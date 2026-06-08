# Projectmod

Bootstrap new repositories, CBC modules, and OpenCode skills with git and
optional GitHub publishing. Guides setup for repo creation, licensing, and
git-flow defaults.

New repository bootstraps start with an empty `chore: initial commit`, then
record generated files as incremental Conventional Commits.

## Functions

- `mkmod`: Create a new CBC module with git, GitHub, `AGENTS.md`,
  scaffolding, and optional Commitlint initialization.
- `mkrepo`: Create a generic repository with git, `README.md`, `AGENTS.md`,
  and bootstrap scaffolding. Can publish to GitHub with a `LICENSE`, stay
  local only, and optionally initialize Commitlint.
- `mkskill`: Create a new OpenCode skill with git, GitHub, and
  scaffolding.
- `mkcommitlint`: Add Commitlint and Husky commit message validation to the
  current branch with incremental setup commits. Pushes only the current
  branch when a remote is configured.

## Commit History

- `mkmod`, `mkrepo`, `mkskill`, and new-history `mkcommitlint` runs create an
  empty `chore: initial commit` before scaffold files are committed.
- Generated scaffold changes use separate Conventional Commits so each setup
  step remains reviewable.

## Aliases

- None.
