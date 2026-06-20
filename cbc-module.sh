#!/usr/bin/env bash

################################################################################
# AGENTS HELPERS
################################################################################

cbc_agents_file_purpose() {
  case "$1" in
  AGENTS.md)
    printf '%s' "AI coding agent instructions for this repository."
    ;;
  LICENSE)
    printf '%s' "Project license text."
    ;;
  README.md)
    printf '%s' "Primary repository overview and setup notes."
    ;;
  cbc-module.sh)
    printf '%s' "CBC module entrypoint and shell workflow functions."
    ;;
  *)
    printf '%s' "Verification needed: document this tracked file after review."
    ;;
  esac
}

cbc_write_agents_md() {
  local target_dir="$1"
  local repo_name="$2"
  local tracked_files

  tracked_files="$(
    {
      git -C "$target_dir" ls-files
      printf '%s\n' 'AGENTS.md'
    } | sort -u
  )"

  {
    cat <<EOF
# AGENTS.md

## Purpose

This file guides AI coding agents working in \`$repo_name\`.
All work must follow best practices and industry standards where
applicable.

## Scope

This file covers repository-wide expectations for code, docs, and git
work.
It does not replace verified instructions in source files, tooling
configs,
or release automation.

## Formatting Rules

- Keep lines at 80 characters or fewer when practical.
- Allow longer lines only for URLs, code blocks, hashes, or commands
  that cannot be wrapped cleanly.

## Quick Start

- Read \`README.md\` first for project context and setup notes.
- Run \`git status --short --branch\` before editing to confirm repo
  state.
- Run \`git diff --stat\` before committing to review the change scope.
- Verification needed: add authoritative setup, run, or build
  commands when this repository defines them.

## Environment

- Git is required for day-to-day work in this repository.
- Verification needed: document runtime versions, package managers,
  and env vars when they exist.

## Repository Overview

- Root files hold the initial project overview, license, and repo
  policies.
- Verification needed: add top-level directories here when the repo
  grows.

## Tracked Files Overview

EOF

    while IFS= read -r tracked_file; do
      [ -n "$tracked_file" ] || continue
      printf -- '- `%s`: %s\n' "$tracked_file" \
        "$(cbc_agents_file_purpose "$tracked_file")"
    done <<< "$tracked_files"

    cat <<'EOF'

## Architecture

- This repository starts from a minimal scaffold and may not define
  subsystems yet.
- Verification needed: describe components, boundaries, and data flow
  after they are introduced.

## Commands

- `git status --short --branch`: show the current branch and worktree
  state.
- `git diff --stat`: review the size and spread of pending changes.
- `git log --oneline --decorate -5`: inspect recent commit history.
- Verification needed: document authoritative build, run, lint, and
  task commands when the repository defines them.

## Testing

- Verification needed: add test commands and expectations when tests
  exist.
- Do not claim coverage, test gates, or suites that are not verified.

## Linting and Formatting

- Verification needed: add formatter and linter commands after they
  are introduced.
- Keep changes minimal and consistent with the existing code style.

## CI and Release

- Use Conventional Commits for every commit. Prefer a scope when it
  adds clarity.
- Never create, edit, or update `CHANGELOG.md` manually.
- `CHANGELOG.md` is generated and maintained by release tooling only.
- If release automation adds or changes generated files, let the
  tooling own those updates.

## Conventions

- Use small, correct changes that fit the existing project structure.
- Verify behavior from the actual codebase before documenting or
  changing it.
- Keep `AGENTS.md` as instructions, not as a changelog, diary, or work
  log.
- Do not add update notes, status logs, or change summaries to
  `AGENTS.md`.

## Security and Compliance

- Never commit secrets, credentials, tokens, or private keys.
- Verify new dependencies, automation, and scripts before trusting
  them.

## Dependencies and Services

- Verification needed: document external services, databases, queues,
  or storage when they are added.
- Avoid assuming any third-party service exists until the repo proves
  it.

## Troubleshooting

- If repo behavior is unclear, inspect tracked files and git history
  before making assumptions.
- If a generated or managed file changes unexpectedly, verify which
  tool owns it before editing.

## Refining Existing AGENTS.md

- Re-check every statement against the repository before keeping it.
- Remove stale, duplicated, or vague guidance.
- Replace placeholders with exact commands, paths, and verified
  workflows.
- Keep bullets short and easy for AI agents to scan.
- Preserve this section order when improving the file.

## Maintenance

- After any code, config, or doc change, verify that `AGENTS.md` still
  matches the repository.
- When `AGENTS.md` needs an update, make it in a separate `docs`
  Conventional Commit such as `docs(agents): update repo instructions`.
- Keep `AGENTS.md` out of mixed code commits whenever possible.
- Remove stale instructions instead of appending historical notes.
EOF
  } > "$target_dir/AGENTS.md"
}

cbc_create_empty_initial_commit() {
  local target_dir="$1"
  local body="$2"
  local -a commit_args=(-m "chore: initial commit")

  if [ -n "$body" ]; then
    commit_args+=(-m "$body")
  fi

  if ! gum spin --spinner dot --title "Creating chore: initial commit..." -- \
    git -C "$target_dir" commit --allow-empty "${commit_args[@]}"; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: chore: initial commit failed."
    return 1
  fi
}

cbc_align_scaffold_branches() {
  local target_dir="$1"
  local remote_name=""

  if ! git -C "$target_dir" show-ref --verify --quiet refs/heads/develop; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: develop branch does not exist."
    return 1
  fi

  if ! gum spin --spinner dot --title "Aligning main with develop..." -- \
    git -C "$target_dir" branch -f main develop; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to align main with develop."
    return 1
  fi

  if ! gum spin --spinner dot --title "Switching to develop branch..." -- \
    git -C "$target_dir" checkout develop; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to switch to develop branch."
    return 1
  fi

  if git -C "$target_dir" remote get-url origin >/dev/null 2>&1; then
    remote_name="origin"
  else
    local remote_candidate

    while IFS= read -r remote_candidate; do
      remote_name="$remote_candidate"
      break
    done < <(git -C "$target_dir" remote)
  fi

  if [ -z "$remote_name" ]; then
    return 0
  fi

  if ! gum spin --spinner dot --title "Pushing aligned branches to remote..." -- \
    git -C "$target_dir" push -u "$remote_name" main develop; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to push aligned branches."
    return 1
  fi
}

################################################################################
# MKMOD
################################################################################

mkmod() {
  OPTIND=1

  usage() {
    cbc_style_box "$CATPPUCCIN_MAUVE" "Description:" \
      "  Bootstrap a new cbc-module project with git, git-flow, and GitHub."

    cbc_style_box "$CATPPUCCIN_BLUE" "Usage:" \
      "  mkcbcmod [-h] [directory]"

    cbc_style_box "$CATPPUCCIN_TEAL" "Options:" \
      "  -h    Display this help message"

    cbc_style_box "$CATPPUCCIN_LAVENDER" "Arguments:" \
      "  directory    Name/path for the new module (prompted if omitted)"

    cbc_style_box "$CATPPUCCIN_PEACH" "Examples:" \
      "  mkcbcmod" \
      "  mkcbcmod mymod" \
      "  mkcbcmod ~/projects/mymod"
  }

  while getopts ":h" opt; do
    case ${opt} in
    h)
      usage
      return 0
      ;;
    \?)
      cbc_style_message "$CATPPUCCIN_RED" "Invalid option: -$OPTARG"
      usage
      return 1
      ;;
    esac
  done

  shift $((OPTIND - 1))

  # --------------------------------------------------------------------------
  # Preflight: required tools
  # --------------------------------------------------------------------------
  local cmd
  for cmd in gum git gh yazi; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: missing required command: $cmd"
      return 1
    fi
  done

  if ! git flow version >/dev/null 2>&1; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: git-flow is not installed."
    return 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: gh is not authenticated. Run 'gh auth login' first."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Resolve target directory
  # --------------------------------------------------------------------------
  local target_dir="$1"

  if [ -z "$target_dir" ]; then
    target_dir=$(gum input --placeholder "Enter directory name for the new module") || {
      cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
      return 0
    }

    if [ -z "$target_dir" ]; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: No directory name provided."
      return 1
    fi
  fi

  # Strip trailing slashes and resolve to absolute path
  target_dir="${target_dir%/}"
  target_dir="$(realpath -m "$target_dir")"

  local repo_name
  repo_name="$(basename "$target_dir")"

  if [ -z "$repo_name" ]; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Could not determine repo name from path."
    return 1
  fi

  local cwd
  cwd="$(pwd -P)"

  local display_dir
  display_dir="$(realpath -m --relative-to="$cwd" "$target_dir")"

  if [ -z "$display_dir" ]; then
    display_dir="$target_dir"
  fi

  # --------------------------------------------------------------------------
  # Confirm before proceeding
  # --------------------------------------------------------------------------
  cbc_style_box "$CATPPUCCIN_LAVENDER" "New CBC Module" \
    "  Directory: $display_dir" \
    "  Repo name: $repo_name"

  if ! gum confirm "Bootstrap this module?"; then
    cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
    return 0
  fi

  # --------------------------------------------------------------------------
  # Fail if directory already exists
  # --------------------------------------------------------------------------
  if [ -e "$target_dir" ]; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: '$target_dir' already exists."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Create directory
  # --------------------------------------------------------------------------
  if ! gum spin --spinner dot --title "Creating directory..." -- \
    mkdir -p "$target_dir"; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to create directory."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Git init with main as default branch
  # --------------------------------------------------------------------------
  if ! gum spin --spinner dot --title "Initializing git repository..." -- \
    git -C "$target_dir" init -b main; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: git init failed."
    return 1
  fi

  # --------------------------------------------------------------------------
  # chore: initial commit
  # --------------------------------------------------------------------------
  if ! cbc_create_empty_initial_commit "$target_dir"; then
    return 1
  fi

  # --------------------------------------------------------------------------
  # cbc-module.sh
  # --------------------------------------------------------------------------
  printf '#!/usr/bin/env bash\n' > "$target_dir/cbc-module.sh"

  if ! gum spin --spinner dot --title "Creating module entrypoint commit..." -- \
    bash -c 'git -C "$1" add cbc-module.sh && git -C "$1" commit -m "chore(module): add module entrypoint" -m "Add the CBC module shell entrypoint scaffold."' _ "$target_dir"; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: module entrypoint commit failed."
    return 1
  fi

  # --------------------------------------------------------------------------
  # README
  # --------------------------------------------------------------------------
  local project_title
  project_title="$(printf '%s' "$repo_name" | tr '-' ' ' | awk '{for (i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) tolower(substr($i,2)) } ; print }')"

  local project_description
  project_description=$(gum input --placeholder "Enter a short project description") || {
    cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
    return 0
  }

  if [ -z "$project_description" ]; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: No project description provided."
    return 1
  fi

  printf '# %s\n\n%s\n' "$project_title" "$project_description" > "$target_dir/README.md"

  if ! gum spin --spinner dot --title "Creating README commit..." -- \
    bash -c "git -C \"$target_dir\" add README.md && git -C \"$target_dir\" commit -m 'docs(readme): add README' -m 'Add project title and description scaffold.'"; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: README commit failed."
    return 1
  fi

  # --------------------------------------------------------------------------
  # License creation (gh-license extension)
  # --------------------------------------------------------------------------
  if ! gh license --help >/dev/null 2>&1; then
    cbc_style_message "$CATPPUCCIN_YELLOW" "gh license extension not found."
    cbc_style_message "$CATPPUCCIN_YELLOW" "Install with: gh extension install Shresht7/gh-license"

    if ! gum confirm "Install gh-license extension now?"; then
      cbc_style_message "$CATPPUCCIN_YELLOW" "License creation will be unavailable until gh-license is installed."
      return 0
    fi

    if ! gum spin --spinner dot --title "Installing gh-license extension..." -- \
      gh extension install Shresht7/gh-license; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to install gh-license extension."
      return 1
    fi
  fi

  if ! gum spin --spinner dot --title "Creating GPL-3.0 license..." -- \
    bash -c "cd \"$target_dir\" && gh license create gpl-3.0 && git add LICENSE && git commit -m 'chore(license): add GPL-3.0 license' -m 'Add the project license file before publishing the repository to GitHub.'"; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: License creation failed."
    return 1
  fi

  # --------------------------------------------------------------------------
  # AGENTS.md
  # --------------------------------------------------------------------------
  if ! cbc_write_agents_md "$target_dir" "$repo_name"; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to create AGENTS.md."
    return 1
  fi

  if ! gum spin --spinner dot --title "Creating AGENTS commit..." -- \
    bash -c 'git -C "$1" add AGENTS.md && git -C "$1" commit -m "docs(agents): add AGENTS guide" -m "Add AI coding agent instructions and AGENTS maintenance rules."' _ "$target_dir"; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: AGENTS commit failed."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Git flow init with defaults
  # --------------------------------------------------------------------------
  if ! gum spin --spinner dot --title "Initializing git-flow..." -- \
    git -C "$target_dir" flow init -d; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: git-flow init failed."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Create GitHub repo (public) and set remote
  # --------------------------------------------------------------------------
  if ! gum spin --spinner dot --title "Creating GitHub repository..." -- \
    gh repo create "$repo_name" --public --source="$target_dir" --remote=origin; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: GitHub repo creation failed."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Push main and develop to remote
  # --------------------------------------------------------------------------
  if ! gum spin --spinner dot --title "Pushing main to remote..." -- \
    git -C "$target_dir" push -u origin main; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to push main branch."
    return 1
  fi

  if ! gum spin --spinner dot --title "Pushing develop to remote..." -- \
    git -C "$target_dir" push -u origin develop; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to push develop branch."
    return 1
  fi

  if ! gum spin --spinner dot --title "Switching to develop branch..." -- \
    git -C "$target_dir" checkout develop; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to switch to develop branch."
    return 1
  fi

  if gum confirm "Initialize commitlint in this module?"; then
    if ! (cd "$target_dir" && mkcommitlint); then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Commitlint initialization failed."
      return 1
    fi

    if ! cbc_align_scaffold_branches "$target_dir"; then
      return 1
    fi
  fi

  # --------------------------------------------------------------------------
  # Success
  # --------------------------------------------------------------------------
  local repo_url
  repo_url="$(gh repo view "$repo_name" --json url -q .url 2>/dev/null)"

  cbc_style_box "$CATPPUCCIN_GREEN" "Module created successfully!" \
    "  Path: $target_dir" \
    "  Repo: ${repo_url:-$repo_name}"

  cd "$target_dir" || return 1
  yazi
}

################################################################################
# MKREPO
################################################################################

mkrepo() {
  OPTIND=1

  usage() {
    cbc_style_box "$CATPPUCCIN_MAUVE" "Description:" \
      "  Bootstrap a new repository with git, git-flow, and optional GitHub."

    cbc_style_box "$CATPPUCCIN_BLUE" "Usage:" \
      "  mkrepo [-h] [directory]"

    cbc_style_box "$CATPPUCCIN_TEAL" "Options:" \
      "  -h    Display this help message"

    cbc_style_box "$CATPPUCCIN_LAVENDER" "Arguments:" \
      "  directory    Name of the new subdirectory to create"

    cbc_style_box "$CATPPUCCIN_PEACH" "Examples:" \
      "  mkrepo" \
      "  mkrepo my-repo"
  }

  while getopts ":h" opt; do
    case ${opt} in
    h)
      usage
      return 0
      ;;
    \?)
      cbc_style_message "$CATPPUCCIN_RED" "Invalid option: -$OPTARG"
      usage
      return 1
      ;;
    esac
  done

  shift $((OPTIND - 1))

  # --------------------------------------------------------------------------
  # Preflight: required tools
  # --------------------------------------------------------------------------
  local cmd
  for cmd in gum git yazi; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: missing required command: $cmd"
      return 1
    fi
  done

  if ! git flow version >/dev/null 2>&1; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: git-flow is not installed."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Resolve target directory
  # --------------------------------------------------------------------------
  local cwd
  cwd="$(pwd -P)"

  local repo_input="$1"
  local use_current_dir="false"
  local target_dir

  if [ -n "$repo_input" ]; then
    repo_input="${repo_input%/}"

    if [ -z "$repo_input" ]; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: No directory name provided."
      return 1
    fi

    if [[ "$repo_input" == */* ]]; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Provide a directory name, not a path."
      return 1
    fi

    target_dir="$(realpath -m "$cwd/$repo_input")"
  else
    local location_choice
    location_choice=$(gum choose "Create subdirectory" "Use current directory") || {
      cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
      return 0
    }

    case "$location_choice" in
    "Create subdirectory")
      local new_dir_name
      new_dir_name=$(gum input --placeholder "Enter directory name for the new repository") || {
        cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
        return 0
      }

      if [ -z "$new_dir_name" ]; then
        cbc_style_message "$CATPPUCCIN_RED" "Error: No directory name provided."
        return 1
      fi

      if [[ "$new_dir_name" == */* ]]; then
        cbc_style_message "$CATPPUCCIN_RED" "Error: Provide a directory name, not a path."
        return 1
      fi

      target_dir="$(realpath -m "$cwd/$new_dir_name")"
      ;;
    "Use current directory")
      use_current_dir="true"
      target_dir="$cwd"
      ;;
    esac
  fi

  local repo_name
  repo_name="$(basename "$target_dir")"

  if [ -z "$repo_name" ]; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Could not determine repo name from directory."
    return 1
  fi

  local display_dir
  display_dir="$(realpath -m --relative-to="$cwd" "$target_dir")"

  if [ -z "$display_dir" ]; then
    display_dir="$target_dir"
  fi

  if [ "$use_current_dir" = "true" ]; then
    if [ -e "$target_dir/.git" ]; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Current directory is already a git repository."
      return 1
    fi
  elif [ -e "$target_dir" ]; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: '$target_dir' already exists."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Resolve repo metadata and current-directory choices
  # --------------------------------------------------------------------------
  local project_description
  project_description=$(gum input --placeholder "Enter a short project description") || {
    cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
    return 0
  }

  if [ -z "$project_description" ]; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: No project description provided."
    return 1
  fi

  local repo_mode
  repo_mode=$(gum choose "Publish on GitHub" "Local only") || {
    cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
    return 0
  }

  local publish_github="false"
  local repo_visibility=""
  local gh_visibility_flag
  gh_visibility_flag="--public"

  if [ "$repo_mode" = "Publish on GitHub" ]; then
    publish_github="true"

    if ! command -v gh >/dev/null 2>&1; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: missing required command: gh"
      return 1
    fi

    if ! gh auth status >/dev/null 2>&1; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: gh is not authenticated. Run 'gh auth login' first."
      return 1
    fi

    if ! gh license --help >/dev/null 2>&1; then
      cbc_style_message "$CATPPUCCIN_YELLOW" "gh license extension not found."
      cbc_style_message "$CATPPUCCIN_YELLOW" "Install with: gh extension install Shresht7/gh-license"

      if ! gum confirm "Install gh-license extension now?"; then
        cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled. GPL-3.0 license creation is required."
        return 0
      fi

      if ! gum spin --spinner dot --title "Installing gh-license extension..." -- \
        gh extension install Shresht7/gh-license; then
        cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to install gh-license extension."
        return 1
      fi
    fi

    repo_visibility=$(gum choose "public" "private") || {
      cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
      return 0
    }

    if [ "$repo_visibility" = "private" ]; then
      gh_visibility_flag="--private"
    fi
  fi

  local readme_action="create"
  local agents_action="create"
  local include_existing_files="false"

  if [ "$use_current_dir" = "true" ]; then
    if [ -f "$target_dir/README.md" ]; then
      local readme_choice
      readme_choice=$(gum choose \
        "Keep existing README.md" \
        "Replace README.md" \
        "Cancel") || {
        cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
        return 0
      }

      case "$readme_choice" in
      "Keep existing README.md")
        readme_action="keep"
        ;;
      "Replace README.md")
        readme_action="replace"
        ;;
      "Cancel")
        cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
        return 0
        ;;
      esac
    fi

    if [ -f "$target_dir/AGENTS.md" ]; then
      local agents_choice
      agents_choice=$(gum choose \
        "Keep existing AGENTS.md" \
        "Replace AGENTS.md" \
        "Cancel") || {
        cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
        return 0
      }

      case "$agents_choice" in
      "Keep existing AGENTS.md")
        agents_action="keep"
        ;;
      "Replace AGENTS.md")
        agents_action="replace"
        ;;
      "Cancel")
        cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
        return 0
        ;;
      esac
    fi

    if [ "$publish_github" = "true" ] && [ -e "$target_dir/LICENSE" ]; then
      if ! gum confirm "Replace existing LICENSE with GPL-3.0?"; then
        cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
        return 0
      fi
    fi

    local existing_file

    if [ "$publish_github" = "true" ]; then
      existing_file="$(find "$target_dir" -mindepth 1 -maxdepth 1 ! -name '.git' ! -name 'README.md' ! -name 'LICENSE' ! -name 'AGENTS.md' -print -quit 2>/dev/null)"
    else
      existing_file="$(find "$target_dir" -mindepth 1 -maxdepth 1 ! -name '.git' ! -name 'README.md' ! -name 'AGENTS.md' -print -quit 2>/dev/null)"
    fi

    if [ -n "$existing_file" ]; then
      if gum confirm "Commit existing files in a separate commit?"; then
        include_existing_files="true"
      fi
    fi
  fi

  # --------------------------------------------------------------------------
  # Confirm before proceeding
  # --------------------------------------------------------------------------
  if [ "$publish_github" = "true" ]; then
    cbc_style_box "$CATPPUCCIN_LAVENDER" "New Repository" \
      "  Directory: $display_dir" \
      "  Repo name: $repo_name" \
      "  Mode: GitHub" \
      "  Visibility: $repo_visibility"
  else
    cbc_style_box "$CATPPUCCIN_LAVENDER" "New Repository" \
      "  Directory: $display_dir" \
      "  Repo name: $repo_name" \
      "  Mode: Local only"
  fi

  if ! gum confirm "Bootstrap this repository?"; then
    cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
    return 0
  fi

  # --------------------------------------------------------------------------
  # Create target directory if needed
  # --------------------------------------------------------------------------
  if [ "$use_current_dir" != "true" ]; then
    if ! gum spin --spinner dot --title "Creating directory..." -- \
      mkdir -p "$target_dir"; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to create directory."
      return 1
    fi
  fi

  # --------------------------------------------------------------------------
  # Git init with main as default branch
  # --------------------------------------------------------------------------
  if ! gum spin --spinner dot --title "Initializing git repository..." -- \
    git -C "$target_dir" init -b main; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: git init failed."
    return 1
  fi

  # --------------------------------------------------------------------------
  # chore: initial commit
  # --------------------------------------------------------------------------
  if ! cbc_create_empty_initial_commit "$target_dir"; then
    return 1
  fi

  # --------------------------------------------------------------------------
  # Commit existing files, if requested
  # --------------------------------------------------------------------------
  if [ "$include_existing_files" = "true" ]; then
    if ! gum spin --spinner dot --title "Creating existing files commit..." -- \
      bash -c '
        if [ "$2" = "true" ]; then
          git -C "$1" add --all -- . ":(exclude)README.md" \
            ":(exclude)LICENSE" ":(exclude)AGENTS.md"
        else
          git -C "$1" add --all -- . ":(exclude)README.md" \
            ":(exclude)AGENTS.md"
        fi

        if git -C "$1" diff --cached --quiet; then
          exit 0
        fi

        git -C "$1" commit -m "chore: add existing project files" \
          -m "Record existing non-bootstrap files before adding generated repository scaffolding."
      ' _ "$target_dir" "$publish_github"; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Existing files commit failed."
      return 1
    fi
  fi

  # --------------------------------------------------------------------------
  # README
  # --------------------------------------------------------------------------
  local project_title
  project_title="$(printf '%s' "$repo_name" | tr '-' ' ' | awk '{for (i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) tolower(substr($i,2)) } ; print }')"

  local readme_commit_body="Add project title and description scaffold."

  if [ "$readme_action" = "keep" ]; then
    readme_commit_body="Add the existing README to the initial repository history."
  fi

  if [ "$readme_action" != "keep" ]; then
    printf '# %s\n\n%s\n' "$project_title" "$project_description" > "$target_dir/README.md"
  fi

  if ! gum spin --spinner dot --title "Creating README commit..." -- \
    bash -c 'git -C "$1" add README.md && git -C "$1" commit -m "docs(readme): add README" -m "$2"' _ "$target_dir" "$readme_commit_body"; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: README commit failed."
    return 1
  fi

  # --------------------------------------------------------------------------
  # License creation
  # --------------------------------------------------------------------------
  if [ "$publish_github" = "true" ]; then
    if ! gum spin --spinner dot --title "Creating GPL-3.0 license..." -- \
      bash -c 'if [ -e "$1/LICENSE" ]; then rm -f "$1/LICENSE"; fi && cd "$1" && gh license create gpl-3.0 && git add LICENSE && git commit -m "chore(license): add GPL-3.0 license" -m "Add the project license file before publishing the repository to GitHub."' _ "$target_dir"; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: License creation failed."
      return 1
    fi
  fi

  # --------------------------------------------------------------------------
  # AGENTS.md
  # --------------------------------------------------------------------------
  local agents_commit_body="Add AI coding agent instructions and AGENTS maintenance rules."

  if [ "$agents_action" = "keep" ]; then
    agents_commit_body="Add the existing AGENTS.md file to the initial repository history."
  else
    if ! cbc_write_agents_md "$target_dir" "$repo_name"; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to create AGENTS.md."
      return 1
    fi
  fi

  if ! gum spin --spinner dot --title "Creating AGENTS commit..." -- \
    bash -c 'git -C "$1" add AGENTS.md && git -C "$1" commit -m "docs(agents): add AGENTS guide" -m "$2"' _ "$target_dir" "$agents_commit_body"; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: AGENTS commit failed."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Git flow init with defaults
  # --------------------------------------------------------------------------
  if ! gum spin --spinner dot --title "Initializing git-flow..." -- \
    git -C "$target_dir" flow init -d; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: git-flow init failed."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Create GitHub repo and set remote
  # --------------------------------------------------------------------------
  if [ "$publish_github" = "true" ]; then
    if ! gum spin --spinner dot --title "Creating GitHub repository..." -- \
      gh repo create "$repo_name" "$gh_visibility_flag" --description "$project_description" --source="$target_dir" --remote=origin; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: GitHub repo creation failed."
      return 1
    fi

    # ------------------------------------------------------------------------
    # Push main and develop to remote
    # ------------------------------------------------------------------------
    if ! gum spin --spinner dot --title "Pushing main to remote..." -- \
      git -C "$target_dir" push -u origin main; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to push main branch."
      return 1
    fi

    if ! gum spin --spinner dot --title "Pushing develop to remote..." -- \
      git -C "$target_dir" push -u origin develop; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to push develop branch."
      return 1
    fi
  fi

  if ! gum spin --spinner dot --title "Switching to develop branch..." -- \
    git -C "$target_dir" checkout develop; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to switch to develop branch."
    return 1
  fi

  if gum confirm "Initialize commitlint in this repository?"; then
    if ! (cd "$target_dir" && mkcommitlint); then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Commitlint initialization failed."
      return 1
    fi

    if ! cbc_align_scaffold_branches "$target_dir"; then
      return 1
    fi
  fi

  # --------------------------------------------------------------------------
  # Success
  # --------------------------------------------------------------------------
  if [ "$publish_github" = "true" ]; then
    local repo_url
    repo_url="$(gh repo view "$repo_name" --json url -q .url 2>/dev/null)"

    cbc_style_box "$CATPPUCCIN_GREEN" "Repository created successfully!" \
      "  Path: $target_dir" \
      "  Mode: GitHub" \
      "  Repo: ${repo_url:-$repo_name}"
  else
    cbc_style_box "$CATPPUCCIN_GREEN" "Repository created successfully!" \
      "  Path: $target_dir" \
      "  Mode: Local only"
  fi

  cd "$target_dir" || return 1
  yazi
}

################################################################################
# MKSKILL
################################################################################

mkskill() {
  OPTIND=1

  usage() {
    cbc_style_box "$CATPPUCCIN_MAUVE" "Description:" \
      "  Bootstrap a new OpenCode skill with git, git-flow, and GitHub."

    cbc_style_box "$CATPPUCCIN_BLUE" "Usage:" \
      "  mkskill [-h] [skill-name]"

    cbc_style_box "$CATPPUCCIN_TEAL" "Options:" \
      "  -h    Display this help message"

    cbc_style_box "$CATPPUCCIN_LAVENDER" "Arguments:" \
      "  skill-name    Name of the skill to create (prompted if omitted)"

    cbc_style_box "$CATPPUCCIN_PEACH" "Examples:" \
      "  mkskill" \
      "  mkskill my-skill"
  }

  while getopts ":h" opt; do
    case ${opt} in
    h)
      usage
      return 0
      ;;
    \?)
      cbc_style_message "$CATPPUCCIN_RED" "Invalid option: -$OPTARG"
      usage
      return 1
      ;;
    esac
  done

  shift $((OPTIND - 1))

  # --------------------------------------------------------------------------
  # Preflight: required tools
  # --------------------------------------------------------------------------
  local cmd
  for cmd in gum git gh yazi; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: missing required command: $cmd"
      return 1
    fi
  done

  if ! git flow version >/dev/null 2>&1; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: git-flow is not installed."
    return 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: gh is not authenticated. Run 'gh auth login' first."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Resolve target directory
  # --------------------------------------------------------------------------
  local skill_name="$1"

  if [ -z "$skill_name" ]; then
    skill_name=$(gum input --placeholder "Enter skill name for the new skill") || {
      cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
      return 0
    }

    if [ -z "$skill_name" ]; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: No skill name provided."
      return 1
    fi
  fi

  skill_name="${skill_name%/}"

  local skills_root
  skills_root="$(realpath -m "$HOME/.config/opencode/skills")"

  local target_dir
  target_dir="$(realpath -m "$skills_root/$skill_name")"

  if [[ "$target_dir" != "$skills_root/"* ]]; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Skill name resolves outside skills directory."
    return 1
  fi

  local repo_name
  repo_name="$(basename "$target_dir")"

  if [ -z "$repo_name" ]; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Could not determine repo name from skill name."
    return 1
  fi

  local cwd
  cwd="$(pwd -P)"

  local display_dir
  display_dir="$(realpath -m --relative-to="$cwd" "$target_dir")"

  if [ -z "$display_dir" ]; then
    display_dir="$target_dir"
  fi

  # --------------------------------------------------------------------------
  # Confirm before proceeding
  # --------------------------------------------------------------------------
  cbc_style_box "$CATPPUCCIN_LAVENDER" "New OpenCode Skill" \
    "  Directory: $display_dir" \
    "  Repo name: $repo_name"

  if ! gum confirm "Bootstrap this skill?"; then
    cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
    return 0
  fi

  # --------------------------------------------------------------------------
  # Fail if directory already exists
  # --------------------------------------------------------------------------
  if [ -e "$target_dir" ]; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: '$target_dir' already exists."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Create directory
  # --------------------------------------------------------------------------
  if ! gum spin --spinner dot --title "Creating skill directory..." -- \
    mkdir -p "$target_dir"; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to create directory."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Git init with main as default branch
  # --------------------------------------------------------------------------
  if ! gum spin --spinner dot --title "Initializing git repository..." -- \
    git -C "$target_dir" init -b main; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: git init failed."
    return 1
  fi

  # --------------------------------------------------------------------------
  # chore: initial commit
  # --------------------------------------------------------------------------
  if ! cbc_create_empty_initial_commit "$target_dir"; then
    return 1
  fi

  # --------------------------------------------------------------------------
  # SKILL.md
  # --------------------------------------------------------------------------
  printf '' > "$target_dir/SKILL.md"

  if ! gum spin --spinner dot --title "Creating skill scaffold commit..." -- \
    bash -c 'git -C "$1" add SKILL.md && git -C "$1" commit -m "chore(skill): add skill scaffold" -m "Add the OpenCode skill definition scaffold."' _ "$target_dir"; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: skill scaffold commit failed."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Git flow init with defaults
  # --------------------------------------------------------------------------
  if ! gum spin --spinner dot --title "Initializing git-flow..." -- \
    git -C "$target_dir" flow init -d; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: git-flow init failed."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Create GitHub repo (public) and set remote
  # --------------------------------------------------------------------------
  if ! gum spin --spinner dot --title "Creating GitHub repository..." -- \
    gh repo create "$repo_name" --public --source="$target_dir" --remote=origin; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: GitHub repo creation failed."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Push main and develop to remote
  # --------------------------------------------------------------------------
  if ! gum spin --spinner dot --title "Pushing main to remote..." -- \
    git -C "$target_dir" push -u origin main; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to push main branch."
    return 1
  fi

  if ! gum spin --spinner dot --title "Pushing develop to remote..." -- \
    git -C "$target_dir" push -u origin develop; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to push develop branch."
    return 1
  fi

  if ! gum spin --spinner dot --title "Switching to develop branch..." -- \
    git -C "$target_dir" checkout develop; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to switch to develop branch."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Success
  # --------------------------------------------------------------------------
  local repo_url
  repo_url="$(gh repo view "$repo_name" --json url -q .url 2>/dev/null)"

  cbc_style_box "$CATPPUCCIN_GREEN" "Skill created successfully!" \
    "  Path: $target_dir" \
    "  Repo: ${repo_url:-$repo_name}"

  cd "$target_dir" || return 1
  yazi
}

################################################################################
# MKZENDOCS
################################################################################

mkzendocs() {
  OPTIND=1

  usage() {
    cbc_style_box "$CATPPUCCIN_MAUVE" "Description:" \
      "  Bootstrap Zensical documentation in the current directory."

    cbc_style_box "$CATPPUCCIN_BLUE" "Usage:" \
      "  mkzendocs [-h]"

    cbc_style_box "$CATPPUCCIN_TEAL" "Options:" \
      "  -h    Display this help message"

    cbc_style_box "$CATPPUCCIN_PEACH" "Examples:" \
      "  mkzendocs"
  }

  while getopts ":h" opt; do
    case ${opt} in
    h)
      usage
      return 0
      ;;
    \?)
      cbc_style_message "$CATPPUCCIN_RED" "Invalid option: -$OPTARG"
      usage
      return 1
      ;;
    esac
  done

  shift $((OPTIND - 1))

  # --------------------------------------------------------------------------
  # Preflight: required tools
  # --------------------------------------------------------------------------
  local cmd
  for cmd in gum python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: missing required command: $cmd"
      return 1
    fi
  done

  if [ "$(uname -s)" != "Linux" ]; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: mkzendocs uses the Linux pip install flow."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Resolve target directory
  # --------------------------------------------------------------------------
  local target_dir
  local in_git_repo="false"

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    in_git_repo="true"
    target_dir="$(git rev-parse --show-toplevel)" || {
      cbc_style_message "$CATPPUCCIN_RED" "Error: Could not resolve git repository root."
      return 1
    }
  else
    cbc_style_message "$CATPPUCCIN_YELLOW" "Warning: mkzendocs is not being run within a git repository."

    if ! gum confirm "Proceed in the current directory?"; then
      cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
      return 0
    fi

    target_dir="$(pwd -P)"
  fi

  local current_branch=""
  local remote_name=""
  local push_action="skip; not in a git repository"

  if [ "$in_git_repo" = "true" ]; then
    local dirty_status
    dirty_status="$(
      git -C "$target_dir" status --porcelain --untracked-files=all |
        grep -Ev '^.. \.venv(/|$)' || true
    )"

    if [ -n "$dirty_status" ]; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: mkzendocs creates commits and requires a clean worktree."
      return 1
    fi

    current_branch="$(git -C "$target_dir" branch --show-current)" || {
      cbc_style_message "$CATPPUCCIN_RED" "Error: Could not determine current branch."
      return 1
    }

    if [ -z "$current_branch" ]; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: mkzendocs cannot run from a detached HEAD."
      return 1
    fi

    local configured_remote
    configured_remote="$(git -C "$target_dir" config "branch.$current_branch.remote" 2>/dev/null || true)"

    if [ -n "$configured_remote" ] && \
      git -C "$target_dir" remote get-url "$configured_remote" >/dev/null 2>&1; then
      remote_name="$configured_remote"
    elif git -C "$target_dir" remote get-url origin >/dev/null 2>&1; then
      remote_name="origin"
    else
      local remote_candidate

      while IFS= read -r remote_candidate; do
        remote_name="$remote_candidate"
        break
      done < <(git -C "$target_dir" remote)
    fi

    push_action="skip; no remote configured"

    if [ -n "$remote_name" ]; then
      push_action="push $current_branch to $remote_name"
    fi
  fi

  # --------------------------------------------------------------------------
  # Resolve documentation mode
  # --------------------------------------------------------------------------
  local has_root_docs="false"
  local doc_file

  for doc_file in README.md CHANGELOG.md AGENTS.md; do
    if [ -f "$target_dir/$doc_file" ]; then
      has_root_docs="true"
      break
    fi
  done

  local needs_site_name="false"
  local site_name="existing"

  if [ ! -f "$target_dir/zensical.toml" ]; then
    needs_site_name="true"
    site_name=$(gum input --placeholder "Enter site_name for zensical.toml") || {
      cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
      return 0
    }

    if [ -z "$site_name" ]; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: No site_name provided."
      return 1
    fi
  fi

  # --------------------------------------------------------------------------
  # Confirm before proceeding
  # --------------------------------------------------------------------------
  cbc_style_box "$CATPPUCCIN_LAVENDER" "Zensical Documentation" \
    "  Directory: $target_dir" \
    "  Repository: $in_git_repo" \
    "  Branch: ${current_branch:-none}" \
    "  Remote push: $push_action" \
    "  Site name: $site_name"

  if ! gum confirm "Bootstrap Zensical docs in this directory?"; then
    cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
    return 0
  fi

  commit_zendocs_paths() {
    [ "$in_git_repo" = "true" ] || return 0

    local subject="$1"
    local body="$2"
    local pathspec

    shift 2

    for pathspec in "$@"; do
      if [ -e "$target_dir/$pathspec" ] || [ -L "$target_dir/$pathspec" ] || \
        git -C "$target_dir" ls-files --error-unmatch "$pathspec" >/dev/null 2>&1; then
        git -C "$target_dir" add -- "$pathspec" || return 1
      fi
    done

    if git -C "$target_dir" diff --cached --quiet; then
      return 0
    fi

    if ! gum spin --spinner dot --title "Creating commit: $subject" -- \
      git -C "$target_dir" commit -m "$subject" -m "$body"; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to create commit: $subject"
      return 1
    fi
  }

  # --------------------------------------------------------------------------
  # Ignore local Python environment
  # --------------------------------------------------------------------------
  local gitignore_file="$target_dir/.gitignore"

  if [ -f "$gitignore_file" ]; then
    if ! grep -Eq '^[[:space:]]*\.venv/?[[:space:]]*$' "$gitignore_file"; then
      {
        printf '\n'
        printf '%s\n' '.venv/'
      } >> "$gitignore_file" || {
        cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to update .gitignore."
        return 1
      }
    fi
  else
    printf '%s\n' '.venv/' > "$gitignore_file" || {
      cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to create .gitignore."
      return 1
    }
  fi

  if ! commit_zendocs_paths \
    "chore(gitignore): ignore Python virtual environment" \
    "Keep the local mkzendocs Python virtual environment out of repository history." \
    .gitignore; then
    return 1
  fi

  # --------------------------------------------------------------------------
  # Linux pip installation
  # --------------------------------------------------------------------------
  if [ ! -x "$target_dir/.venv/bin/python" ]; then
    if ! gum spin --spinner dot --title "Creating Python virtual environment..." -- \
      python3 -m venv "$target_dir/.venv"; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to create Python virtual environment."
      return 1
    fi
  fi

  if [ ! -x "$target_dir/.venv/bin/zensical" ]; then
    if ! gum spin --spinner dot --title "Installing Zensical with pip..." -- \
      bash -c '"$1/.venv/bin/python" -m pip install zensical' _ "$target_dir"; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to install Zensical."
      return 1
    fi
  fi

  # --------------------------------------------------------------------------
  # Zensical project scaffold
  # --------------------------------------------------------------------------
  local needs_zensical_scaffold="false"

  if [ ! -f "$target_dir/zensical.toml" ]; then
    needs_zensical_scaffold="true"
  elif [ "$has_root_docs" != "true" ]; then
    if [ ! -f "$target_dir/docs/index.md" ] || \
      [ ! -f "$target_dir/docs/markdown.md" ]; then
      needs_zensical_scaffold="true"
    fi
  fi

  if [ "$needs_zensical_scaffold" = "true" ]; then
    local scaffold_dir
    scaffold_dir="$(mktemp -d)" || {
      cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to create temporary scaffold directory."
      return 1
    }

    if ! mkdir -p "$scaffold_dir/project"; then
      rm -rf "$scaffold_dir"
      cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to prepare temporary scaffold directory."
      return 1
    fi

    if ! gum spin --spinner dot --title "Creating Zensical project..." -- \
      bash -c 'cd "$2/project" && "$1/.venv/bin/zensical" new .' _ "$target_dir" "$scaffold_dir"; then
      rm -rf "$scaffold_dir"
      cbc_style_message "$CATPPUCCIN_RED" "Error: zensical new . failed."
      return 1
    fi

    if [ ! -f "$target_dir/zensical.toml" ]; then
      if ! cp "$scaffold_dir/project/zensical.toml" "$target_dir/zensical.toml"; then
        rm -rf "$scaffold_dir"
        cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to create zensical.toml."
        return 1
      fi
    fi

    if [ "$has_root_docs" != "true" ]; then
      if ! mkdir -p "$target_dir/docs"; then
        rm -rf "$scaffold_dir"
        cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to create docs directory."
        return 1
      fi

      for doc_file in index.md markdown.md; do
        [ ! -e "$target_dir/docs/$doc_file" ] || continue

        if ! cp "$scaffold_dir/project/docs/$doc_file" "$target_dir/docs/$doc_file"; then
          rm -rf "$scaffold_dir"
          cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to create docs/$doc_file."
          return 1
        fi
      done
    fi

    rm -rf "$scaffold_dir"
  fi

  if [ ! -f "$target_dir/zensical.toml" ]; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: zensical.toml was not created."
    return 1
  fi

  # --------------------------------------------------------------------------
  # site_name configuration
  # --------------------------------------------------------------------------
  if [ "$needs_site_name" = "true" ] && \
    ! python3 - "$target_dir/zensical.toml" "$site_name" <<'PY'
import json
import re
import sys

config_path = sys.argv[1]
site_name = sys.argv[2]

with open(config_path, "r", encoding="utf-8", newline="") as config_file:
    lines = config_file.readlines()

updated = False

for index, line in enumerate(lines):
    if re.match(r"^\s*site_name\s*=", line):
        newline = ""
        if line.endswith("\r\n"):
            newline = "\r\n"
        elif line.endswith("\n"):
            newline = "\n"

        indent = re.match(r"^\s*", line).group(0)
        lines[index] = f"{indent}site_name = {json.dumps(site_name)}{newline}"
        updated = True
        break

if not updated:
    raise SystemExit("site_name setting not found in zensical.toml")

with open(config_path, "w", encoding="utf-8", newline="") as config_file:
    config_file.writelines(lines)
PY
  then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to update site_name."
    return 1
  fi

  if ! commit_zendocs_paths \
    "docs(zensical): add zensical configuration" \
    "Add the Zensical site configuration for repository documentation." \
    zensical.toml; then
    return 1
  fi

  if [ "$has_root_docs" != "true" ]; then
    if ! commit_zendocs_paths \
      "docs(zensical): add documentation index" \
      "Add the default Zensical documentation landing page." \
      docs/index.md; then
      return 1
    fi

    if ! commit_zendocs_paths \
      "docs(zensical): add markdown guide" \
      "Add the default Zensical Markdown guide page." \
      docs/markdown.md; then
      return 1
    fi
  fi

  # --------------------------------------------------------------------------
  # Root documentation links
  # --------------------------------------------------------------------------
  if [ "$has_root_docs" = "true" ]; then
    if [ ! -d "$target_dir/docs" ]; then
      if ! mkdir -p "$target_dir/docs"; then
        cbc_style_message "$CATPPUCCIN_RED" "Error: docs directory was not created."
        return 1
      fi
    fi

    if ! rm -f "$target_dir/docs/index.md" "$target_dir/docs/markdown.md"; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to remove generated docs pages."
      return 1
    fi

    if ! commit_zendocs_paths \
      "docs(zensical): remove generated docs pages" \
      "Remove default Zensical pages when root documentation links replace them." \
      docs/index.md docs/markdown.md; then
      return 1
    fi

    for doc_file in README.md CHANGELOG.md AGENTS.md; do
      [ -f "$target_dir/$doc_file" ] || continue

      if [ -L "$target_dir/docs/$doc_file" ] && \
        [ "$(readlink "$target_dir/docs/$doc_file")" = "../$doc_file" ]; then
        continue
      fi

      if ! rm -f "$target_dir/docs/$doc_file"; then
        cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to prepare docs/$doc_file."
        return 1
      fi

      if ! ln -s "../$doc_file" "$target_dir/docs/$doc_file"; then
        cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to link docs/$doc_file."
        return 1
      fi

      case "$doc_file" in
      README.md)
        if ! commit_zendocs_paths \
          "docs(readme): link README into zensical docs" \
          "Expose the repository README through the generated Zensical docs." \
          docs/README.md; then
          return 1
        fi
        ;;
      CHANGELOG.md)
        if ! commit_zendocs_paths \
          "docs(changelog): link changelog into zensical docs" \
          "Expose the repository changelog through the generated Zensical docs." \
          docs/CHANGELOG.md; then
          return 1
        fi
        ;;
      AGENTS.md)
        if ! commit_zendocs_paths \
          "docs(agents): link AGENTS guide into zensical docs" \
          "Expose the repository AGENTS guide through the generated Zensical docs." \
          docs/AGENTS.md; then
          return 1
        fi
        ;;
      esac
    done
  fi

  if [ "$in_git_repo" = "true" ] && [ -n "$remote_name" ]; then
    if ! gum spin --spinner dot --title "Pushing $current_branch to remote..." -- \
      git -C "$target_dir" push -u "$remote_name" "$current_branch"; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to push $current_branch branch."
      return 1
    fi
  fi

  # --------------------------------------------------------------------------
  # Success
  # --------------------------------------------------------------------------
  cbc_style_box "$CATPPUCCIN_GREEN" "Zensical docs bootstrapped successfully!" \
    "  Path: $target_dir" \
    "  Branch: ${current_branch:-none}" \
    "  Remote: ${remote_name:-none}" \
    "  Config: zensical.toml" \
    "  Site name: $site_name"
}

################################################################################
# MKCOMMITLINT
################################################################################

mkcommitlint() {
  OPTIND=1

  usage() {
    cbc_style_box "$CATPPUCCIN_MAUVE" "Description:" \
      "  Bootstrap Commitlint and Husky in the current git repository."

    cbc_style_box "$CATPPUCCIN_BLUE" "Usage:" \
      "  mkcommitlint [-h]"

    cbc_style_box "$CATPPUCCIN_TEAL" "Options:" \
      "  -h    Display this help message"

    cbc_style_box "$CATPPUCCIN_PEACH" "Examples:" \
      "  mkcommitlint"
  }

  while getopts ":h" opt; do
    case ${opt} in
    h)
      usage
      return 0
      ;;
    \?)
      cbc_style_message "$CATPPUCCIN_RED" "Invalid option: -$OPTARG"
      usage
      return 1
      ;;
    esac
  done

  shift $((OPTIND - 1))

  if [ "$#" -gt 0 ]; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: mkcommitlint does not accept arguments."
    usage
    return 1
  fi

  # --------------------------------------------------------------------------
  # Preflight: required tools
  # --------------------------------------------------------------------------
  local cmd
  for cmd in gum git node; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: missing required command: $cmd"
      return 1
    fi
  done

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: mkcommitlint must run inside a git repository."
    return 1
  fi

  local target_dir
  target_dir="$(git rev-parse --show-toplevel)" || {
    cbc_style_message "$CATPPUCCIN_RED" "Error: Could not resolve git repository root."
    return 1
  }

  local repo_name
  repo_name="$(basename "$target_dir")"

  if [ -z "$repo_name" ]; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Could not determine repo name from path."
    return 1
  fi

  local cwd
  cwd="$(pwd -P)"

  local display_dir
  display_dir="$(realpath -m --relative-to="$cwd" "$target_dir")"

  if [ -z "$display_dir" ]; then
    display_dir="$target_dir"
  fi

  if [ -n "$(git -C "$target_dir" status --porcelain)" ]; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: mkcommitlint creates commits and requires a clean worktree."
    return 1
  fi

  local has_commits="false"

  if git -C "$target_dir" rev-parse --verify HEAD >/dev/null 2>&1; then
    has_commits="true"
  fi

  local current_branch
  current_branch="$(git -C "$target_dir" branch --show-current)" || {
    cbc_style_message "$CATPPUCCIN_RED" "Error: Could not determine current branch."
    return 1
  }

  if [ -z "$current_branch" ]; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: mkcommitlint cannot run from a detached HEAD."
    return 1
  fi

  local remote_name=""
  local configured_remote
  configured_remote="$(git -C "$target_dir" config "branch.$current_branch.remote" 2>/dev/null || true)"

  if [ -n "$configured_remote" ] && \
    git -C "$target_dir" remote get-url "$configured_remote" >/dev/null 2>&1; then
    remote_name="$configured_remote"
  elif git -C "$target_dir" remote get-url origin >/dev/null 2>&1; then
    remote_name="origin"
  else
    local remote_candidate

    while IFS= read -r remote_candidate; do
      remote_name="$remote_candidate"
      break
    done < <(git -C "$target_dir" remote)
  fi

  local push_action="skip; no remote configured"

  if [ -n "$remote_name" ]; then
    push_action="push $current_branch to $remote_name"
  fi

  # --------------------------------------------------------------------------
  # Resolve package manager
  # --------------------------------------------------------------------------
  local package_json="$target_dir/package.json"
  local package_manager=""
  local package_manager_source="default"
  local create_package_json="false"

  if [ -f "$package_json" ]; then
    local declared_package_manager
    declared_package_manager="$(node -e 'const fs = require("fs"); const file = process.argv[1]; const pkg = JSON.parse(fs.readFileSync(file, "utf8")); const value = String(pkg.packageManager || ""); if (value) process.stdout.write(value.split("@")[0]);' "$package_json")" || {
      cbc_style_message "$CATPPUCCIN_RED" "Error: package.json is not valid JSON."
      return 1
    }

    case "$declared_package_manager" in
    npm | pnpm | yarn | bun)
      package_manager="$declared_package_manager"
      package_manager_source="package.json packageManager"
      ;;
    "")
      ;;
    *)
      cbc_style_message "$CATPPUCCIN_RED" "Error: unsupported package manager: $declared_package_manager"
      return 1
      ;;
    esac
  else
    create_package_json="true"
  fi

  if [ -z "$package_manager" ]; then
    if [ -f "$target_dir/pnpm-lock.yaml" ]; then
      package_manager="pnpm"
      package_manager_source="pnpm-lock.yaml"
    elif [ -f "$target_dir/yarn.lock" ]; then
      package_manager="yarn"
      package_manager_source="yarn.lock"
    elif [ -f "$target_dir/bun.lock" ] || [ -f "$target_dir/bun.lockb" ]; then
      package_manager="bun"
      package_manager_source="bun lockfile"
    elif [ -f "$target_dir/package-lock.json" ] || [ -f "$target_dir/npm-shrinkwrap.json" ]; then
      package_manager="npm"
      package_manager_source="npm lockfile"
    else
      package_manager="npm"
      package_manager_source="default"
    fi
  fi

  if ! command -v "$package_manager" >/dev/null 2>&1; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: missing required package manager: $package_manager"
    return 1
  fi

  if [ "$create_package_json" = "true" ] && ! command -v npm >/dev/null 2>&1; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: npm is required to create package.json."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Detect existing config and hook state
  # --------------------------------------------------------------------------
  local commitlint_config=""
  local config_candidate

  for config_candidate in \
    commitlint.config.js \
    commitlint.config.cjs \
    commitlint.config.mjs \
    .commitlintrc \
    .commitlintrc.json \
    .commitlintrc.yaml \
    .commitlintrc.yml \
    .commitlintrc.js \
    .commitlintrc.cjs \
    .commitlintrc.mjs; do
    if [ -f "$target_dir/$config_candidate" ]; then
      commitlint_config="$config_candidate"
      break
    fi
  done

  local config_action="create commitlint.config.cjs"

  if [ -n "$commitlint_config" ]; then
    config_action="keep $commitlint_config"
  fi

  local hook_file="$target_dir/.husky/commit-msg"
  local hook_action="create .husky/commit-msg"

  if [ -f "$hook_file" ]; then
    if grep -q "commitlint" "$hook_file"; then
      hook_action="keep existing commit-msg hook"
    else
      hook_action="append to existing commit-msg hook"
    fi
  fi

  local package_action="use existing package.json"

  if [ "$create_package_json" = "true" ]; then
    package_action="create package.json"
  fi

  local initial_commit_action="skip"

  if [ "$has_commits" != "true" ]; then
    initial_commit_action="create chore: initial commit"
  fi

  cbc_style_box "$CATPPUCCIN_LAVENDER" "Commitlint Bootstrap" \
    "  Repository: $repo_name" \
    "  Path: $display_dir" \
    "  Branch: $current_branch" \
    "  Baseline commit: $initial_commit_action" \
    "  Remote push: $push_action" \
    "  Package manager: $package_manager ($package_manager_source)" \
    "  Package file: $package_action" \
    "  Commitlint config: $config_action" \
    "  Husky hook: $hook_action" \
    "  Commits: create incremental Conventional Commits"

  if ! gum confirm "Bootstrap commitlint in this repository?"; then
    cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
    return 0
  fi

  commit_bootstrap_paths() {
    local subject="$1"
    local body="$2"
    local pathspec

    shift 2

    for pathspec in "$@"; do
      if [ -e "$target_dir/$pathspec" ] || \
        git -C "$target_dir" ls-files --error-unmatch "$pathspec" >/dev/null 2>&1; then
        git -C "$target_dir" add -- "$pathspec" || return 1
      fi
    done

    if git -C "$target_dir" diff --cached --quiet; then
      return 0
    fi

    if ! gum spin --spinner dot --title "Creating commit: $subject" -- \
      git -C "$target_dir" commit -m "$subject" -m "$body"; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to create commit: $subject"
      return 1
    fi
  }

  # --------------------------------------------------------------------------
  # chore: initial commit
  # --------------------------------------------------------------------------
  if [ "$has_commits" != "true" ]; then
    if ! cbc_create_empty_initial_commit \
      "$target_dir" \
      "Create a clean repository baseline before adding commitlint automation."; then
      return 1
    fi
  fi

  # --------------------------------------------------------------------------
  # Ignore installed dependencies
  # --------------------------------------------------------------------------
  local gitignore_file="$target_dir/.gitignore"

  if [ -f "$gitignore_file" ]; then
    if ! grep -Eq '^[[:space:]]*/?node_modules/?[[:space:]]*$' "$gitignore_file"; then
      {
        printf '\n'
        printf '%s\n' 'node_modules/'
      } >> "$gitignore_file"
    fi
  else
    printf '%s\n' 'node_modules/' > "$gitignore_file"
  fi

  if ! commit_bootstrap_paths \
    "chore(gitignore): ignore node dependencies" \
    "Keep installed package dependencies out of repository history." \
    .gitignore; then
    return 1
  fi

  # --------------------------------------------------------------------------
  # package.json
  # --------------------------------------------------------------------------
  if [ "$create_package_json" = "true" ]; then
    if ! gum spin --spinner dot --title "Creating package.json..." -- \
      bash -c 'cd "$1" && npm init -y' _ "$target_dir"; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to create package.json."
      return 1
    fi
  fi

  # --------------------------------------------------------------------------
  # Dependencies
  # --------------------------------------------------------------------------
  case "$package_manager" in
  npm)
    if ! gum spin --spinner dot --title "Installing commitlint tooling..." -- \
      bash -c 'cd "$1" && npm install --save-dev @commitlint/cli @commitlint/config-conventional husky' _ "$target_dir"; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to install commitlint tooling."
      return 1
    fi
    ;;
  pnpm)
    if ! gum spin --spinner dot --title "Installing commitlint tooling..." -- \
      bash -c 'cd "$1" && pnpm add --save-dev @commitlint/cli @commitlint/config-conventional husky' _ "$target_dir"; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to install commitlint tooling."
      return 1
    fi
    ;;
  yarn)
    if ! gum spin --spinner dot --title "Installing commitlint tooling..." -- \
      bash -c 'cd "$1" && yarn add --dev @commitlint/cli @commitlint/config-conventional husky' _ "$target_dir"; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to install commitlint tooling."
      return 1
    fi
    ;;
  bun)
    if ! gum spin --spinner dot --title "Installing commitlint tooling..." -- \
      bash -c 'cd "$1" && bun add --dev @commitlint/cli @commitlint/config-conventional husky' _ "$target_dir"; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to install commitlint tooling."
      return 1
    fi
    ;;
  esac

  # --------------------------------------------------------------------------
  # Dependency commit
  # --------------------------------------------------------------------------
  local -a package_paths

  case "$package_manager" in
  npm)
    package_paths=(package.json package-lock.json npm-shrinkwrap.json)
    ;;
  pnpm)
    package_paths=(package.json pnpm-lock.yaml)
    ;;
  yarn)
    package_paths=(package.json yarn.lock)
    ;;
  bun)
    package_paths=(package.json bun.lock bun.lockb)
    ;;
  esac

  if ! commit_bootstrap_paths \
    "build(commitlint): add commitlint dependencies" \
    "Install Commitlint and Husky as development dependencies." \
    "${package_paths[@]}"; then
    return 1
  fi

  # --------------------------------------------------------------------------
  # Commitlint config
  # --------------------------------------------------------------------------
  if [ -z "$commitlint_config" ]; then
    {
      printf '%s\n' 'module.exports = {'
      printf '%s\n' '  extends: ["@commitlint/config-conventional"],'
      printf '%s\n' '};'
    } > "$target_dir/commitlint.config.cjs"
  fi

  if ! commit_bootstrap_paths \
    "build(commitlint): add conventional commit rules" \
    "Configure Commitlint to enforce Conventional Commits." \
    commitlint.config.cjs; then
    return 1
  fi

  # --------------------------------------------------------------------------
  # package.json scripts
  # --------------------------------------------------------------------------
  if ! node -e 'const fs = require("fs"); const file = process.argv[1]; const pkg = JSON.parse(fs.readFileSync(file, "utf8")); pkg.scripts = pkg.scripts || {}; const prepare = String(pkg.scripts.prepare || "").trim(); if (!prepare) { pkg.scripts.prepare = "husky"; } else if (!/\bhusky\b/.test(prepare)) { pkg.scripts.prepare = `${prepare} && husky`; } fs.writeFileSync(file, `${JSON.stringify(pkg, null, 2)}\n`);' "$package_json"; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to update package.json prepare script."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Husky setup
  # --------------------------------------------------------------------------
  case "$package_manager" in
  npm)
    if ! gum spin --spinner dot --title "Initializing Husky..." -- \
      bash -c 'cd "$1" && ./node_modules/.bin/husky' _ "$target_dir"; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Husky initialization failed."
      return 1
    fi
    ;;
  pnpm)
    if ! gum spin --spinner dot --title "Initializing Husky..." -- \
      bash -c 'cd "$1" && pnpm exec husky' _ "$target_dir"; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Husky initialization failed."
      return 1
    fi
    ;;
  yarn)
    if ! gum spin --spinner dot --title "Initializing Husky..." -- \
      bash -c 'cd "$1" && yarn husky' _ "$target_dir"; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Husky initialization failed."
      return 1
    fi
    ;;
  bun)
    if ! gum spin --spinner dot --title "Initializing Husky..." -- \
      bash -c 'cd "$1" && bun run husky' _ "$target_dir"; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Husky initialization failed."
      return 1
    fi
    ;;
  esac

  mkdir -p "$target_dir/.husky"

  local hook_command

  case "$package_manager" in
  npm)
    hook_command='./node_modules/.bin/commitlint --edit "$1"'
    ;;
  pnpm)
    hook_command='pnpm exec commitlint --edit "$1"'
    ;;
  yarn)
    hook_command='yarn commitlint --edit "$1"'
    ;;
  bun)
    hook_command='bun run commitlint --edit "$1"'
    ;;
  esac

  if [ ! -f "$hook_file" ]; then
    {
      printf '%s\n' '#!/usr/bin/env sh'
      printf '\n'
      printf '%s\n' "$hook_command"
    } > "$hook_file"
  elif ! grep -q "commitlint" "$hook_file"; then
    {
      printf '\n'
      printf '%s\n' "$hook_command"
    } >> "$hook_file"
  fi

  chmod +x "$hook_file"

  if ! commit_bootstrap_paths \
    "build(husky): enforce commitlint on commits" \
    "Run Commitlint from the commit-msg hook for every new commit." \
    package.json .husky; then
    return 1
  fi

  # --------------------------------------------------------------------------
  # Verification
  # --------------------------------------------------------------------------
  local message_file
  message_file="$(mktemp)" || {
    cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to create temporary message file."
    return 1
  }

  printf '%s\n' 'chore: verify commitlint setup' > "$message_file"

  case "$package_manager" in
  npm)
    if ! gum spin --spinner dot --title "Verifying commitlint..." -- \
      bash -c 'cd "$1" && ./node_modules/.bin/commitlint --edit "$2"' _ "$target_dir" "$message_file"; then
      rm -f "$message_file"
      cbc_style_message "$CATPPUCCIN_RED" "Error: Commitlint verification failed."
      return 1
    fi
    ;;
  pnpm)
    if ! gum spin --spinner dot --title "Verifying commitlint..." -- \
      bash -c 'cd "$1" && pnpm exec commitlint --edit "$2"' _ "$target_dir" "$message_file"; then
      rm -f "$message_file"
      cbc_style_message "$CATPPUCCIN_RED" "Error: Commitlint verification failed."
      return 1
    fi
    ;;
  yarn)
    if ! gum spin --spinner dot --title "Verifying commitlint..." -- \
      bash -c 'cd "$1" && yarn commitlint --edit "$2"' _ "$target_dir" "$message_file"; then
      rm -f "$message_file"
      cbc_style_message "$CATPPUCCIN_RED" "Error: Commitlint verification failed."
      return 1
    fi
    ;;
  bun)
    if ! gum spin --spinner dot --title "Verifying commitlint..." -- \
      bash -c 'cd "$1" && bun run commitlint --edit "$2"' _ "$target_dir" "$message_file"; then
      rm -f "$message_file"
      cbc_style_message "$CATPPUCCIN_RED" "Error: Commitlint verification failed."
      return 1
    fi
    ;;
  esac

  rm -f "$message_file"

  if [ -n "$remote_name" ]; then
    if ! gum spin --spinner dot --title "Pushing $current_branch to remote..." -- \
      git -C "$target_dir" push -u "$remote_name" "$current_branch"; then
      cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to push $current_branch branch."
      return 1
    fi
  fi

  cbc_style_box "$CATPPUCCIN_GREEN" "Commitlint bootstrapped successfully!" \
    "  Path: $target_dir" \
    "  Branch: $current_branch" \
    "  Remote: ${remote_name:-none}" \
    "  Config: ${commitlint_config:-commitlint.config.cjs}" \
    "  Hook: .husky/commit-msg"
}
