#!/usr/bin/env bash

# Keep command discovery immediate without parsing the implementation in
# every terminal. Older CBC versions and standalone sourcing stay eager.
if declare -F cbc_lazy_register >/dev/null; then
  cbc_lazy_register "${BASH_SOURCE[0]%cbc-module.sh}projectmod.sh" \
    cbc_agents_file_purpose cbc_write_agents_md \
    cbc_create_empty_initial_commit cbc_ensure_todo_txt cbc_commit_todo_txt \
    cbc_align_scaffold_branches cbc_offer_zensical_docs_bootstrap \
    mkmod mkrepo mkskill mkzendocs docsite mkcommitlint
else
  source "${BASH_SOURCE[0]%cbc-module.sh}projectmod.sh"
fi
