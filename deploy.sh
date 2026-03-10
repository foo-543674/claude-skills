#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SRC="${SCRIPT_DIR}/skills"

# Determine Claude Code skills directory
SKILLS_DEST="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}/skills"

echo "Source:      ${SKILLS_SRC}"
echo "Destination: ${SKILLS_DEST}"

mkdir -p "${SKILLS_DEST}"

# Copy skills (overwrite existing)
installed=0
for skill_dir in "${SKILLS_SRC}"/*/; do
  [[ -d "$skill_dir" ]] || continue
  name="$(basename "$skill_dir")"
  rm -rf "${SKILLS_DEST}/${name}"
  cp -r "$skill_dir" "${SKILLS_DEST}/${name}"
  echo "  Installed: ${name}"
  installed=$((installed + 1))
done

echo ""
echo "Done. ${installed} skills installed to ${SKILLS_DEST}"
