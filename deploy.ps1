# OpenClaw / VS Code MCP Skills 一键部署脚本
# 用法: .\deploy.ps1 [-SkillName <name>] [-DryRun]
# 示例: .\deploy.ps1                    # 部署所有 skills
#       .\deploy.ps1 -SkillName aster-dedicated   # 只部署指定 skill
#       .\deploy.ps1 -DryRun             # 预览，不实际发送

param(
    [string]$SkillName = "",
    [switch]$DryRun
)

$configFile = Join-Path $PSScriptRoot "config.json"
$skillsDir  = Join-Path $PSScriptRoot "skills"

# ── 读取或初始化配置 ────────────────────────────────────────────────────────────
function Get-Config {
    if (Test-Path $configFile) {
        return Get-Content $configFile | ConvertFrom-Json
    }
    Write-Host ""
    Write-Host "首次运行，请配置 OpenClaw API Key" -ForegroundColor Cyan
    Write-Host "获取地址: https://openclaw.ai/settings/api" -ForegroundColor DarkGray
    $apiKey = Read-Host "请输入你的 OpenClaw API Key"
    $endpoint = Read-Host "OpenClaw API 地址 (直接回车使用默认 https://api.openclaw.ai)"
    if (-not $endpoint) { $endpoint = "https://api.openclaw.ai" }

    $config = @{ apiKey = $apiKey; endpoint = $endpoint }
    $config | ConvertTo-Json | Set-Content $configFile
    Write-Host "配置已保存到 config.json（不会上传到 GitHub）" -ForegroundColor Green
    return $config | ConvertFrom-Json
}

# ── 解析 SKILL.md 第一行的元数据表格 ────────────────────────────────────────────
function Parse-SkillMeta {
    param([string]$content)
    # 格式: | name | version | description | url |   |
    $firstLine = ($content -split "`n")[0].Trim()
    if ($firstLine -match '^\|\s*(.+?)\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|') {
        return @{
            name        = $Matches[1]
            version     = $Matches[2]
            description = $Matches[3]
            url         = $Matches[4]
        }
    }
    return $null
}

# ── 部署单个 Skill ───────────────────────────────────────────────────────────────
function Deploy-Skill {
    param([string]$skillPath, [PSCustomObject]$config)

    $skillMdPath = Join-Path $skillPath "SKILL.md"
    if (-not (Test-Path $skillMdPath)) {
        Write-Host "  ⚠️  未找到 SKILL.md，跳过: $skillPath" -ForegroundColor Yellow
        return
    }

    $content = Get-Content $skillMdPath -Raw -Encoding UTF8
    $meta    = Parse-SkillMeta -content $content

    if (-not $meta) {
        Write-Host "  ❌ 无法解析 SKILL.md 元数据，跳过: $skillPath" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "  📦 Skill: $($meta.name)  v$($meta.version)" -ForegroundColor Cyan
    Write-Host "     $($meta.description)" -ForegroundColor DarkGray

    if ($DryRun) {
        Write-Host "  [DryRun] 跳过实际上传" -ForegroundColor DarkYellow
        return
    }

    # 调用 OpenClaw API 上传 skill
    $body = @{
        name        = $meta.name
        version     = $meta.version
        description = $meta.description
        url         = $meta.url
        content     = $content
    } | ConvertTo-Json -Depth 5

    try {
        $response = Invoke-RestMethod `
            -Uri "$($config.endpoint)/v1/skills/import" `
            -Method POST `
            -Headers @{ "Authorization" = "Bearer $($config.apiKey)"; "Content-Type" = "application/json" } `
            -Body $body `
            -ErrorAction Stop

        Write-Host "  ✅ 部署成功: $($meta.name)" -ForegroundColor Green
        if ($response.id) {
            Write-Host "     Skill ID: $($response.id)" -ForegroundColor DarkGray
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "  ❌ 部署失败 (HTTP $statusCode): $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "     请检查 API Key 和网络连接，或手动导入 SKILL.md 到 OpenClaw 控制台" -ForegroundColor DarkGray
        Write-Host "     手动导入地址: https://openclaw.ai/skills/import" -ForegroundColor DarkGray
    }
}

# ── 主流程 ───────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "   OpenClaw Skills 部署工具" -ForegroundColor Cyan
if ($DryRun) { Write-Host "   [DryRun 模式 — 不会实际上传]" -ForegroundColor DarkYellow }
Write-Host "═══════════════════════════════════════════" -ForegroundColor DarkCyan

$config = Get-Config

# 收集要部署的 skills
if ($SkillName) {
    $targets = @(Join-Path $skillsDir $SkillName)
    if (-not (Test-Path $targets[0])) {
        Write-Host "❌ 未找到 skill: $SkillName" -ForegroundColor Red
        exit 1
    }
} else {
    $targets = Get-ChildItem -Path $skillsDir -Directory | Select-Object -ExpandProperty FullName
}

Write-Host ""
Write-Host "找到 $($targets.Count) 个 Skill，开始部署..." -ForegroundColor White

# 重新生成 skills.json
Write-Host ""
Write-Host "🔄 更新 skills.json..." -ForegroundColor Cyan
python3 "$PSScriptRoot/scripts/generate_manifest.py"
if ($LASTEXITCODE -eq 0) {
    git -C $PSScriptRoot add skills.json
    $changed = git -C $PSScriptRoot diff --cached --name-only
    if ($changed) {
        git -C $PSScriptRoot commit -m "auto: update skills.json"
        git -C $PSScriptRoot push
        Write-Host "  ✅ skills.json 已更新并推送" -ForegroundColor Green
    } else {
        Write-Host "  ✅ skills.json 无变更" -ForegroundColor DarkGray
    }
} else {
    Write-Host "  ⚠️  生成 skills.json 失败，跳过" -ForegroundColor Yellow
}

foreach ($target in $targets) {
    Deploy-Skill -skillPath $target -config $config
}

Write-Host ""
Write-Host "═══════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "   完成！" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host ""
