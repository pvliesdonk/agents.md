#!/usr/bin/env bash
set -euo pipefail

DEST="${HOME}/.config/opencode"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing agents.md package to ${DEST}"
echo "---"

# Backup existing AGENTS.md if present
if [[ -f "${DEST}/AGENTS.md" ]]; then
    BACKUP="${DEST}/AGENTS.md.bak.$(date +%Y%m%d%H%M%S)"
    echo "Backing up existing AGENTS.md -> ${BACKUP}"
    cp "${DEST}/AGENTS.md" "${BACKUP}"
fi

# Create directories
mkdir -p "${DEST}/agents"
for skill_dir in "${SCRIPT_DIR}"/skills/*/; do
    name="$(basename "${skill_dir}")"
    mkdir -p "${DEST}/skills/${name}"
done

# Install AGENTS.md
cp "${SCRIPT_DIR}/AGENTS.md" "${DEST}/AGENTS.md"
echo "  AGENTS.md"

# Install agents
for agent in "${SCRIPT_DIR}"/agents/*.md; do
    name="$(basename "${agent}")"
    cp "${agent}" "${DEST}/agents/${name}"
    echo "  agents/${name}"
done

# Install skills
for skill_dir in "${SCRIPT_DIR}"/skills/*/; do
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
echo "Restart opencode to pick up changes."
