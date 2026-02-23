# openclaw-skills

我的个人 OpenClaw / VS Code MCP Skills 库，包含安全审查和加固后的版本。

## 项目结构

```
skills/
├── aster-dedicated/   # Aster 专用 AI 手机版（全自动化，含提示词注入防护）
└── aster-safe/        # Aster 安全加固版（日常手机使用，高安全限制）
```

## 如何添加新 Skill

1. 在 `skills/` 目录下新建文件夹，命名为 skill 名称
2. 在文件夹内创建 `SKILL.md`
3. 运行 `.\deploy.ps1` 一键部署到 OpenClaw

## 一键部署到 OpenClaw

```powershell
.\deploy.ps1
```

首次运行会提示输入 OpenClaw API Key，之后保存到 `config.json`（已加入 .gitignore，不会上传）。

## VS Code MCP 配置

将 `.mcp.json` 复制到你的工作区根目录，或全局路径：
```
C:\Users\<你的用户名>\AppData\Roaming\Code\User\mcp.json
```

## Skill 安全评级说明

| 评级 | 含义 |
|------|------|
| 🟢 原版可用 | 无高风险问题 |
| 🟡 已加固 | 修复了中高风险问题后可用 |
| 🔴 不建议使用 | 存在无法修复的架构性风险 |

| Skill | 原版评级 | 本库版本 | 主要改动 |
|-------|---------|---------|---------|
| aster-dedicated | 🟡 | 🟢 加固版 | 加入提示词注入防护、金融OTP过滤 |
| aster-safe | 🟡 | 🟢 加固版 | 所有高危操作需确认、OTP禁止自动填入 |
