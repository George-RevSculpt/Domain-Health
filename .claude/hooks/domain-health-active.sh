#!/bin/bash
# Domain Health — activation hook
# Fires on domain/blacklist-related prompts

SKILL_FILE="$HOME/.claude/skills/domain-health/SKILL.md"

if [ ! -f "$SKILL_FILE" ]; then
  exit 0
fi

cat <<EOF
<skill>
$(cat "$SKILL_FILE")
</skill>
EOF
