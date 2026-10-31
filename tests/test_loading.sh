#!/usr/bin/env bash
# Run from the module root. Set CBC_TEST_SCRIPT to test lazy integration.
set -eo pipefail
module_root="$PWD"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
export HOME="$fixture" CBC_CONFIG_DIR="$fixture/config"
export CBC_MODULE_ROOT="$fixture/modules"
mkdir -p "$CBC_CONFIG_DIR" "$CBC_MODULE_ROOT"
printf '%s\n' 'CBC_SHOW_BANNER=false' 'CBC_USE_GUM=false' \
  'CBC_SOURCE_BASH_ALIASES=false' >"$CBC_CONFIG_DIR/cbc.config"
: >"$HOME/.cbc_aliases.sh"
cbc_style_box() { shift; printf '%s\n' "$@"; printf '\n'; }
cbc_style_message() { shift; printf '%s\n' "$@"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
commands=(mkmod mkrepo mkskill mkzendocs docsite mkcommitlint)

# Standalone/older CBC sourcing must still define every command eagerly.
source ./cbc-module.sh
for command in "${commands[@]}"; do
  "$command" -h >"$fixture/$command.eager"
  [[ -s "$fixture/$command.eager" ]] || fail "No help for $command."
done
if docsite --invalid >/dev/null 2>&1; then fail 'Bad option succeeded.'; fi

if [ -n "${CBC_TEST_SCRIPT:-}" ]; then
  source "$CBC_TEST_SCRIPT"
  source "$module_root/cbc-module.sh"
  [[ "$(declare -f mkrepo)" == *cbc_lazy_invoke* ]] ||
    fail 'Implementation was parsed at startup.'
  for command in "${commands[@]}"; do
    "$command" -h >"$fixture/$command.lazy"
    cmp "$fixture/$command.eager" "$fixture/$command.lazy"
  done
  [[ "$PWD" == "$module_root" ]] || fail 'Help changed directories.'
  [[ "$(declare -f mkrepo)" != *cbc_lazy_invoke* ]] ||
    fail 'First use did not promote the entire command group.'
  source "$module_root/cbc-module.sh"
  [[ "$(declare -f mkrepo)" == *cbc_lazy_invoke* ]] ||
    fail 'Reload did not reset lazy functions.'
  mkrepo -h >"$fixture/reloaded"
  cmp "$fixture/mkrepo.eager" "$fixture/reloaded"
else
  printf '%s\n' 'SKIP: lazy integration (set CBC_TEST_SCRIPT)'
fi
printf '%s\n' 'PASS: project command help, eager fallback, and lazy reload'
