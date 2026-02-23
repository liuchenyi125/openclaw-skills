"""
自动扫描 skills/ 目录，读取每个 SKILL.md 第一行元数据，生成 skills.json
用法: python3 scripts/generate_manifest.py
"""
import json
import os
from datetime import datetime, timezone

OWNER = "liuchenyi125"
REPO  = "openclaw-skills"
BASE  = f"https://github.com/{OWNER}/{REPO}/blob/main/skills"

root     = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
skills_dir = os.path.join(root, "skills")

skills = []

for skill_id in sorted(os.listdir(skills_dir)):
    skill_path = os.path.join(skills_dir, skill_id)
    md_path    = os.path.join(skill_path, "SKILL.md")

    if not os.path.isdir(skill_path) or not os.path.exists(md_path):
        continue

    with open(md_path, "r", encoding="utf-8") as f:
        first_line = f.readline().strip()

    # 解析格式: | name | version | description | homepage |   |
    parts = [p.strip() for p in first_line.split("|") if p.strip()]
    if len(parts) < 3:
        print(f"  ⚠️  跳过 {skill_id}：无法解析元数据（需要表格格式首行）")
        continue

    skills.append({
        "id":          skill_id,
        "name":        parts[0],
        "version":     parts[1],
        "description": parts[2],
        "homepage":    parts[3] if len(parts) > 3 else "",
        "url":         f"{BASE}/{skill_id}/SKILL.md"
    })
    print(f"  ✅  {parts[0]}  v{parts[1]}")

manifest = {
    "owner":   OWNER,
    "repo":    REPO,
    "updated": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
    "skills":  skills
}

out_path = os.path.join(root, "skills.json")
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)

print(f"\n生成完毕：skills.json（共 {len(skills)} 个 skill）")
