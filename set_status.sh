#!/bin/bash
# set_status.sh v2 — 多 agent 状态聚合写入
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
set -u

STATUS="${1:-idle}"
AGENT="${2:-default}"
DIR="$HOME/.agent-status.d"
OUT="$HOME/.agent-status"

case "$STATUS" in
  idle|working|attention) ;;
  *) STATUS="idle" ;;
esac
AGENT="$(printf '%s' "$AGENT" | tr -c 'a-zA-Z0-9_-' '_')"
[ -z "$AGENT" ] && AGENT="default"

mkdir -p "$DIR"
printf '%s' "$STATUS" > "$DIR/$AGENT"

# 取文件 mtime：macOS 用 stat -f %m，Linux 用 stat -c %Y
if stat -f %m "$DIR/$AGENT" >/dev/null 2>&1; then
  stat_mtime() { stat -f %m "$1"; }
else
  stat_mtime() { stat -c %Y "$1"; }
fi

best="idle"; best_prio=1; best_mtime=0; best_agent=""
for f in "$DIR"/*; do
  [ -f "$f" ] || continue
  s="$(cat "$f" 2>/dev/null)"
  case "$s" in
    attention) p=3 ;;
    working)   p=2 ;;
    *)         p=1; s="idle" ;;
  esac
  m="$(stat_mtime "$f")"
  a="$(basename "$f")"
  if [ "$p" -gt "$best_prio" ] || { [ "$p" -eq "$best_prio" ] && [ "$m" -ge "$best_mtime" ]; }; then
    best="$s"; best_prio="$p"; best_mtime="$m"; best_agent="$a"
  fi
done

if [ -n "$best_agent" ] && [ "$best_agent" != "default" ]; then
  printf '%s:%s' "$best" "$best_agent" > "$OUT"
else
  printf '%s' "$best" > "$OUT"
fi
