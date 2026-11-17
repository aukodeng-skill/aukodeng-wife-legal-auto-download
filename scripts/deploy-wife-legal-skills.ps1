<#
.SYNOPSIS
    法律技能一键部署（按 GitHub topic 自动发现，支持 Windows / macOS / Linux）

.DESCRIPTION
    - 技能仓清单来自组织仓库的 topic（默认 wife-legal），不写死仓名；
    - catalog.tsv 提供业务分类，用于选择安装与平铺启用；
    - 支持交互式选择：可按分类、按仓库、全部或排除大型库；
    - Windows 用 PowerShell 原生运行；macOS / Linux 可用 deploy.sh 自动转调同名 bash 脚本。

.EXAMPLE
    .\scripts\deploy-wife-legal-skills.ps1 -Action list
    .\scripts\deploy-wife-legal-skills.ps1 -Action install
    .\scripts\deploy-wife-legal-skills.ps1 -Action install -Category 合同与商事
    .\scripts\deploy-wife-legal-skills.ps1 -Action enable -Repo Legal-Skills-Chinese -Project D:\Git\my-project
#>
param(
    [ValidateSet('list','status','scan','install','update','uninstall','enable','disable')]
    [string]$Action = 'install',

    [string]$Org = 'aukodeng-skill',
    [string]$Topic = 'wife-legal',

    # 技能库根目录；不传时按平台自动选择
    [string]$Root = '',

    # 目标项目根目录（enable / disable 生效位置：<Project>/.trae/skills）
    [string]$Project = (Get-Location).Path,

    [string[]]$Repo = @(),
    [string[]]$Category = @(),
    [switch]$All,
    [switch]$IncludeLarge,

    # 离线压缩包路径：install 时从压缩包解压安装，不访问 GitHub
    [string]$Offline = '',

    # 选择配置 JSON 路径：读取网页导出的 wife-legal-selection.json 作为选择来源
    [string]$Config = '',

    # 不走交互菜单（参数已足够时自动生效）
    [switch]$NonInteractive,

    # 允许覆盖已存在的目标技能目录（enable 默认覆盖，保留开关便于脚本调用）
    [switch]$Force,

    # scan/status 输出 JSON（网页「导入本地状态」用）
    [switch]$Json,

    # 显示帮助（deploy.sh 转调 -h/--help 时使用）
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$catalogPath = Join-Path $repoRoot 'catalog.tsv'

if ($Help)
{
    @'
用法：deploy-wife-legal-skills.ps1 [参数]

  -Action <list|status|scan|install|update|uninstall|enable|disable>  默认 install
  -Repo <名称>        指定仓库，可重复或逗号分隔
  -Category <分类>    指定业务分类，可重复或逗号分隔
  -All                全部仓库（仍不含大型库）
  -IncludeLarge       放开大型库（安装与启用都生效）
  -Offline <zip>      离线压缩包：install 时从本地压缩包解压安装，不访问 GitHub
  -Config <json>      选择配置：读取网页导出的 wife-legal-selection.json 作为选择来源
  -Root <目录>        技能库根目录，默认 D:\Git\ai-skills\wife-legal
  -Project <目录>     目标项目根目录（enable/disable 作用位置），默认当前目录
  -Json               scan/status 输出 JSON（网页「导入本地状态」用）
  -Org <组织>         默认 aukodeng-skill
  -Topic <标签>       默认 wife-legal
  -NonInteractive     不做交互菜单（使用默认全选或显式参数）
  -Help               显示帮助
'@ | Write-Host
    exit 0
}

function Test-WindowsPlatform
{
    return ([System.Environment]::OSVersion.Platform -eq 'Win32NT')
}

function Get-DefaultRoot
{
    if (Test-WindowsPlatform)
    {
        if (Test-Path 'D:\Git')
        {
            return 'D:\Git\ai-skills\wife-legal'
        }
        return [IO.Path]::Combine($env:USERPROFILE, 'Git', 'ai-skills', 'wife-legal')
    }
    return [IO.Path]::Combine($HOME, 'Git', 'ai-skills', 'wife-legal')
}

function Get-Catalog
{
    if (-not (Test-Path $catalogPath))
    {
        throw "未找到分类清单：$catalogPath"
    }
    # catalog.tsv 为 UTF-8（无 BOM），显式指定编码避免中文乱码
    return Import-Csv -Path $catalogPath -Delimiter "`t" -Encoding UTF8
}

# 按 topic 从组织仓库发现技能仓；网络不可用时回落到 catalog.tsv
function Get-DiscoveredRepos
{
    $headers = @{ Accept = 'application/vnd.github.mercy-preview+json'; 'User-Agent' = 'wife-legal-deploy' }
    $found = @()
    try
    {
        $page = 1
        while ($page -le 10)
        {
            $url = "https://api.github.com/orgs/$Org/repos?per_page=100&page=$page"
            $items = Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec 20
            if (-not $items -or $items.Count -eq 0)
            {
                break
            }
            foreach ($item in $items)
            {
                if ($item.topics -contains $Topic)
                {
                    $found += $item.name
                }
            }
            if ($items.Count -lt 100)
            {
                break
            }
            $page++
        }
    }
    catch
    {
        Write-Warning "按 topic 发现仓库失败（$($_.Exception.Message)），改用 catalog.tsv 清单"
        return $null
    }
    return $found
}

function Select-Repos
{
    param($Catalog)

    $names = @($Catalog | ForEach-Object { $_.repo })

    # 显式指定了仓库或分类，或要求全部：不做交互
    if ($Repo.Count -gt 0 -or $Category.Count -gt 0 -or $All -or $NonInteractive)
    {
        $selected = @()
        if ($All)
        {
            $selected = $Catalog
        }
        elseif ($Repo.Count -gt 0)
        {
            foreach ($r in $Repo)
            {
                $hit = $Catalog | Where-Object { $_.repo -eq $r }
                if (-not $hit)
                {
                    Write-Warning "catalog.tsv 中没有仓库：$r"
                    continue
                }
                $selected += $hit
            }
        }
        elseif ($Category.Count -gt 0)
        {
            foreach ($c in $Category)
            {
                $hit = @($Catalog | Where-Object { $_.category -eq $c })
                if ($hit.Count -eq 0)
                {
                    Write-Warning "没有该分类：$c"
                    continue
                }
                $selected += $hit
            }
        }
        else
        {
            $selected = @($Catalog | Where-Object { $_.large -ne '1' })
        }
        return @($selected | Sort-Object repo -Unique)
    }

    # 交互菜单（分类顺序与 catalog.tsv 一致，保证 Windows/macOS 编号相同）
    $catOrder = @()
    foreach ($row in $Catalog)
    {
        if ($catOrder -notcontains $row.category)
        {
            $catOrder += $row.category
        }
    }
    Write-Host ''
    Write-Host '可用技能分类：' -ForegroundColor Cyan
    $i = 1
    $indexMap = @{}
    foreach ($cat in $catOrder)
    {
        $catCount = @($Catalog | Where-Object { $_.category -eq $cat }).Count
        Write-Host ("  [{0}] {1}（{2} 个仓）" -f $i, $cat, $catCount)
        $indexMap[$i] = $cat
        $i++
    }
    Write-Host ("  [{0}] 全部（不含大型库）" -f $i)
    $allIndex = $i
    $i++
    if ($IncludeLarge)
    {
        Write-Host ("  [{0}] 全部（含大型库）" -f $i)
        $allLargeIndex = $i
    }

    Write-Host ''
    Write-Host '输入编号 / 分类名 / 仓库名（空格或逗号分隔），直接回车=全部（不含大型库）：' -ForegroundColor Yellow
    $answer = Read-Host '选择'

    if ([string]::IsNullOrWhiteSpace($answer))
    {
        return @($Catalog | Where-Object { $_.large -ne '1' })
    }

    $tokens = @($answer -split '[,，\s]+' | Where-Object { $_ -ne '' })
    $selected = @()
    foreach ($t in $tokens)
    {
        $num = 0
        if ([int]::TryParse($t, [ref]$num))
        {
            if ($num -eq $allIndex)
            {
                $selected += @($Catalog | Where-Object { $_.large -ne '1' })
            }
            elseif ($IncludeLarge -and $num -eq $allLargeIndex)
            {
                $selected += $Catalog
            }
            elseif ($indexMap.ContainsKey($num))
            {
                $cat = $indexMap[$num]
                $selected += @($Catalog | Where-Object { $_.category -eq $cat })
            }
            else
            {
                Write-Warning "无效编号：$t"
            }
            continue
        }
        $byCat = @($Catalog | Where-Object { $_.category -eq $t })
        if ($byCat.Count -gt 0)
        {
            $selected += $byCat
            continue
        }
        $byRepo = @($Catalog | Where-Object { $_.repo -eq $t })
        if ($byRepo.Count -gt 0)
        {
            $selected += $byRepo
            continue
        }
        Write-Warning "未匹配的分类或仓库：$t"
    }
    return @($selected | Sort-Object repo -Unique)
}

function Show-Catalog
{
    param($Catalog)
    $lastCat = ''
    foreach ($row in $Catalog)
    {
        if ($row.category -ne $lastCat)
        {
            Write-Host ''
            Write-Host ("[{0}]" -f $row.category) -ForegroundColor Cyan
            $lastCat = $row.category
        }
        $flag = ''
        if ($row.large -eq '1')
        {
            $flag = '（大型库）'
        }
        Write-Host ("  - {0}{1} | {2} 个技能 | {3}" -f $row.repo, $flag, $row.skills, $row.note)
    }
}

function Invoke-Install
{
    param($Targets)

    if (-not (Test-Path $Root))
    {
        New-Item -ItemType Directory -Force -Path $Root | Out-Null
    }

    # 离线模式：从压缩包解压安装，不访问 GitHub（压缩包内为各仓顶层目录）
    if ($Offline)
    {
        if (-not (Test-Path $Offline))
        {
            throw "离线压缩包不存在：$Offline（先从 Release 下载并放到部署仓目录）"
        }
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ("wife-legal-offline-" + [GUID]::NewGuid().ToString('N'))
        try
        {
            Expand-Archive -Path $Offline -DestinationPath $tmp -Force
            foreach ($row in $Targets)
            {
                $srcDir = Join-Path $tmp $row.repo
                $dest = [IO.Path]::Combine($Root, $row.repo)
                if (-not (Test-Path $srcDir))
                {
                    Write-Warning ("离线包中没有仓库：{0}" -f $row.repo)
                    continue
                }
                if (Test-Path $dest)
                {
                    Write-Host ("跳过（已存在）：{0}" -f $row.repo) -ForegroundColor DarkGray
                    continue
                }
                Move-Item -Path $srcDir -Destination $dest
                Write-Host ("离线安装：{0}" -f $row.repo) -ForegroundColor Green
            }
        }
        finally
        {
            if (Test-Path $tmp) { Remove-Item -Path $tmp -Recurse -Force }
        }
        return
    }

    foreach ($row in $Targets)
    {
        $dest = [IO.Path]::Combine($Root, $row.repo)
        if (Test-Path $dest)
        {
            Write-Host ("跳过（已存在）：{0}" -f $row.repo) -ForegroundColor DarkGray
            continue
        }
        Write-Host ("克隆：{0}" -f $row.repo) -ForegroundColor Green
        git clone --depth 1 "https://github.com/$Org/$($row.repo).git" $dest
        if ($LASTEXITCODE -ne 0)
        {
            Write-Warning ("克隆失败：{0}" -f $row.repo)
        }
    }
}

function Invoke-Update
{
    param($Targets)

    foreach ($row in $Targets)
    {
        $dest = [IO.Path]::Combine($Root, $row.repo)
        if (-not (Test-Path $dest))
        {
            Write-Host ("尚未安装，先克隆：{0}" -f $row.repo) -ForegroundColor Yellow
            git clone --depth 1 "https://github.com/$Org/$($row.repo).git" $dest
            continue
        }
        Write-Host ("更新：{0}" -f $row.repo) -ForegroundColor Green
        git -C $dest pull --ff-only
    }
}

function Invoke-Enable
{
    param($Targets)

    $skillsRoot = [IO.Path]::Combine($Project, '.trae', 'skills')
    New-Item -ItemType Directory -Force -Path $skillsRoot | Out-Null

    foreach ($row in $Targets)
    {
        $src = [IO.Path]::Combine($Root, $row.repo)
        if (-not (Test-Path $src))
        {
            Write-Warning ("未安装，跳过启用：{0}（先执行 -Action install）" -f $row.repo)
            continue
        }
        if ($row.large -eq '1' -and -not $IncludeLarge)
        {
            Write-Warning ("大型库默认不启用：{0}（追加 -IncludeLarge 强制启用）" -f $row.repo)
            continue
        }

        $skillFiles = @(Get-ChildItem -Path $src -Recurse -Filter 'SKILL.md' -File -ErrorAction SilentlyContinue)
        if ($skillFiles.Count -eq 0)
        {
            Write-Warning ("未找到 SKILL.md：{0}" -f $row.repo)
            continue
        }

        $used = @{}
        $count = 0
        foreach ($f in $skillFiles)
        {
            $skillDir = Split-Path -Parent $f.FullName
            $leaf = Split-Path -Leaf $skillDir
            $prefix = "wife-legal-$($row.repo)-$leaf"
            if ($used.ContainsKey($prefix))
            {
                $used[$prefix] = $used[$prefix] + 1
                $prefix = "$prefix-$($used[$prefix])"
            }
            else
            {
                $used[$prefix] = 1
            }
            $target = [IO.Path]::Combine($skillsRoot, $prefix)
            if (Test-Path $target)
            {
                Remove-Item -Path $target -Recurse -Force
            }
            Copy-Item -Path $skillDir -Destination $target -Recurse -Force
            $count++
        }
        Write-Host ("启用：{0} -> {1} 个技能" -f $row.repo, $count) -ForegroundColor Green
    }
}

function Invoke-Disable
{
    param($Targets)

    $skillsRoot = [IO.Path]::Combine($Project, '.trae', 'skills')
    if (-not (Test-Path $skillsRoot))
    {
        Write-Host '目标项目没有 .trae/skills，无需停用'
        return
    }
    foreach ($row in $Targets)
    {
        $pattern = "wife-legal-$($row.repo)-*"
        $dirs = @(Get-ChildItem -Path $skillsRoot -Directory -Filter $pattern -ErrorAction SilentlyContinue)
        foreach ($d in $dirs)
        {
            Remove-Item -Path $d.FullName -Recurse -Force
        }
        Write-Host ("停用：{0}（移除 {1} 个目录）" -f $row.repo, $dirs.Count) -ForegroundColor Green
    }
}

function Show-Status
{
    param($Catalog)

    foreach ($row in $Catalog)
    {
        $dest = [IO.Path]::Combine($Root, $row.repo)
        $installed = Test-Path $dest
        $enabled = 0
        $skillsRoot = [IO.Path]::Combine($Project, '.trae', 'skills')
        if (Test-Path $skillsRoot)
        {
            $enabled = @(Get-ChildItem -Path $skillsRoot -Directory -Filter "wife-legal-$($row.repo)-*" -ErrorAction SilentlyContinue).Count
        }
        $state = if ($installed) { '已安装' } else { '未安装' }
        Write-Host ("{0,-48} {1,-6} 已启用 {2}" -f $row.repo, $state, $enabled)
    }
}

# 删除技能库中已安装的仓（uninstall；只删技能库目录，启用目录用 disable 单独清理）
function Invoke-Uninstall
{
    param($Targets)

    $existing = @($Targets | Where-Object { Test-Path ([IO.Path]::Combine($Root, $_.repo)) })
    if ($existing.Count -eq 0)
    {
        Write-Host '所选仓库均未安装，无需删除'
        return
    }

    # 交互确认（-NonInteractive / -Force 跳过，便于脚本调用）
    if (-not $NonInteractive -and -not $Force)
    {
        Write-Host ("将删除以下 {0} 个仓库（位于 {1}）：" -f $existing.Count, $Root) -ForegroundColor Yellow
        $existing | ForEach-Object { Write-Host ("  - {0}" -f $_.repo) }
        $answer = Read-Host '确认删除？输入 y 确认'
        if ($answer -notmatch '^[yY]')
        {
            Write-Host '已取消删除'
            return
        }
    }

    foreach ($row in $existing)
    {
        $dest = [IO.Path]::Combine($Root, $row.repo)
        Remove-Item -Path $dest -Recurse -Force
        Write-Host ("已删除：{0}" -f $row.repo) -ForegroundColor Green
    }
}

# 扫描本地安装状态；-Json 时输出网页可导入的 JSON
function Show-Scan
{
    param($Catalog)

    $repos = @()
    foreach ($row in $Catalog)
    {
        $dest = [IO.Path]::Combine($Root, $row.repo)
        $isInstalled = Test-Path $dest
        $enabled = 0
        $head = $null
        $skillsRoot = [IO.Path]::Combine($Project, '.trae', 'skills')
        if (Test-Path $skillsRoot)
        {
            $enabled = @(Get-ChildItem -Path $skillsRoot -Directory -Filter "wife-legal-$($row.repo)-*" -ErrorAction SilentlyContinue).Count
        }
        if ($isInstalled -and (Test-Path (Join-Path $dest '.git')))
        {
            $head = (git -C $dest rev-parse --short HEAD 2>$null)
            if ($LASTEXITCODE -ne 0) { $head = $null }
        }
        $repos += [ordered]@{
            repo = $row.repo
            category = $row.category
            large = $row.large
            installed = $isInstalled
            enabled = $enabled
            head = $head
        }
    }

    if ($Json)
    {
        $out = [ordered]@{
            type = 'wife-legal-scan'
            version = 1
            scannedAt = (Get-Date).ToUniversalTime().ToString('o')
            root = $Root
            project = $Project
            repos = $repos
        }
        $out | ConvertTo-Json -Depth 5 | Write-Output
        return
    }

    foreach ($r in $repos)
    {
        $state = if ($r.installed) { '已安装' } else { '未安装' }
        Write-Host ("{0,-48} {1,-6} 已启用 {2}" -f $r.repo, $state, $r.enabled)
    }
}

# ---------- 主流程 ----------
$catalog = Get-Catalog

# 读取网页导出的选择配置（-Config）：仓库清单并入选择，root / org / topic / offline 可一并接管
if ($Config)
{
    if (-not (Test-Path $Config))
    {
        throw "配置文件不存在：$Config"
    }
    $cfg = Get-Content -Path $Config -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $cfg.selected)
    {
        throw "配置文件里没有 selected 字段，确认是网页导出的 wife-legal-selection.json"
    }
    $cfgRepos = @($cfg.selected | ForEach-Object { $_.repo })
    Write-Host ("已从配置读取 {0} 个仓库选择（{1}）" -f $cfgRepos.Count, $Config) -ForegroundColor Cyan
    if ($Repo.Count -eq 0)
    {
        $Repo = $cfgRepos
    }
    if (-not $Root -and $cfg.root) { $Root = $cfg.root }
    if ($cfg.org) { $Org = $cfg.org }
    if ($cfg.topic) { $Topic = $cfg.topic }
    if (-not $Offline -and $cfg.mode -eq 'offline') { $Offline = Join-Path $repoRoot 'wife-legal-offline-bundle.zip' }
}

# 用 topic 发现结果校验 catalog（发现多出的仓时提示补录）
$discovered = Get-DiscoveredRepos
if ($discovered -and $discovered.Count -gt 0)
{
    $known = @($catalog | ForEach-Object { $_.repo })
    $missing = @($discovered | Where-Object { $known -notcontains $_ })
    if ($missing.Count -gt 0)
    {
        Write-Warning ("以下仓库带 topic {0} 但未登记到 catalog.tsv：{1}" -f $Topic, ($missing -join ', '))
    }
}

if (-not $Root)
{
    $Root = Get-DefaultRoot
}

switch ($Action)
{
    'list'
    {
        Show-Catalog -Catalog $catalog
        Write-Host ''
        Write-Host ("技能库根目录：{0}" -f $Root)
        break
    }
    'status'
    {
        if ($Json) { Show-Scan -Catalog $catalog } else { Show-Status -Catalog $catalog }
        break
    }
    'scan'
    {
        Show-Scan -Catalog $catalog
        break
    }
    default
    {
        $targets = Select-Repos -Catalog $catalog
        if (-not $targets -or $targets.Count -eq 0)
        {
            Write-Warning '没有选中任何仓库'
            break
        }
        Write-Host ''
        Write-Host ("技能库根目录：{0}" -f $Root)
        Write-Host ("目标项目：{0}" -f $Project)
        Write-Host ''

        switch ($Action)
        {
            'install'   { Invoke-Install   -Targets $targets }
            'update'    { Invoke-Update    -Targets $targets }
            'uninstall' { Invoke-Uninstall -Targets $targets }
            'enable'    { Invoke-Enable    -Targets $targets }
            'disable'   { Invoke-Disable   -Targets $targets }
        }
        break
    }
}
