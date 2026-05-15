#!/usr/bin/env bash
#
# Install community Claude Code skills/plugins at session start.
#
# Clones a curated list of skill repos into ~/.claude/community-skills-cache/
# and exposes them via symlinks under ~/.claude/{skills,commands,agents}/.
#
# Idempotent: safe to re-run. Uses --depth 1 + `git pull` for fast refresh.

set -euo pipefail

# Run only in remote (cloud) sessions; locally the user installs via /plugin.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

CACHE_DIR="${HOME}/.claude/community-skills-cache"
SKILLS_DIR="${HOME}/.claude/skills"
COMMANDS_DIR="${HOME}/.claude/commands"
AGENTS_DIR="${HOME}/.claude/agents"

mkdir -p "$CACHE_DIR" "$SKILLS_DIR" "$COMMANDS_DIR" "$AGENTS_DIR"

# repo-spec: "github-owner/repo|local-name|optional-subpath"
# If subpath is given, only that path inside the repo is linked as a single skill
# named <local-name>. Otherwise the script auto-discovers skills using the
# patterns in install_repo().
REPOS=(
  # full repos (auto-discovery of all skills)
  "obra/superpowers|superpowers|"
  "pbakaus/impeccable|impeccable|"
  "OthmanAdi/planning-with-files|planning-with-files|"
  "Lum1104/Understand-Anything|understand-anything|"
  "trailofbits/skills|trailofbits-skills|"
  "vercel-labs/agent-browser|agent-browser|"
  "blader/humanizer|humanizer|"
  "supermemoryai/supermemory|supermemory|"
  "coreyhaines31/marketingskills|marketing|"
  # targeted: only a specific sub-skill from a big repo
  "remotion-dev/skills|remotion|skills/remotion"
  "anthropics/skills|anthropic-frontend-design|skills/frontend-design"
  "vercel-labs/agent-skills|vercel-web-design-guidelines|skills/web-design-guidelines"
  "ComposioHQ/awesome-claude-skills|composio-document|document-skills"
)

clone_or_update() {
  local repo="$1" dest="$2"
  if [ -d "$dest/.git" ]; then
    git -C "$dest" fetch --depth 1 --quiet origin HEAD 2>/dev/null || true
    git -C "$dest" reset --hard --quiet FETCH_HEAD 2>/dev/null || true
  else
    rm -rf "$dest"
    git clone --depth 1 --quiet "https://github.com/${repo}.git" "$dest" \
      || { echo "warn: failed to clone ${repo}" >&2; return 1; }
  fi
}

link_subdir_contents() {
  # link_subdir_contents <src_parent_dir> <target_dir> <prefix>
  # For each child in src_parent_dir, create a symlink in target_dir named "<prefix>-<child>"
  local src="$1" target="$2" prefix="$3"
  [ -d "$src" ] || return 0
  shopt -s nullglob
  for child in "$src"/*; do
    [ -e "$child" ] || continue
    local base name link
    base=$(basename "$child")
    name="${prefix}-${base}"
    link="${target}/${name}"
    # Skip dotfiles and obvious non-skill stuff
    case "$base" in
      .*|README*|LICENSE*|CHANGELOG*) continue ;;
    esac
    ln -sfn "$child" "$link"
  done
  shopt -u nullglob
}

install_repo() {
  local spec="$1"
  # spec format: repo|name|subpath
  IFS='|' read -r repo name subpath <<< "$spec"
  local dest="${CACHE_DIR}/${name}"

  echo "==> ${repo}${subpath:+ (only: $subpath)}"
  clone_or_update "$repo" "$dest" || return 0

  # If a subpath is specified, link only that path.
  # Two cases:
  #   a) <subpath>/SKILL.md exists → link as a single skill named <name>
  #   b) <subpath>/* contains SKILL.md files → link each child as <name>-<child>
  if [ -n "$subpath" ]; then
    local target="${dest}/${subpath}"
    if [ -f "${target}/SKILL.md" ]; then
      ln -sfn "$target" "${SKILLS_DIR}/${name}"
    elif [ -d "$target" ]; then
      link_subdir_contents "$target" "$SKILLS_DIR" "${name}"
    elif [ -f "$target" ]; then
      mkdir -p "${SKILLS_DIR}/${name}"
      ln -sfn "$target" "${SKILLS_DIR}/${name}/SKILL.md"
    else
      echo "warn: subpath '${subpath}' not found in ${repo}" >&2
    fi
    return 0
  fi

  # Common layouts:
  #   <repo>/SKILL.md              → single skill at root
  #   <repo>/skills/*/SKILL.md     → multiple skills in skills/
  #   <repo>/.claude/skills/*      → impeccable-style dist
  #   <repo>/commands/*.md         → slash commands
  #   <repo>/agents/*.md           → subagents
  #   <repo>/plugins/*/skills/*    → trailofbits-style plugin bundle

  # 1) SKILL.md at root → single skill
  if [ -f "${dest}/SKILL.md" ]; then
    ln -sfn "$dest" "${SKILLS_DIR}/${name}"
  fi

  # 2) skills/ subdir with sub-skills
  link_subdir_contents "${dest}/skills" "$SKILLS_DIR" "${name}"

  # 3) Plugin layout: plugins/<plugin>/skills/<skill>/
  if [ -d "${dest}/plugins" ]; then
    shopt -s nullglob
    for plugin_dir in "${dest}/plugins"/*; do
      [ -d "$plugin_dir" ] || continue
      local plugin_name
      plugin_name=$(basename "$plugin_dir")
      link_subdir_contents "${plugin_dir}/skills" "$SKILLS_DIR" "${name}-${plugin_name}"
      link_subdir_contents "${plugin_dir}/commands" "$COMMANDS_DIR" "${name}-${plugin_name}"
      link_subdir_contents "${plugin_dir}/agents" "$AGENTS_DIR" "${name}-${plugin_name}"
    done
    shopt -u nullglob
  fi

  # 4) impeccable-style dist
  if [ -d "${dest}/dist/claude-code/.claude/skills" ]; then
    link_subdir_contents "${dest}/dist/claude-code/.claude/skills" "$SKILLS_DIR" "${name}"
  fi
  if [ -d "${dest}/dist/claude-code/.claude/commands" ]; then
    link_subdir_contents "${dest}/dist/claude-code/.claude/commands" "$COMMANDS_DIR" "${name}"
  fi

  # 5) Top-level commands/ agents/
  link_subdir_contents "${dest}/commands" "$COMMANDS_DIR" "${name}"
  link_subdir_contents "${dest}/agents" "$AGENTS_DIR" "${name}"

  # 6) .claude/skills inside repo
  link_subdir_contents "${dest}/.claude/skills" "$SKILLS_DIR" "${name}"
  link_subdir_contents "${dest}/.claude/commands" "$COMMANDS_DIR" "${name}"
  link_subdir_contents "${dest}/.claude/agents" "$AGENTS_DIR" "${name}"

  # 7) Plugin-as-top-folder pattern: <plugin-name>/skills/<skill>/
  # e.g. Understand-Anything has understand-anything-plugin/skills/*
  shopt -s nullglob
  for top_dir in "${dest}"/*; do
    [ -d "$top_dir" ] || continue
    local top_base
    top_base=$(basename "$top_dir")
    case "$top_base" in
      skills|plugins|dist|scripts|docs|src|assets|node_modules|packages|examples|tests|test|benchmarks|evals|cli|bin|docker|homepage|READMEs|skill-data|.*)
        continue ;;
    esac
    link_subdir_contents "${top_dir}/skills" "$SKILLS_DIR" "${name}-${top_base}"
    link_subdir_contents "${top_dir}/commands" "$COMMANDS_DIR" "${name}-${top_base}"
    link_subdir_contents "${top_dir}/agents" "$AGENTS_DIR" "${name}-${top_base}"
  done
  shopt -u nullglob
}

for spec in "${REPOS[@]}"; do
  install_repo "$spec" || true
done

echo
echo "==> Installed skills:"
ls -1 "$SKILLS_DIR" 2>/dev/null | sed 's/^/  /' || true
echo "==> Installed commands:"
ls -1 "$COMMANDS_DIR" 2>/dev/null | sed 's/^/  /' || true
