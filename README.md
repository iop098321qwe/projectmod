# Projectmod

Bootstrap new repositories, CBC modules, and OpenCode skills with git and
optional GitHub publishing. Guides setup for repo creation, licensing, and
git-flow defaults.

## Functions

- `mkmod`: Create a new CBC module with git, GitHub, `AGENTS.md`, and
  scaffolding.
- `mkrepo`: Create a generic repository with git, `README.md`, `AGENTS.md`,
  and bootstrap scaffolding. Can publish to GitHub with a `LICENSE`, stay
  local only, and optionally initialize Commitlint.
- `mkskill`: Create a new OpenCode skill with git, GitHub, and
  scaffolding.
- `mkcommitlint`: Add Commitlint and Husky commit message validation to
  `main` and `develop` with incremental setup commits. Pushes both branches
  when a remote is configured.

## Aliases
- None.
