#!/usr/bin/env bash

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

  # --------------------------------------------------------------------------
  # Confirm before proceeding
  # --------------------------------------------------------------------------
  cbc_style_box "$CATPPUCCIN_LAVENDER" "New CBC Module" \
    "  Directory: $target_dir" \
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
  # Create directory and cbc-module.sh
  # --------------------------------------------------------------------------
  if ! gum spin --spinner dot --title "Creating directory..." -- \
    mkdir -p "$target_dir"; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to create directory."
    return 1
  fi

  printf '#!/usr/bin/env bash\n' > "$target_dir/cbc-module.sh"

  # --------------------------------------------------------------------------
  # Git init with main as default branch
  # --------------------------------------------------------------------------
  if ! gum spin --spinner dot --title "Initializing git repository..." -- \
    git -C "$target_dir" init -b main; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: git init failed."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Initial commit
  # --------------------------------------------------------------------------
  if ! gum spin --spinner dot --title "Creating initial commit..." -- \
    bash -c "git -C \"$target_dir\" add cbc-module.sh && git -C \"$target_dir\" commit -m 'initial commit'"; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Initial commit failed."
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
    bash -c "cd \"$target_dir\" && gh license create gpl-3.0 && git add LICENSE && git commit -m 'add GPL-3.0 license'"; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: License creation failed."
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

  cbc_style_box "$CATPPUCCIN_GREEN" "Module created successfully!" \
    "  Path: $target_dir" \
    "  Repo: ${repo_url:-$repo_name}"

  cd "$target_dir" || return 1
  yazi
}
