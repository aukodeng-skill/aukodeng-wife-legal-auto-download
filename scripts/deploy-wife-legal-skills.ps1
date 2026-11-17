# wife-legal 法律技能仓一键部署/更新/切换脚本
# 按 GitHub topic wife-legal 自动发现组织下的法律技能仓，仓名清单不写死
# 用法：
#   .\deploy-wife-legal-skills.ps1 -Action list
#   .\deploy-wife-legal-skills.ps1 -Action install
#   .\deploy-wife-legal-skills.ps1 -Action update
#   .\deploy-wife-legal-skills.ps1 -Action enable -Project D:\Git\proj -Repo Legal-Skills-Chinese
#   .\deploy-wife-legal-skills.ps1 -Action disable -Project D:\Git\proj
param(
    # 操作类型：list（列出标签下仓库）、install（克隆）、update（拉取）、enable/disable（在项目内启用/停用）
    [ValidateSet('list','install','update','enable','disable')]
    [string]$Action = 'install',
    # 按 topic 检索的组织
    [string]$Org = 'aukodeng-skill',
    # 检索用的 topic
    [string]$Topic = 'wife-legal',
    # 技能库根目录（每个仓一个子目录）
    [string]$Root = 'D:\Git\ai-skills\wife-legal',
    # 启用/停用的目标项目根（默认当前目录）
    [string]$Project = (Get-Location).Path,
    # 只处理指定仓（留空为全部）
    [string[]]$Repo = @(),
    # 允许启用 awesome-legal-skills 这类超大合集（默认跳过，避免技能列表膨胀）
    [switch]$IncludeLarge
)

# 体积过大的合集仓，默认不参与 enable
$largeRepos = @('awesome-legal-skills')

# API 不可达时的兜底清单（与 topic 检索结果保持一致）
$fallbackRepos = @('Legal-Skills-Chinese','legal-skills','lawyerDU','claude-for-legal','awesome-legal-skills')

# 发现：优先按 topic 检索组织下仓库，失败时回落到内置清单
function Get-TargetRepos
{
    $headers = @{
        'User-Agent' = 'aukodeng-wife-legal-auto-download'
        'Accept'     = 'application/vnd.github.mercy-preview+json'
    }
    $result = @()
    try
    {
        $page = 1
        while ($true)
        {
            $uri = "https://api.github.com/orgs/$Org/repos?per_page=100&page=$page"
            $batch = Invoke-RestMethod -Uri $uri -Headers $headers -TimeoutSec 20 -ErrorAction Stop
            if (-not $batch) { break }
            $result += $batch
            if ($batch.Count -lt 100) { break }
            $page++
        }
        $matched = $result | Where-Object { $_.topics -contains $Topic }
        if (-not $matched)
        {
            Write-Warning "组织 $Org 下没有找到 topic=$Topic 的仓库，改用内置清单"
            $matched = $fallbackRepos | ForEach-Object {
                [pscustomobject]@{ name = $_; clone_url = "https://github.com/$Org/$_.git" }
            }
        }
    }
    catch
    {
        Write-Warning "GitHub API 调用失败（$($_.Exception.Message)），改用内置清单"
        $matched = $fallbackRepos | ForEach-Object {
            [pscustomobject]@{ name = $_; clone_url = "https://github.com/$Org/$_.git" }
        }
    }
    if ($Repo.Count -gt 0)
    {
        $matched = $matched | Where-Object { $Repo -contains $_.name }
    }
    return $matched | ForEach-Object {
        [pscustomobject]@{ Name = $_.name; Url = $_.clone_url }
    }
}

$repos = @(Get-TargetRepos)
if ($repos.Count -eq 0)
{
    Write-Host "没有匹配的仓库（Org=$Org，Topic=$Topic，Repo=$($Repo -join ',')）"
    return
}

# list：列出标签下仓库及本地是否已部署
if ($Action -eq 'list')
{
    foreach ($r in $repos)
    {
        $dest = Join-Path $Root $r.Name
        $state = if (Test-Path (Join-Path $dest '.git')) { '已部署' } else { '未部署' }
        Write-Host ("[{0}] {1}  {2}" -f $state, $r.Name, $r.Url)
    }
    return
}

# install：浅克隆到 Root\<仓库名>
if ($Action -eq 'install')
{
    New-Item -ItemType Directory -Force -Path $Root | Out-Null
    foreach ($r in $repos)
    {
        $dest = Join-Path $Root $r.Name
        if (Test-Path $dest)
        {
            Write-Host "[跳过] $dest 已存在（更新请用 -Action update）"
            continue
        }
        # --depth 1 只取最新快照，技能包不需要完整历史
        git clone --depth 1 $r.Url $dest
    }
    return
}

# update：对已部署仓库执行 git pull
if ($Action -eq 'update')
{
    foreach ($r in $repos)
    {
        $dest = Join-Path $Root $r.Name
        if (Test-Path (Join-Path $dest '.git'))
        {
            Write-Host "[更新] $dest"
            git -C $dest pull --ff-only
        }
        else
        {
            Write-Host "[缺失] $dest 不存在，请先 -Action install"
        }
    }
    return
}

# enable：把每个仓里的技能目录平铺到项目 .trae\skills\wife-legal-<仓>-<技能>
# Trae 只识别 .trae\skills\<name>\SKILL.md 这一层，所以必须平铺，不能保留仓库原有嵌套
if ($Action -eq 'enable')
{
    $skillRoot = Join-Path $Project '.trae\skills'
    New-Item -ItemType Directory -Force -Path $skillRoot | Out-Null
    foreach ($r in $repos)
    {
        if ($largeRepos -contains $r.Name -and -not $IncludeLarge)
        {
            Write-Host "[跳过] $($r.Name) 技能数量过多，需要时加 -IncludeLarge 或 -Repo $($r.Name)"
            continue
        }
        $src = Join-Path $Root $r.Name
        if (-not (Test-Path $src))
        {
            Write-Host "[缺失] $src 不存在，请先 -Action install"
            continue
        }
        # 每个 SKILL.md 所在目录就是一个技能
        $skillFiles = Get-ChildItem -Path $src -Recurse -Filter 'SKILL.md' -File -ErrorAction SilentlyContinue
        foreach ($f in $skillFiles)
        {
            $leaf = Split-Path $f.DirectoryName -Leaf
            $name = if ($leaf -eq $r.Name) { "wife-legal-$($r.Name)" } else { "wife-legal-$($r.Name)-$leaf" }
            $target = Join-Path $skillRoot $name
            if (Test-Path $target)
            {
                Remove-Item $target -Recurse -Force
            }
            Copy-Item $f.DirectoryName $target -Recurse -Force
        }
        Write-Host "[启用] $($r.Name)：$($skillFiles.Count) 个技能 -> $skillRoot"
    }
    return
}

# disable：移除本脚本铺进项目的 wife-legal-* 技能目录
if ($Action -eq 'disable')
{
    $skillRoot = Join-Path $Project '.trae\skills'
    if (-not (Test-Path $skillRoot))
    {
        Write-Host "[跳过] $skillRoot 不存在"
        return
    }
    $targets = Get-ChildItem $skillRoot -Directory -Filter 'wife-legal-*' -ErrorAction SilentlyContinue
    if (-not $targets)
    {
        Write-Host "[跳过] 没有 wife-legal-* 技能目录"
        return
    }
    foreach ($t in $targets)
    {
        Remove-Item $t.FullName -Recurse -Force
        Write-Host "[停用] 已移除 $($t.FullName)"
    }
}
