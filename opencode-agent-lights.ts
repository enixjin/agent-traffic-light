// agent-lights.ts — OpenCode v2 全局插件：经 set_status.sh 上报本 agent 状态
// （多 agent 聚合逻辑在 set_status.sh v2.1 里，显示端统一读 ~/.agent-status）
// 安装: 放到 ~/.config/opencode/plugins/agent-lights.ts, 然后重启 OpenCode
// 写法依据 OpenCode v2 插件 API (opencode.ai/v2/docs/build/plugins/)

import { spawnSync } from "node:child_process"

const home = process.env.HOME || "~"
const setStatus = (status: string) => {
  // set_status.sh 自己不打印输出；忽略任何错误，绝不阻塞 OpenCode
  spawnSync(`${home}/.agent-lights/set_status.sh`, [status, "opencode"], {
    stdio: "ignore",
  })
}

export default {
  id: "agent-lights",
  setup: async (ctx: any) => {
    // 订阅生命周期事件
    const controller = new AbortController()
    const runEvents = async () => {
      try {
        for await (const { event } of ctx.event.subscribe({ signal: controller.signal })) {
          if (event.type === "session.idle") {
            setStatus("idle")
          }
          if (event.type === "permission.asked") {
            setStatus("attention")
          }
          if (event.type === "permission.replied") {
            setStatus("working")
          }
          if (event.type === "session.deleted" || event.type === "session.error") {
            setStatus("idle")
          }
        }
      } catch {
        // abort 时正常退出循环
      }
    }
    runEvents()

    // 每次工具调用前 = 工作中, 黄灯
    await ctx.tool.hook("execute.before", () => {
      setStatus("working")
    })

    // 卸载时取消事件订阅
    return () => controller.abort()
  },
}
