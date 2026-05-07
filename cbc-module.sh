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

################################################################################
# MKREPO
################################################################################

mkrepo() {
  OPTIND=1

  usage() {
    cbc_style_box "$CATPPUCCIN_MAUVE" "Description:" \
      "  Bootstrap a new repository with git, git-flow, and GitHub."

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

  local repo_visibility
  repo_visibility=$(gum choose "public" "private") || {
    cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
    return 0
  }

  local gh_visibility_flag
  gh_visibility_flag="--public"

  if [ "$repo_visibility" = "private" ]; then
    gh_visibility_flag="--private"
  fi

  local readme_action="create"
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

    if [ -e "$target_dir/LICENSE" ]; then
      if ! gum confirm "Replace existing LICENSE with GPL-3.0?"; then
        cbc_style_message "$CATPPUCCIN_YELLOW" "Canceled."
        return 0
      fi
    fi

    if [ -n "$(find "$target_dir" -mindepth 1 -maxdepth 1 ! -name '.git' ! -name 'README.md' ! -name 'LICENSE' -print -quit 2>/dev/null)" ]; then
      if gum confirm "Commit existing files in a separate commit?"; then
        include_existing_files="true"
      fi
    fi
  fi

  # --------------------------------------------------------------------------
  # Confirm before proceeding
  # --------------------------------------------------------------------------
  cbc_style_box "$CATPPUCCIN_LAVENDER" "New Repository" \
    "  Directory: $display_dir" \
    "  Repo name: $repo_name" \
    "  Visibility: $repo_visibility"

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
  # Empty initial commit
  # --------------------------------------------------------------------------
  if ! gum spin --spinner dot --title "Creating empty initial commit..." -- \
    git -C "$target_dir" commit --allow-empty -m "initial commit"; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Empty initial commit failed."
    return 1
  fi

  # --------------------------------------------------------------------------
  # Commit existing files, if requested
  # --------------------------------------------------------------------------
  if [ "$include_existing_files" = "true" ]; then
    if ! gum spin --spinner dot --title "Creating existing files commit..." -- \
      bash -c 'git -C "$1" add --all -- . ":(exclude)README.md" ":(exclude)LICENSE" && if git -C "$1" diff --cached --quiet; then exit 0; fi && git -C "$1" commit -m "chore: add existing project files" -m "Record existing non-bootstrap files before adding generated repository scaffolding."' _ "$target_dir"; then
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
  if ! gum spin --spinner dot --title "Creating GPL-3.0 license..." -- \
    bash -c 'if [ -e "$1/LICENSE" ]; then rm -f "$1/LICENSE"; fi && cd "$1" && gh license create gpl-3.0 && git add LICENSE && git commit -m "chore(license): add GPL-3.0 license" -m "Add the project license file before publishing the repository to GitHub."' _ "$target_dir"; then
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
  # Create GitHub repo and set remote
  # --------------------------------------------------------------------------
  if ! gum spin --spinner dot --title "Creating GitHub repository..." -- \
    gh repo create "$repo_name" "$gh_visibility_flag" --description "$project_description" --source="$target_dir" --remote=origin; then
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

  cbc_style_box "$CATPPUCCIN_GREEN" "Repository created successfully!" \
    "  Path: $target_dir" \
    "  Repo: ${repo_url:-$repo_name}"

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
  # Create directory and SKILL.md
  # --------------------------------------------------------------------------
  if ! gum spin --spinner dot --title "Creating skill directory..." -- \
    mkdir -p "$target_dir"; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Failed to create directory."
    return 1
  fi

  printf '' > "$target_dir/SKILL.md"

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
    bash -c "git -C \"$target_dir\" add SKILL.md && git -C \"$target_dir\" commit -m 'initial commit'"; then
    cbc_style_message "$CATPPUCCIN_RED" "Error: Initial commit failed."
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
