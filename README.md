# aukodeng-wife-legal-auto-download

按 GitHub topic `wife-legal` 自动发现并一键部署法律技能仓。仓名清单不写死在脚本里——组织下任何打上 `wife-legal` 标签的仓库都会被自动收录。

当前收录（2026-11-17）：

| 仓库 | 说明 |
|------|------|
| Legal-Skills-Chinese | 清华智能法治研究院，38 个中文法律技能，国内成文法 |
| legal-skills | 执业律师实战工作流，支持自定义模板与审查标准 |
| lawyerDU | 案件云配套：诉讼可视化、案件报告、证据目录 |
| claude-for-legal | Anthropic 官方，80+ 技能，英美法（跨境业务用） |
| awesome-legal-skills | 276 个独立法律技能合集，按需挑选 |

## 一键部署

```powershell
# 先看组织下有哪些带 wife-legal 标签的仓
.\scripts\deploy-wife-legal-skills.ps1 -Action list

# 克隆全部法律技能仓到 D:\Git\ai-skills\wife-legal\<仓库名>
.\scripts\deploy-wife-legal-skills.ps1 -Action install

# 只装常用的三个（不装 276 技能的合集）
.\scripts\deploy-wife-legal-skills.ps1 -Action install `
    -Repo Legal-Skills-Chinese,legal-skills,lawyerDU

# 更新已部署的仓
.\scripts\deploy-wife-legal-skills.ps1 -Action update

# 把技能平铺进项目 .trae\skills\（Trae 只认一层目录，故按 wife-legal-<仓>-<技能> 命名）
.\scripts\deploy-wife-legal-skills.ps1 -Action enable -Project D:\Git\my-workbuddy-project `
    -Repo Legal-Skills-Chinese

# 停用（移除已平铺进项目的法律技能）
.\scripts\deploy-wife-legal-skills.ps1 -Action disable -Project D:\Git\my-workbuddy-project
```

参数说明：

- `-Root`：技能库根目录，默认 `D:\Git\ai-skills\wife-legal`，每仓一个子目录
- `-Project`：启用/停用的目标项目根，默认当前目录
- `-Repo`：只处理指定仓，留空为全部
- `-IncludeLarge`：允许启用 `awesome-legal-skills`（276 个技能，会显著增加技能列表体积，默认跳过）

## 按需读取（不导入也能用）

不想把技能铺进项目时，用 MCP filesystem 指向技能库根目录，让 Agent 按需读取 `SKILL.md`：

```json
{
  "mcpServers": {
    "wife-legal-skills": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "D:\\Git\\ai-skills\\wife-legal"]
    }
  }
}
```

把这段合并进项目的 `.trae/mcp.json`（或全局 MCP 配置），重启会话生效。

## 目录结构

```
scripts\deploy-wife-legal-skills.ps1   # 发现 / 克隆 / 更新 / 启用 / 停用
workbuddy-mcp.json                     # 上面那段 MCP 配置的独立副本
```
