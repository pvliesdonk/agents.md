#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-opencode}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Determine target configuration
case "$TARGET" in
  opencode)
    DEST="${HOME}/.config/opencode"
    AGENTS_SRC="agents"
    SKILLS_SRC="skills"
    CONFIG_FILE="AGENTS.md"
    RESTART_MSG="Restart opencode to pick up changes."
    ;;
  claude)
    DEST="${HOME}/.claude"
    AGENTS_SRC="claude-agents"
    SKILLS_SRC="claude-skills"
    CONFIG_FILE="AGENTS.md"
    RESTART_MSG="Restart Claude Code to pick up changes."
    ;;
  both)
    echo "Installing for both OpenCode and Claude Code..."
    echo ""
    "$0" opencode
    echo ""
    "$0" claude
    exit 0
    ;;
  *)
    echo "Usage: $0 [opencode|claude|both]"
    echo ""
    echo "  opencode  Install to ~/.config/opencode (default)"
    echo "  claude    Install to ~/.claude"
    echo "  both      Install to both locations"
    exit 1
    ;;
esac

echo "Installing agents.md package for ${TARGET} to ${DEST}"
echo "---"

# Backup existing AGENTS.md if present
if [[ -f "${DEST}/${CONFIG_FILE}" ]]; then
    BACKUP="${DEST}/${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    echo "Backing up existing ${CONFIG_FILE} -> ${BACKUP}"
    cp "${DEST}/${CONFIG_FILE}" "${BACKUP}"
fi

# Create directories
mkdir -p "${DEST}/agents"
for skill_dir in "${SCRIPT_DIR}/${SKILLS_SRC}"/*/; do
    name="$(basename "${skill_dir}")"
    mkdir -p "${DEST}/skills/${name}"
done

# Copy hooks examples (always from .claude/hooks/examples)
if [[ -d "${SCRIPT_DIR}/.claude/hooks/examples" ]]; then
    mkdir -p "${DEST}/hooks/examples"
    cp -r "${SCRIPT_DIR}/.claude/hooks/examples"/* "${DEST}/hooks/examples/"
    echo "  hooks/examples/ ($(ls -1 "${SCRIPT_DIR}/.claude/hooks/examples" | wc -l | tr -d ' ') files)"
fi

# Install AGENTS.md (same for both)
cp "${SCRIPT_DIR}/${CONFIG_FILE}" "${DEST}/${CONFIG_FILE}"
echo "  ${CONFIG_FILE}"

# Install agents
for agent in "${SCRIPT_DIR}/${AGENTS_SRC}"/*.md; do
    name="$(basename "${agent}")"
    cp "${agent}" "${DEST}/agents/${name}"
    echo "  agents/${name}"
done

# Install skills
for skill_dir in "${SCRIPT_DIR}/${SKILLS_SRC}"/*/; do
    name="$(basename "${skill_dir}")"
    if [[ -f "${skill_dir}/SKILL.md" ]]; then
        cp "${skill_dir}/SKILL.md" "${DEST}/skills/${name}/SKILL.md"
        echo "  skills/${name}/SKILL.md"
    fi
done

echo "---"
echo ""

agent_count=$(ls "${DEST}/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')
skill_count=$(ls "${DEST}/skills/"*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
echo "Installed: ${agent_count} agents, ${skill_count} skills"
echo ""
echo "${RESTART_MSG}"
