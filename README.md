# aukodeng-wife-legal-auto-download

面向律师、仲裁员、企业法务的法律技能（Claude Skill / Trae Skill）一键部署仓。

- **不写死仓名**：组织 `aukodeng-skill` 下任何打上 GitHub topic `wife-legal` 的仓库都会被自动发现并收录；
- **可挑选**：按业务分类、按仓库名、全部（含/不含大型库）三种方式选择，不用整包安装；
- **双平台**：Windows 与 macOS / Linux 使用同一套命令，入口脚本自动识别平台；
- **在线 + 离线**：在线从 GitHub 克隆安装，断网环境用离线压缩包部署，同一套页面与脚本；
- **按需启用**：技能可留在技能库里用 MCP 读取，也可平铺进项目的 `.trae/skills/` 交给 IDE 直接识别。

## 技能管理台（网页）

不用记命令，浏览器里完成「选择 → 安装 / 更新 / 删除 → 启用」全流程：

- **在线版**：<https://aukodeng-skill.github.io/aukodeng-wife-legal-auto-download/>（GitHub Pages，点开即用）
- **本地版**：clone 本仓后双击 [index.html](index.html)，断网也能打开（技能清单内嵌在页面里）
- **离线部署**：页面右上角切「离线模式」，配合 [Release 里的离线压缩包](https://github.com/aukodeng-skill/aukodeng-wife-legal-auto-download/releases/tag/offline-bundle)（`wife-legal-offline-bundle.zip`，含全部 34 仓 + 页面本体），全程不访问 GitHub

页面能力：

1. 34 仓 / 10 分类可视化勾选，Windows 与 macOS 命令一键切换；
2. 「导入本地状态」：粘贴扫描 JSON 后自动标记**已安装**仓库（勾选后可生成**更新 / 删除**命令）；
3. 生成 `install` / `update` / `uninstall` / `enable` / `scan` 五类命令，复制即用；
4. 「导出配置」：选择结果存为 `wife-legal-selection.json`，可用脚本 `--config` 参数直接执行。

配套命令（扫描本机已安装状态，输出 JSON 给页面导入）：

```bash
./deploy.sh --action scan --json     # macOS / Linux
.\deploy.cmd -Action scan -Json      # Windows
```

## 平台支持

| 平台 | 入口 | 实际执行 |
|------|------|----------|
| Windows（PowerShell） | `.\deploy.cmd` 或 `.\scripts\deploy-wife-legal-skills.ps1` | PowerShell 版 |
| Windows（Git Bash / MSYS2 / Cygwin） | `./deploy.sh` | 自动转调 PowerShell 版 |
| macOS / Linux | `./deploy.sh` | bash 版 |
| 其他系统 | `./deploy.sh` | 直接报错退出 |

`deploy.sh` 用 `uname -s` 判断平台：`Darwin`/`Linux` 走 bash 实现，`MINGW*`/`MSYS*`/`CYGWIN*` 转调 PowerShell 实现，其余系统给出明确提示。两个实现功能、参数、菜单编号完全一致（分类编号按 `catalog.tsv` 原始顺序，Windows 与 macOS 看到的编号相同）。

## 业务归类（34 个仓库，10 个分类）

分类数据在 [catalog.tsv](catalog.tsv)，是 Windows 与 macOS 两个脚本共用的唯一数据源，新增仓库只需加一行。

### 综合技能库（10）

| 仓库 | 技能数 | 说明 |
|------|--------|------|
| Legal-Skills-Chinese | 76 | 中文法律技能合集，覆盖合同、诉讼、合规等通用场景 |
| legal-skills | 2 | 中文法律工作流（尽调、文书），含检索脚本 |
| lawyerDU | - | 律师实务技能与提示词合集 |
| claude-for-legal | - | Anthropic 官方法律技能示例（英文，美国法） |
| legal-skills-1 | 72 | 中文法律人技能集合，更新活跃 |
| legal-skills-2 | 3 | 英文法律技能（合同、检索），GPL-3.0 |
| lq-skills | 52 | 面向律师与法律工程师的技能集合 |
| mini-claude-for-legal | 982 | 大型英文技能库，默认不启用 |
| legal-skills-open | 20295 | 超大法律技能库（2 万+ SKILL.md），默认不启用 |
| awesome-legal-skills | 281 | 法律技能索引与合集，默认不启用 |

### 合同与商事（3）

`ai-legal-claude`（合同审查 / NDA / 合规风险，1.8k star）、`claude-legal-skill`（CUAD 数据集条款审查）、`contract-copilot.skill`（中文合同起草与审查副驾）

### 诉讼与争议解决（4）

`new-litigation-visualization`（诉讼可视化与庭审表达）、`cn-litigation-toolkit`（中国诉讼工具箱：立案、证据、庭审）、`china-lawyer-analyst`（案件分析与策略）、`uae-offplan-dispute-skill`（UAE 期房买卖争议与仲裁要点）

### 法律检索与类案（4）

`legal-research-skill`（检索流程与引证规范）、`cn-law-hub`（法条检索与法源定位）、`china-law-case-analysis-skills`（类案检索与裁判要旨）、`dingduff-public`（检索技能与 Claude 插件）

### 劳动与用工（2）

`cn-labor-law-skills`（入职、解除、竞业、**劳动仲裁**）、`worker-rights-cn`（加班费、工伤、仲裁流程）

### 婚姻家事（1）

`family-lawyer-skills`（离婚、财产分割、抚养权）

### 知识产权（3）

`Claude-Patent-Creator`（美国专利与 USPTO 流程）、`cn-patent-drafter`（中国专利撰写）、`patent-skills`（检索、撰写、审查意见答复）

### 合规与企业法务（3）

`Claude-Skills-Governance-Risk-and-Compliance`（GRC，1k star）、`SOE-Legal-Checker`（国企合规审核）、`qulv-china-legal-counsel-skill`（企业法务日常）

### 法律文书与翻译（2）

`legal-document-assistant`（文书起草与校对）、`Chinese-English-Legal-Translation-Skill`（中英法律翻译术语与句式）

### 域外法（2）

`AI-Skills-German-Law`（德国法，319 个技能）、`commercial-legal-pl`（波兰商事法）

> 仲裁目前没有独立专仓：相关能力落在 `cn-labor-law-skills`（劳动仲裁）、`worker-rights-cn`（仲裁流程）、`uae-offplan-dispute-skill`（房产争议与仲裁）、`cn-litigation-toolkit`（争议解决流程）中，归类时按业务场景而非文件类型划分。

## 常用参数速查

完整流程用网页生成命令即可；脚本直连时参考下表（两个平台参数等价，`--xxx` 对应 `-Xxx`）：

| 参数 | 说明 |
|------|------|
| `--action` | `list` / `status` / `scan` / `install` / `update` / `uninstall` / `enable` / `disable`，默认 `install` |
| `--repo` | 指定仓库，可重复或逗号分隔 |
| `--category` | 指定业务分类，可重复或逗号分隔 |
| `--all` / `--include-large` | 全部仓库（仍不含大型库）/ 放开大型库 |
| `--offline <zip>` | 离线安装：从本地压缩包解压，不访问 GitHub |
| `--config <json>` | 读取网页导出的 `wife-legal-selection.json` 作为选择来源 |
| `--json` | `scan` / `status` 输出 JSON（网页「导入本地状态」用） |
| `--root` | 技能库根目录：Windows 默认 `D:\Git\ai-skills\wife-legal`（无 D 盘则用户目录下 `Git\ai-skills\wife-legal`），macOS/Linux 默认 `~/Git/ai-skills/wife-legal` |
| `--project` | 启用/停用的目标项目根，默认当前目录 |
| `--non-interactive` | 跳过交互菜单（`uninstall` 同时跳过删除确认） |

## 大型库保护

`legal-skills-open`（20295 个 SKILL.md）、`mini-claude-for-legal`（982）、`awesome-legal-skills`（281）体积大或技能数过多，会显著拖慢 IDE 技能索引：

- `install` / `enable` 默认跳过；
- 确需使用时追加 `--include-large`；
- 只想要其中几个技能时，直接进技能库目录挑，或让 Agent 按需读取。

## 按需读取（不导入也能用）

不想把技能铺进项目时，用 MCP filesystem 指向技能库根目录，让 Agent 按需读取 `SKILL.md`。配置见 [workbuddy-mcp.json](workbuddy-mcp.json)，合并进项目的 `.trae/mcp.json`（或全局 MCP 配置）后重启会话。

macOS / Linux 需要把路径改成 `"/Users/<你的用户名>/Git/ai-skills/wife-legal"`（或 `"/home/<你的用户名>/..."`）。

## 选型建议

1. **国内民商事主力**：`Legal-Skills-Chinese`（清华智能法治研究院，76 个中文技能，大陆成文法、律师手写验证，覆盖合同审查、起诉状、证据梳理、类案检索、劳动争议、股权协议、合规自查、风险分级）。纯 SKILL.md，可直接导入。
2. **沉淀个人办案 SOP**：`legal-skills`（执业律师维护的实战工作流：咨询接待、合同红评、诉讼文书、刑事辩护、尽调底稿、法规检索，支持自定义律所模板与审查标准）。
3. **诉讼律师**：`lawyerDU`（诉讼可视化、案件报告、证据目录、办案日志、文书生成，输出可同步案件云）+ `cn-litigation-toolkit`。
4. **跨境业务**：`claude-for-legal`（Anthropic 官方，12 大领域 80+ 技能，原生英美法，需自行替换法条库）+ `awesome-legal-skills`（按需挑单条 SKILL.md，不要整仓导入）。
5. **企业法务 / 合规**：`Claude-Skills-Governance-Risk-and-Compliance` + `SOE-Legal-Checker`（国企合规）+ `qulv-china-legal-counsel-skill`。
6. **劳动仲裁**：`cn-labor-law-skills` + `worker-rights-cn`（入职、解除、竞业、加班费、工伤、仲裁流程）。
7. **域外法**：`AI-Skills-German-Law`（德国法 319 个技能）、`commercial-legal-pl`（波兰商事法）。

完整的部署/切换方案、分类明细与 MCP 配置见 [docs/法律技能一键部署与切换方案.md](docs/法律技能一键部署与切换方案.md)。

## 目录结构

```
deploy.sh                          # 跨平台入口（自动识别 Windows / macOS / Linux）
deploy.cmd                         # Windows 入口
index.html                         # 技能管理台网页（在线 Pages / 本地双击 / 离线部署同一份）
scripts/deploy-wife-legal-skills.ps1   # PowerShell 实现
scripts/deploy-wife-legal-skills.sh    # macOS / Linux bash 实现
scripts/make-offline-bundle.sh     # 手动生成离线压缩包（兜底；线上以 Actions 自动发 Release 为准）
.github/workflows/offline-bundle.yml   # 自动打离线包并更新 Release（tag: offline-bundle，每周自动刷新）
catalog.tsv                        # 34 个仓库 × 10 个业务分类（两个平台的共用数据源）
workbuddy-mcp.json                 # MCP filesystem 配置样例
docs/法律技能一键部署与切换方案.md      # 完整方案、选型与分类明细
```
