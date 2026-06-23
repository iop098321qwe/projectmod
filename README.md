# Projectmod

Bootstrap new repositories, CBC modules, OpenCode skills, and Zensical docs
with git and optional GitHub publishing. Guides setup for repo creation,
licensing, and git-flow defaults.

New repository bootstraps start with an empty `chore: initial commit`, then
record generated files as incremental Conventional Commits.
Bootstrap flows that create `todo.txt` also create blank `done.txt` and
`inbox.txt.tuxedo-lock` files alongside it for todo workflows.

## Functions

- `mkmod`: Create a new CBC module with git, GitHub, `AGENTS.md`,
  scaffolding, optional Commitlint initialization, and optional Zensical docs
  bootstrap.
- `mkrepo`: Create a generic repository with git, `README.md`, `AGENTS.md`,
  and bootstrap scaffolding. Can publish to GitHub with a `LICENSE`, stay
  local only, and optionally initialize Commitlint and Zensical docs.
- `mkskill`: Create a new OpenCode skill with git, GitHub, and
  scaffolding, with optional Zensical docs bootstrap.
- `mkcommitlint`: Add Commitlint and Husky commit message validation to the
  current branch with incremental setup commits. Pushes only the current
  branch when a remote is configured.
- `mkzendocs`: Idempotently bootstrap Zensical documentation from the
  repository root when available, or with confirmation outside a repository.
  Recreates the ignored local `.venv` as needed, prompts for `site_name` when
  creating `zensical.toml`, creates incremental Conventional Commits for
  generated docs artifacts and root-doc symlinks, and pushes the current branch
  when a remote is configured.
- `docsite`: Open the current repository's Zensical docs site in the default
  browser. Requires running inside a git repository with `zensical.toml` and a
  qualifying `docs/` entry page.

## Commit History

- `mkmod`, `mkrepo`, `mkskill`, and new-history `mkcommitlint` runs create an
  empty `chore: initial commit` before scaffold files are committed.
- Bootstrap flows that add `todo.txt` also add blank `done.txt` and
  `inbox.txt.tuxedo-lock` files in the same directory.
- Generated scaffold changes use separate Conventional Commits so each setup
  step remains reviewable.
- Optional Zensical docs bootstraps run through `mkzendocs`, preserving its
  incremental documentation commit history.
- `mkzendocs` commits each generated documentation artifact and root-doc
  symlink separately, skipping commits for unchanged files.

## Aliases

- None.
