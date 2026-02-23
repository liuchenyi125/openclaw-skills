# GitHub 一键配置脚本
# 自动完成：添加 SSH 公钥 → 创建远程仓库 → 推送代码
# 用法: .\setup-github.ps1

param(
    [string]$RepoName = "openclaw-skills",
    [string]$GitHubUser = "liuchenyi125"
)

Write-Host ""
Write-Host "═══════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "   GitHub 一键配置工具" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "需要一个 GitHub Personal Access Token（PAT）" -ForegroundColor White
Write-Host ""
Write-Host "创建步骤：" -ForegroundColor Yellow
Write-Host "  1. 打开 https://github.com/settings/tokens/new" -ForegroundColor DarkGray
Write-Host "  2. Token name: openclaw-skills-setup" -ForegroundColor DarkGray
Write-Host "  3. Expiration: 7 days（用完即可过期）" -ForegroundColor DarkGray
Write-Host "  4. 勾选 Scopes:" -ForegroundColor DarkGray
Write-Host "       ✅ repo（完整仓库权限）" -ForegroundColor DarkGray
Write-Host "       ✅ admin:public_key（添加 SSH 公钥）" -ForegroundColor DarkGray
Write-Host "  5. 点击 Generate token，复制 token" -ForegroundColor DarkGray
Write-Host ""

$token = Read-Host "请粘贴你的 GitHub Token"
if (-not $token) { Write-Host "❌ Token 不能为空" -ForegroundColor Red; exit 1 }

$headers = @{
    "Authorization" = "token $token"
    "Accept"        = "application/vnd.github.v3+json"
    "User-Agent"    = "openclaw-skills-setup"
}

# ── Step 1: 添加 SSH 公钥 ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "Step 1/3  添加 SSH 公钥到 GitHub..." -ForegroundColor Cyan

$pubKeyPath = "$env:USERPROFILE\.ssh\id_rsa.pub"
if (-not (Test-Path $pubKeyPath)) {
    Write-Host "  ❌ 未找到 SSH 公钥: $pubKeyPath" -ForegroundColor Red
    exit 1
}
$pubKey = Get-Content $pubKeyPath -Raw

try {
    $keyBody = @{ title = "openclaw-skills ($env:COMPUTERNAME)"; key = $pubKey.Trim() } | ConvertTo-Json
    $keyResp  = Invoke-RestMethod -Uri "https://api.github.com/user/keys" -Method POST -Headers $headers -Body $keyBody -ContentType "application/json" -ErrorAction Stop
    Write-Host "  ✅ SSH 公钥添加成功 (ID: $($keyResp.id))" -ForegroundColor Green
}
catch {
    $msg = $_.Exception.Message
    if ($msg -match "key is already in use") {
        Write-Host "  ✅ SSH 公钥已存在，跳过" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  添加 SSH 公钥失败: $msg" -ForegroundColor Yellow
        Write-Host "     将改用 HTTPS 推送" -ForegroundColor DarkGray
    }
}

# ── Step 2: 创建 GitHub 仓库 ──────────────────────────────────────────────────
Write-Host ""
Write-Host "Step 2/3  创建 GitHub 仓库: $GitHubUser/$RepoName..." -ForegroundColor Cyan

$repoBody = @{
    name        = $RepoName
    description = "My personal OpenClaw / VS Code MCP Skills — security reviewed and hardened"
    private     = $false
    auto_init   = $false
} | ConvertTo-Json

$repoUrl = "https://github.com/$GitHubUser/$RepoName"

try {
    $repoResp = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Method POST -Headers $headers -Body $repoBody -ContentType "application/json" -ErrorAction Stop
    Write-Host "  ✅ 仓库创建成功: $repoUrl" -ForegroundColor Green
}
catch {
    $msg = $_.Exception.Message
    if ($msg -match "name already exists") {
        Write-Host "  ✅ 仓库已存在，跳过创建" -ForegroundColor Green
    } else {
        Write-Host "  ❌ 创建仓库失败: $msg" -ForegroundColor Red
        exit 1
    }
}

# ── Step 3: 推送代码 ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Step 3/3  推送代码到 GitHub..." -ForegroundColor Cyan

Set-Location $PSScriptRoot

# 先尝试 SSH，失败则用 HTTPS
$sshTest = ssh -T git@github.com 2>&1
if ($sshTest -match "successfully authenticated") {
    $remoteUrl = "git@github.com:$GitHubUser/$RepoName.git"
    Write-Host "  使用 SSH 推送" -ForegroundColor DarkGray
} else {
    $remoteUrl = "https://$token@github.com/$GitHubUser/$RepoName.git"
    Write-Host "  使用 HTTPS 推送" -ForegroundColor DarkGray
}

git remote remove origin 2>$null
git remote add origin $remoteUrl
git branch -M main
git push -u origin main 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════" -ForegroundColor DarkCyan
    Write-Host "  ✅ 全部完成！" -ForegroundColor Green
    Write-Host "  仓库地址: $repoUrl" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "后续工作流：" -ForegroundColor White
    Write-Host "  新增/修改 skill  →  git add . && git commit -m '...' && git push" -ForegroundColor DarkGray
    Write-Host "  部署到 OpenClaw  →  .\deploy.ps1" -ForegroundColor DarkGray
} else {
    Write-Host "  ❌ 推送失败，请检查 Token 权限或手动运行: git push -u origin main" -ForegroundColor Red
}
