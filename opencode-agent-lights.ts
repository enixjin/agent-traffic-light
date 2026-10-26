// agent-lights.ts — OpenCode v2 全局插件：经 set_status.sh 上报本 agent 状态
// （多 agent 聚合逻辑在 set_status.sh v2.1 里，显示端统一读 ~/.agent-status）
// 安装: 放到 ~/.config/opencode/plugins/agent-lights.ts, 然后重启 OpenCode
// 写法依据 OpenCode v2 插件 API (opencode.ai/v2/docs/build/plugins/)
//
// v2 生命周期事件（实测）:
//   working: session.step.started / session.tool.called
//   idle:    session.step.ended 且 finish 为 "stop" / "error" / "length" /
//          "content-filter" / "unknown"
//   attention: permission.requested（待验证，保留兼容）

import { spawnSync } from "node:child_process"

const home = process.env.HOME || "~"
const setStatus = (status: string) => {
  // set_status.sh 自己不打印输出；忽略任何错误，绝不阻塞 OpenCode
  spawnSync(`${home}/.agent-lights/set_status.sh`, [status, "opencode"], {
    stdio: "ignore",
  })
}

const IDLE_FINISHES = new Set([
  "stop",
  "error",
  "length",
  "content-filter",
  "unknown",
])

export default {
  id: "agent-lights",
  setup: async (ctx: any) => {
    // 启动时先置为待命，避免上次异常退出残留工作中状态
    setStatus("idle")

    const controller = new AbortController()
    let toolCallsTimeout: ReturnType<typeof setTimeout> | undefined

    const runEvents = async () => {
      try {
        for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
          const type = event?.type
          if (!type) continue

          // 开始新步骤 / 决定调用工具 = 工作中（黄灯）
          if (type === "session.step.started" || type === "session.tool.called") {
            if (toolCallsTimeout) {
              clearTimeout(toolCallsTimeout)
              toolCallsTimeout = undefined
            }
            setStatus("working")
          }

          // 步骤结束：根据 finish 判断是继续工作还是回到待命
          if (type === "session.step.ended") {
            const finish = event.data?.finish
            if (finish === "tool-calls") {
              // 工具调用后通常很快会进入下一步；加个保险，5s 没新 step 则回到待命
              toolCallsTimeout = setTimeout(() => {
                setStatus("idle")
              }, 5000)
            } else if (IDLE_FINISHES.has(finish)) {
              setStatus("idle")
            }
          }

          // 权限确认（红灯）—— 事件名按 v1 经验保留，实际以 v2 为准
          if (type === "permission.requested" || type === "permission.asked") {
            setStatus("attention")
          }
          if (type === "permission.replied" || type === "permission.resolved") {
            setStatus("working")
          }

          // 会话被删除/出错 = 清掉本 agent 状态，避免残留红灯永远压住其他 agent
          if (type === "session.deleted" || type === "session.error") {
            setStatus("idle")
          }
        }
      } catch {
        // abort 时正常退出循环
      }
    }
    runEvents()

    // 卸载时取消事件订阅与保险定时器
    return () => {
      if (toolCallsTimeout) clearTimeout(toolCallsTimeout)
      controller.abort()
    }
  },
}
