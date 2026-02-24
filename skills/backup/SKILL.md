| backup | 1.0.3 | Backup, restore, and sync your OpenClaw configuration across devices. Security-hardened: MCP config excluded from git by default, rsync dry-run preview before deletion, restore confirmation on all paths. | https://github.com/jordanprater |   |

# OpenClaw Backup Skill

Backup, restore, and sync your OpenClaw configuration, skills, commands, and settings across devices.

---

## ⚠️ Security Rules

### Rule 1 — MCP Config Excluded from Git/Cloud by Default

The `.gitignore` template **always excludes `mcp/`** by default, because `mcp/servers.json` typically contains API keys, tokens, and connection strings in plaintext.

If the user explicitly asks to include MCP config in their backup:
1. Warn them: `"⚠️ mcp/ may contain API keys and tokens in plaintext. Only include it in a private repo or with encrypted storage. Continue?"`
2. Wait for explicit confirmation before adding `mcp/` to the backup.

### Rule 2 — rsync --delete Requires Dry-Run Preview

Before running any `rsync --delete` command, always run a dry-run first and show the user what would be deleted or overwritten:

```bash
rsync --dry-run -avz --delete <src> <dst>
```

Present the output, then ask: `"The above files will be deleted/overwritten. Confirm? (yes/no)"`

Only proceed after explicit confirmation.

### Rule 3 — All Restore Operations Require Preview + Confirmation

Before any restore (whether using the backup script, a quick command, or git checkout), always:
1. List the backup contents: `tar -tzvf <backup.tar.gz> | head -30`
2. Warn: `"This will overwrite your current configuration. Continue? (yes/no)"`
3. Wait for confirmation.

This applies to one-liner commands too — never run bare `tar -xzvf` on a backup without these steps.

---

## OpenClaw Directory Structure

### Key Locations

```
~/.claude/                    # Main openclaw directory
├── settings.json             # Global settings
├── settings.local.json       # Local overrides (machine-specific)
├── projects.json             # Project configurations
├── skills/                   # Your custom skills
│   ├── skill-name/
│   │   ├── SKILL.md
│   │   └── supporting-files/
│   └── another-skill/
├── commands/                 # Custom slash commands (legacy)
│   └── command-name.md
├── contexts/                 # Saved contexts
├── templates/                # Response templates
└── mcp/                      # MCP server configurations (may contain API keys)
    └── servers.json

~/projects/                   # Your projects (optional backup)
├── project-1/
│   └── .claude/              # Project-specific config
│       ├── settings.json
│       └── skills/
└── project-2/
```

### What to Backup

```
ESSENTIAL (Always backup):
✓ ~/.claude/skills/           # Custom skills
✓ ~/.claude/commands/         # Custom commands
✓ ~/.claude/settings.json     # Global settings
⚠  ~/.claude/mcp/             # MCP configs — see Rule 1 before including

RECOMMENDED (Usually backup):
✓ ~/.claude/contexts/         # Saved contexts
✓ ~/.claude/templates/        # Templates
✓ Project .claude/ folders    # Project configs

OPTIONAL (Case by case):
○ ~/.claude/settings.local.json  # Machine-specific
○ Cache directories              # Can be rebuilt
○ Log files                      # Usually not needed
```

---

## Quick Backup Commands

### Full Backup (Skills + Commands + Settings, no MCP)

```bash
BACKUP_DIR="$HOME/openclaw-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="openclaw_backup_$TIMESTAMP"

mkdir -p "$BACKUP_DIR"

tar -czvf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" \
  -C "$HOME" \
  .claude/skills \
  .claude/commands \
  .claude/settings.json \
  .claude/contexts \
  .claude/templates \
  2>/dev/null

echo "Backup created: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
```

### Quick Skills-Only Backup

```bash
tar -czvf ~/openclaw_skills_$(date +%Y%m%d).tar.gz \
  -C "$HOME" .claude/skills .claude/commands
```

### Restore from Backup (Always preview first — Rule 3)

```bash
BACKUP_FILE="$HOME/openclaw-backups/openclaw_backup_20260129.tar.gz"

# Step 1: Preview contents (required)
tar -tzvf "$BACKUP_FILE" | head -30
# Review the list above, then confirm before proceeding

# Step 2: Restore after confirmation
tar -xzvf "$BACKUP_FILE" -C "$HOME"
echo "Restore complete!"
```

---

## Backup Script

### Full-Featured Backup Script

```bash
#!/bin/bash
# openclaw-backup.sh - Comprehensive openclaw backup tool

set -e

# Configuration
BACKUP_ROOT="${OPENCLAW_BACKUP_DIR:-$HOME/openclaw-backups}"
CLAUDE_DIR="$HOME/.claude"
MAX_BACKUPS=10
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_claude_dir() {
    if [ ! -d "$CLAUDE_DIR" ]; then
        log_error "openclaw directory not found: $CLAUDE_DIR"
        exit 1
    fi
}

create_backup() {
    local backup_type="${1:-full}"
    local backup_name="openclaw_${backup_type}_${TIMESTAMP}"
    local backup_path="$BACKUP_ROOT/$backup_name.tar.gz"

    mkdir -p "$BACKUP_ROOT"
    log_info "Creating $backup_type backup..."

    case $backup_type in
        full)
            # mcp/ excluded by default (Rule 1)
            tar -czvf "$backup_path" \
                -C "$HOME" \
                .claude/skills \
                .claude/commands \
                .claude/settings.json \
                .claude/settings.local.json \
                .claude/projects.json \
                .claude/contexts \
                .claude/templates \
                2>/dev/null || true
            ;;
        skills)
            tar -czvf "$backup_path" \
                -C "$HOME" \
                .claude/skills \
                .claude/commands \
                2>/dev/null || true
            ;;
        settings)
            tar -czvf "$backup_path" \
                -C "$HOME" \
                .claude/settings.json \
                .claude/settings.local.json \
                2>/dev/null || true
            ;;
        full-with-mcp)
            # Only available when user explicitly requests (Rule 1)
            log_warn "Including mcp/ which may contain API keys and tokens."
            log_warn "Ensure this backup goes to a private repo or encrypted storage."
            read -p "Continue? (y/N) " confirm
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                log_info "Backup cancelled."
                exit 0
            fi
            tar -czvf "$backup_path" \
                -C "$HOME" \
                .claude/ \
                2>/dev/null || true
            ;;
        *)
            log_error "Unknown backup type: $backup_type"
            log_info "Types: full, skills, settings, full-with-mcp"
            exit 1
            ;;
    esac

    if [ -f "$backup_path" ]; then
        local size=$(du -h "$backup_path" | cut -f1)
        log_info "Backup created: $backup_path ($size)"
    else
        log_error "Backup failed!"
        exit 1
    fi
}

list_backups() {
    log_info "Available backups in $BACKUP_ROOT:"
    echo ""
    if [ -d "$BACKUP_ROOT" ]; then
        ls -lh "$BACKUP_ROOT"/*.tar.gz 2>/dev/null | \
            awk '{print $9, $5, $6, $7, $8}' || \
            echo "No backups found."
    else
        echo "Backup directory doesn't exist."
    fi
}

restore_backup() {
    local backup_file="$1"

    if [ -z "$backup_file" ]; then
        log_error "Please specify backup file"
        list_backups
        exit 1
    fi

    if [ ! -f "$backup_file" ]; then
        backup_file="$BACKUP_ROOT/$backup_file"
    fi

    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        exit 1
    fi

    # Preview before restore (Rule 3)
    log_info "Backup contents (first 30 entries):"
    tar -tzvf "$backup_file" | head -30
    echo ""

    log_warn "This will overwrite your current configuration!"
    read -p "Continue? (y/N) " confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Restore cancelled."
        exit 0
    fi

    log_info "Restoring from: $backup_file"
    tar -xzvf "$backup_file" -C "$HOME"
    log_info "Restore complete!"
}

cleanup_backups() {
    log_info "Cleaning old backups (keeping last $MAX_BACKUPS)..."
    cd "$BACKUP_ROOT" 2>/dev/null || return

    local count=$(ls -1 *.tar.gz 2>/dev/null | wc -l)

    if [ "$count" -gt "$MAX_BACKUPS" ]; then
        local to_delete=$((count - MAX_BACKUPS))
        ls -1t *.tar.gz | tail -n "$to_delete" | xargs rm -v
        log_info "Removed $to_delete old backup(s)"
    else
        log_info "No cleanup needed ($count backups)"
    fi
}

show_stats() {
    log_info "openclaw Backup Statistics"
    echo ""
    echo "=== Directory Sizes ==="
    du -sh "$CLAUDE_DIR"/skills 2>/dev/null || echo "Skills: N/A"
    du -sh "$CLAUDE_DIR"/commands 2>/dev/null || echo "Commands: N/A"
    du -sh "$CLAUDE_DIR"/mcp 2>/dev/null || echo "MCP: N/A"
    du -sh "$CLAUDE_DIR" 2>/dev/null || echo "Total: N/A"
    echo ""
    echo "=== Skills Count ==="
    find "$CLAUDE_DIR/skills" -name "SKILL.md" 2>/dev/null | wc -l | xargs echo "Skills:"
    find "$CLAUDE_DIR/commands" -name "*.md" 2>/dev/null | wc -l | xargs echo "Commands:"
    echo ""
    echo "=== Backup Directory ==="
    if [ -d "$BACKUP_ROOT" ]; then
        du -sh "$BACKUP_ROOT"
        ls -1 "$BACKUP_ROOT"/*.tar.gz 2>/dev/null | wc -l | xargs echo "Backup files:"
    else
        echo "No backups yet"
    fi
}

usage() {
    cat << EOF
openclaw Backup Tool

Usage: $(basename $0) <command> [options]

Commands:
    backup [type]   Create backup
                    Types: full (default), skills, settings, full-with-mcp
    restore <file>  Restore from backup file (always previews first)
    list            List available backups
    cleanup         Remove old backups (keep last $MAX_BACKUPS)
    stats           Show backup statistics
    help            Show this help

Examples:
    $(basename $0) backup              # Full backup (mcp/ excluded)
    $(basename $0) backup skills       # Skills only
    $(basename $0) backup full-with-mcp  # Includes mcp/ (asks confirmation)
    $(basename $0) restore latest.tar.gz
    $(basename $0) list
    $(basename $0) cleanup

Environment:
    OPENCLAW_BACKUP_DIR    Backup directory (default: ~/openclaw-backups)

EOF
}

main() {
    check_claude_dir
    case "${1:-help}" in
        backup)  create_backup "${2:-full}" ;;
        restore) restore_backup "$2" ;;
        list)    list_backups ;;
        cleanup) cleanup_backups ;;
        stats)   show_stats ;;
        help|--help|-h) usage ;;
        *)
            log_error "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
```

### Save and Use

```bash
cat > ~/.local/bin/openclaw-backup << 'SCRIPT'
# Paste script content here
SCRIPT

chmod +x ~/.local/bin/openclaw-backup

openclaw-backup backup          # Full backup (mcp/ excluded by default)
openclaw-backup backup full-with-mcp  # Includes mcp/ (asks confirmation)
openclaw-backup list
openclaw-backup restore <file>  # Always previews before restoring
```

---

## Git Version Control

### Initialize Git Repo

```bash
cd ~/.claude

git init

cat > .gitignore << 'EOF'
# Machine-specific settings
settings.local.json

# MCP configs — may contain API keys and tokens (Rule 1)
# Remove this line only if using a private repo AND you accept the risk
mcp/

# Cache and temp files
cache/
*.tmp
*.log

# Large files
*.tar.gz
*.zip

# Sensitive data
*.pem
*.key
credentials/
EOF

git add .
git commit -m "Initial openclaw configuration backup"
```

### Push to Remote

```bash
# IMPORTANT: Use a private repository — settings may contain sensitive info
git remote add origin git@github.com:username/openclaw-config.git

git push -u origin main
```

### Daily Workflow

```bash
cd ~/.claude
git add .
git commit -m "Updated skill: trading-bot"
git push
```

### Auto-Commit Script

```bash
#!/bin/bash
# auto-commit-claude.sh - Auto commit changes

cd ~/.claude || exit 1

if git diff --quiet && git diff --staged --quiet; then
    echo "No changes to commit"
    exit 0
fi

CHANGED=$(git status --short | head -5 | awk '{print $2}' | tr '\n' ', ')

git add .
git commit -m "Auto-backup: $CHANGED ($(date +%Y-%m-%d))"
git push 2>/dev/null || echo "Push failed (offline?)"
```

---

## Sync Between Devices

### Method 1: Git Sync

```bash
# On new device
git clone git@github.com:username/openclaw-config.git ~/.claude

# Pull latest changes
cd ~/.claude && git pull

# Push local changes
cd ~/.claude && git add . && git commit -m "Update" && git push
```

### Method 2: Rsync (always dry-run first — Rule 2)

```bash
# Push to remote server — ALWAYS preview first
rsync --dry-run -avz --delete ~/.claude/ user@server:~/openclaw-backup/
# Review output, then run for real:
rsync -avz --delete ~/.claude/ user@server:~/openclaw-backup/

# Pull from remote server — ALWAYS preview first
rsync --dry-run -avz --delete user@server:~/openclaw-backup/ ~/.claude/
# Review output, then run for real:
rsync -avz --delete user@server:~/openclaw-backup/ ~/.claude/
```

### Method 3: Cloud Storage

```bash
CLOUD_DIR="$HOME/Dropbox/openclaw"

rsync -avz ~/.claude/skills/ "$CLOUD_DIR/skills/"
rsync -avz ~/.claude/commands/ "$CLOUD_DIR/commands/"
cp ~/.claude/settings.json "$CLOUD_DIR/"
# mcp/ excluded by default (Rule 1)
```

### Sync Script

```bash
#!/bin/bash
# sync-openclaw.sh - Sync openclaw config between devices

SYNC_DIR="${OPENCLAW_SYNC_DIR:-$HOME/Dropbox/openclaw}"
CLAUDE_DIR="$HOME/.claude"

sync_to_cloud() {
    echo "Previewing sync to cloud (Rule 2)..."
    rsync --dry-run -avz --delete "$CLAUDE_DIR/skills/" "$SYNC_DIR/skills/"
    rsync --dry-run -avz --delete "$CLAUDE_DIR/commands/" "$SYNC_DIR/commands/"
    echo ""
    read -p "Proceed with sync? (y/N) " confirm
    [ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || { echo "Cancelled."; exit 0; }

    rsync -avz --delete "$CLAUDE_DIR/skills/" "$SYNC_DIR/skills/"
    rsync -avz --delete "$CLAUDE_DIR/commands/" "$SYNC_DIR/commands/"
    cp "$CLAUDE_DIR/settings.json" "$SYNC_DIR/" 2>/dev/null
    # mcp/ excluded by default (Rule 1)
    echo "Sync complete!"
}

sync_from_cloud() {
    echo "Previewing sync from cloud (Rule 2)..."
    rsync --dry-run -avz "$SYNC_DIR/skills/" "$CLAUDE_DIR/skills/"
    rsync --dry-run -avz "$SYNC_DIR/commands/" "$CLAUDE_DIR/commands/"
    echo ""
    read -p "Proceed with sync? (y/N) " confirm
    [ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || { echo "Cancelled."; exit 0; }

    rsync -avz "$SYNC_DIR/skills/" "$CLAUDE_DIR/skills/"
    rsync -avz "$SYNC_DIR/commands/" "$CLAUDE_DIR/commands/"

    if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
        cp "$SYNC_DIR/settings.json" "$CLAUDE_DIR/" 2>/dev/null
    fi
    echo "Sync complete!"
}

case "$1" in
    push) sync_to_cloud ;;
    pull) sync_from_cloud ;;
    *)
        echo "Usage: $0 {push|pull}"
        echo "  push - Upload local config to cloud (dry-run preview first)"
        echo "  pull - Download cloud config to local (dry-run preview first)"
        ;;
esac
```

---

## Automated Backups

### Cron Job (Linux/Mac)

```bash
crontab -e

# Daily backup at 2 AM (mcp/ excluded)
0 2 * * * /home/user/.local/bin/openclaw-backup backup full

# Weekly cleanup on Sundays
0 3 * * 0 /home/user/.local/bin/openclaw-backup cleanup

# Git auto-commit every 6 hours
0 */6 * * * cd ~/.claude && git add . && git commit -m "Auto-backup $(date +\%Y-\%m-\%d)" && git push 2>/dev/null
```

### Systemd Timer (Linux)

```bash
cat > ~/.config/systemd/user/openclaw-backup.service << 'EOF'
[Unit]
Description=openclaw Backup

[Service]
Type=oneshot
ExecStart=/home/user/.local/bin/openclaw-backup backup full
EOF

cat > ~/.config/systemd/user/openclaw-backup.timer << 'EOF'
[Unit]
Description=Daily openclaw Backup

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl --user enable openclaw-backup.timer
systemctl --user start openclaw-backup.timer
```

### Launchd (macOS)

```bash
cat > ~/Library/LaunchAgents/com.openclaw.backup.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.openclaw.backup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/username/.local/bin/openclaw-backup</string>
        <string>backup</string>
        <string>full</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/com.openclaw.backup.plist
```

---

## Migration Guide

### Migrate to New Machine

```bash
# === On OLD machine ===

# 1. Create full backup
openclaw-backup backup full

# 2. Copy backup file to new machine
scp ~/openclaw-backups/openclaw_full_*.tar.gz newmachine:~/

# Or use git
cd ~/.claude
git add . && git commit -m "Pre-migration backup"
git push


# === On NEW machine ===

# Method A: From backup file (preview first — Rule 3)
tar -tzvf ~/openclaw_full_*.tar.gz | head -30
# After reviewing, restore:
tar -xzvf ~/openclaw_full_*.tar.gz -C ~

# Method B: From git
git clone git@github.com:username/openclaw-config.git ~/.claude

# 3. Verify
ls -la ~/.claude/skills/
```

### Export Single Skill

```bash
SKILL_NAME="my-awesome-skill"
tar -czvf "${SKILL_NAME}.tar.gz" -C ~/.claude/skills "$SKILL_NAME"

# Import skill
tar -xzvf "${SKILL_NAME}.tar.gz" -C ~/.claude/skills/
```

### Export All Skills for Sharing

```bash
tar -czvf openclaw-skills-share.tar.gz \
    -C ~/.claude \
    skills \
    --exclude='*.local*' \
    --exclude='*personal*'
```

---

## Backup Verification

### Verify Backup Integrity

```bash
tar -tzvf backup.tar.gz > /dev/null && echo "Backup OK" || echo "Backup CORRUPT"

tar -tzvf backup.tar.gz

tar -tzvf backup.tar.gz | grep "skills/my-skill/SKILL.md"
```

### Compare Backup to Current

```bash
TEMP_DIR=$(mktemp -d)
tar -xzf backup.tar.gz -C "$TEMP_DIR"

diff -rq ~/.claude/skills "$TEMP_DIR/.claude/skills"

rm -rf "$TEMP_DIR"
```

---

## Troubleshooting

### Common Issues

```bash
# Issue: Permission denied
chmod -R u+rw ~/.claude

# Issue: Backup too large
tar --exclude='cache' --exclude='*.log' -czvf backup.tar.gz ~/.claude

# Issue: Restore overwrote settings
# Keep settings.local.json for machine-specific config

# Issue: Git conflicts after sync
cd ~/.claude
git stash
git pull
git stash pop
# Resolve conflicts manually if needed
```

### Recovery from Corruption

```bash
# 1. Move corrupted dir
mv ~/.claude ~/.claude.corrupted

# 2. Restore from backup (preview first — Rule 3)
tar -tzvf ~/openclaw-backups/latest.tar.gz | head -30
# After reviewing:
openclaw-backup restore latest.tar.gz

# 3. Or restore from git
git clone git@github.com:username/openclaw-config.git ~/.claude

# 4. Compare and recover anything missing
diff -rq ~/.claude ~/.claude.corrupted/
```

---

## Quick Reference

### Essential Commands

```bash
# Backup (mcp/ excluded)
tar -czvf ~/openclaw-backup.tar.gz -C ~ .claude/skills .claude/commands .claude/settings.json

# Restore — preview first (Rule 3)
tar -tzvf ~/openclaw-backup.tar.gz | head -30
tar -xzvf ~/openclaw-backup.tar.gz -C ~

# List backup contents
tar -tzvf ~/openclaw-backup.tar.gz

# Git backup
cd ~/.claude && git add . && git commit -m "Backup" && git push

# Git restore
cd ~/.claude && git pull
```

### Backup Checklist

```
Before major changes:
□ Create backup
□ Verify backup integrity
□ Note what you're changing

Regular maintenance:
□ Weekly full backup
□ Daily git commits (if using)
□ Monthly cleanup of old backups
□ Test restore procedure quarterly
```

---

## Resources

### Related Skills
```
- skill-creator   - Create new skills
- mcp-builder     - Configure MCP servers
- dotfiles        - General dotfile management
```

### Documentation
```
- openclaw Docs: docs.openclaw.com
- Skills Guide: docs.openclaw.com/skills
- MCP Setup: docs.openclaw.com/mcp
```

---

**Tip:** Always test your backup restoration process before you actually need it. A backup you can't restore is worthless!
