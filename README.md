# aukodeng-wife-legal-auto-download

面向律师、仲裁员、企业法务的法律技能（Claude Skill / Trae Skill）一键部署仓。

- **不写死仓名**：组织 `aukodeng-skill` 下任何打上 GitHub topic `wife-legal` 的仓库都会被自动发现并收录；
- **可挑选**：按业务分类、按仓库名、全部（含/不含大型库）三种方式选择，不用整包安装；
- **双平台**：Windows 与 macOS / Linux 使用同一套命令，入口脚本自动识别平台；
- **按需启用**：技能可留在技能库里用 MCP 读取，也可平铺进项目的 `.trae/skills/` 交给 IDE 直接识别。

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

## 一键部署

### 1. 看清单与分类

```bash
./deploy.sh --action list          # macOS / Linux
.\deploy.cmd -Action list          # Windows
```

### 2. 选择并安装

交互式（推荐首次使用，直接回车 = 全部但不含大型库）：

```bash
./deploy.sh --action install
```

非交互式，按分类选：

```bash
./deploy.sh --action install --category 合同与商事
./deploy.sh --action install --category 合同与商事 --category 劳动与用工
.\deploy.cmd -Action install -Category 合同与商事
```

按仓库选（可多个）：

```bash
./deploy.sh --action install --repo Legal-Skills-Chinese --repo cn-labor-law-skills
.\deploy.cmd -Action install -Repo Legal-Skills-Chinese,cn-labor-law-skills
```

全部安装（大型库需显式放开）：

```bash
./deploy.sh --action install --all
./deploy.sh --action install --all --include-large
```

### 3. 启用进项目

把技能平铺到 `<项目>/.trae/skills/wife-legal-<仓库>-<技能>/`，Trae / Claude Code 只认一层目录，因此统一加前缀：

```bash
./deploy.sh --action enable --repo cn-labor-law-skills --project ~/work/case-2026
.\deploy.cmd -Action enable -Repo cn-labor-law-skills -Project D:\work\case-2026
```

### 4. 停用 / 更新 / 状态

```bash
./deploy.sh --action disable --repo cn-labor-law-skills --project ~/work/case-2026
./deploy.sh --action update
./deploy.sh --action status
```

### 参数说明

| 参数 | 说明 |
|------|------|
| `--action` / `-Action` | `list` / `status` / `install` / `update` / `enable` / `disable`，默认 `install` |
| `--repo` / `-Repo` | 指定仓库，可重复或逗号分隔 |
| `--category` / `-Category` | 指定业务分类，可重复或逗号分隔 |
| `--all` / `-All` | 全部仓库（仍不含大型库） |
| `--include-large` / `-IncludeLarge` | 放开大型库（安装与启用都生效） |
| `--root` / `-Root` | 技能库根目录：Windows 默认 `D:\Git\ai-skills\wife-legal`（无 D 盘则用户目录下 `Git\ai-skills\wife-legal`），macOS/Linux 默认 `~/Git/ai-skills/wife-legal` |
| `--project` / `-Project` | 启用/停用的目标项目根，默认当前目录 |
| `--non-interactive` / `-NonInteractive` | 跳过交互菜单 |
| `--org` / `--topic` | 默认 `aukodeng-skill` / `wife-legal` |

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
scripts/deploy-wife-legal-skills.ps1   # PowerShell 实现
scripts/deploy-wife-legal-skills.sh    # macOS / Linux bash 实现
catalog.tsv                        # 34 个仓库 × 10 个业务分类（两个平台的共用数据源）
workbuddy-mcp.json                 # MCP filesystem 配置样例
docs/法律技能一键部署与切换方案.md      # 完整方案、选型与分类明细
```

## 与其他仓的分工

| 仓 | topic | 可见性 | 用途 |
|------|------|------|------|
| `aukodeng-wife-legal-auto-download`（本仓） | `wife-legal` | Public | 法律技能唯一部署入口，34 仓 / 10 分类，可选装可选启用 |
| `aukodeng-work-auto-download` | `aukodeng-work` | Private（需登录） | SDWAN 项目私有技能镜像，`-Action apply` 铺入开发项目 |

两个仓各自独立部署，装哪个仓的脚本就只加载那个仓对应的技能，互不混杂。

## 仓库收录规则

1. 在 `aukodeng-skill` 组织下 fork（或新建）目标仓；
2. 给仓库打上 topic `wife-legal`；
3. 在 `catalog.tsv` 增加一行（仓库名、分类、上游地址、是否大型库、技能数、说明）；
4. 提交后所有已部署环境执行 `--action update` 即可看到新仓。

部署仓自身不打 `wife-legal` 标签，避免把自己当成技能仓收录。
