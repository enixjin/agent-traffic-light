// agent-lights.ts — OpenCode 全局插件: 经 set_status.sh 上报本 agent 状态
// （多 agent 聚合逻辑在 set_status.sh v2.1 里，显示端统一读 ~/.agent-status）
// 安装: 放到 ~/.config/opencode/plugins/agent-lights.ts, 然后重启 OpenCode
// 写法依据 OpenCode 官方插件文档 (opencode.ai/docs/plugins)

export const AgentLights = async ({ $ }: any) => {
  const home = process.env.HOME || "~"
  // set_status.sh 自己不打印任何输出，直接调即可
  const set = (s: string) => $`${home}/.agent-lights/set_status.sh ${s} opencode`

  return {
    // 每次工具调用前 = 工作中, 黄灯
    "tool.execute.before": async () => {
      await set("working")
    },
    "event": async ({ event }: any) => {
      // 回合结束 / 会话空闲 = 待命, 蓝灯
      if (event.type === "session.idle") {
        await set("idle")
      }
      // 弹出权限确认等你点 = 需人工介入, 红灯
      if (event.type === "permission.asked") {
        await set("attention")
      }
      // 权限弹窗已回答(无论批准/拒绝) = 不再等人, 回黄灯
      if (event.type === "permission.replied") {
        await set("working")
      }
      // 会话被删除/出错 = 清掉本 agent 状态, 避免残留红灯永远压住其他 agent
      if (event.type === "session.deleted" || event.type === "session.error") {
        await set("idle")
      }
    },
  }
}
