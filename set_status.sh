#!/bin/bash
# set_status.sh v2.1 — 多 agent 状态聚合写入（并发安全）
#
# 用法: set_status.sh <idle|working|attention> [agent]
# 例子: set_status.sh working claude
#
# 每个 agent 的状态落在 ~/.agent-status.d/<agent>，
# 再按优先级聚合成 ~/.agent-status（集成契约，见 HARDWARE.md）：
#   attention（需人工介入）> working（工作中）> idle（待命）
# 优先级相同时取最后写入的。
#
# 约定：hooks 只调这个脚本；显示端（App / 未来硬件驱动）只读 ~/.agent-status。
#
# v2.1 并发加固（对外契约不变）：
#   1) 所有落盘用 临时文件 + mv 原子替换，读端（App 轮询/并发聚合）永远不会看到半截内容；
#   2) 聚合段用 mkdir 自旋锁互斥，防止两个并发 hook 拿旧目录快照互相覆盖，
#      把刚写进去的 attention（红灯）冲掉；
#   3) 同优先级的"最后写入者胜"改用小数秒 mtime 判定（原来 1 秒粒度内会退化成按字母序）。
set -u

STATUS="${1:-idle}"
AGENT="${2:-default}"
DIR="$HOME/.agent-status.d"
OUT="$HOME/.agent-status"
LOCK="$DIR.lock"

case "$STATUS" in
  idle|working|attention) ;;
  *) STATUS="idle" ;;
esac
AGENT="$(printf '%s' "$AGENT" | tr -c 'a-zA-Z0-9_-' '_')"
[ -z "$AGENT" ] && AGENT="default"

mkdir -p "$DIR"

# ---------- 原子写：同目录隐藏临时文件 + mv（rename 原子，临时文件不会被聚合 glob 扫到） ----------
atomic_write() { # $1=目标文件 $2=内容
  local tmp
  tmp="$(dirname "$1")/.$(basename "$1").tmp.$$"
  printf '%s' "$2" > "$tmp" && mv -f "$tmp" "$1"
}

atomic_write "$DIR/$AGENT" "$STATUS"

# ---------- mtime 读取：优先小数秒（macOS %Fm），Linux 退回 %Y 整秒 ----------
if _m=$(stat -f %Fm "$DIR/$AGENT" 2>/dev/null) && printf '%s' "$_m" | grep -q '^[0-9]'; then
  file_mtime() { stat -f %Fm "$1" 2>/dev/null || printf '0\n'; }
else
  file_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || printf '0\n'; }
fi
mtime_ge() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a + 0 >= b + 0) }'; }

# ---------- mkdir 自旋锁（macOS 没有 flock(1)；mkdir 是原子的） ----------
acquired=""
cleanup() { [ -n "$acquired" ] && rmdir "$LOCK" 2>/dev/null; return 0; }
trap cleanup EXIT INT TERM
tries=0
while [ "$tries" -lt 40 ]; do
  if mkdir "$LOCK" 2>/dev/null; then acquired=1; break; fi
  # 陈旧锁窃取：持有者被 kill -9 时锁目录会残留，超过 5 秒视为死锁并清除
  now=$(date +%s)
  lm=$(stat -c %Y "$LOCK" 2>/dev/null || stat -f %m "$LOCK" 2>/dev/null || echo "$now")
  [ $((now - lm)) -ge 5 ] && rmdir "$LOCK" 2>/dev/null
  tries=$((tries + 1))
  sleep 0.05
done
# 拿不到锁也继续聚合：mv 仍保证原子（不会撕裂），只是退化为旧的 last-writer-wins

# ---------- 聚合：优先级最高者胜；同优先级取最后写入（锁内重读，快照必然新鲜） ----------
best="idle"; best_prio=1; best_mtime=0; best_agent=""
for f in "$DIR"/*; do
  [ -f "$f" ] || continue
  s="$(cat "$f" 2>/dev/null)"
  case "$s" in
    attention) p=3 ;;
    working)   p=2 ;;
    *)         p=1; s="idle" ;;
  esac
  m="$(file_mtime "$f")"
  a="$(basename "$f")"
  if [ "$p" -gt "$best_prio" ] || { [ "$p" -eq "$best_prio" ] && mtime_ge "$m" "$best_mtime"; }; then
    best="$s"; best_prio="$p"; best_mtime="$m"; best_agent="$a"
  fi
done

if [ -n "$best_agent" ] && [ "$best_agent" != "default" ]; then
  atomic_write "$OUT" "$best:$best_agent"
else
  atomic_write "$OUT" "$best"
fi
