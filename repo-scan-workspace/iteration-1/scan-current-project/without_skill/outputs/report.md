## Repo scan: /Users/LUP1BG/Documents/BoschProjects/claude-repo-scan

**Stack:** Markdown · JSON · Claude Code skill/plugin framework · No traditional runtime language
**Size:** ~15 files, ~14 dirs (excl. `.git/`, `.claude/`)

### Structure

```
claude-repo-scan/
├── CLAUDE.md                          # Project instructions for Claude; describes skill anatomy and goals
├── skills/
│   └── repo-scan/
│       └── SKILL.md                   # Primary skill definition (prompt file loaded by Skill tool)
├── evals/
│   └── evals.json                     # 3 eval prompts with expected outputs for skill validation
├── repo-scan-workspace/
│   └── iteration-1/                   # Eval run workspace; sub-dirs per eval scenario
│       ├── scan-caveman-plugin/       # eval_metadata.json + with_skill/ + without_skill/ outputs
│       ├── scan-current-project/      # eval_metadata.json + with_skill/ + without_skill/ outputs
│       └── scan-skill-creator/        # eval_metadata.json + with_skill/ + without_skill/ outputs
└── .claude/
    └── settings.local.json            # Claude Code permissions (allow Read on ~/.claude/plugins/**)
```

### Dependencies (none)

No `package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, or any other dependency manifest found. The project has no runtime dependencies — it is a pure prompt/configuration artifact.

### Issues

[WARN] No tests — no `test/`, `tests/`, `__tests__/`, `spec/`, `*.test.*`, or `*.spec.*` files found. Eval metadata (JSON assertions) partially fills this gap but does not constitute runnable tests.
[WARN] No CI config — no `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/`, or `azure-pipelines.yml` found.
[WARN] No `.gitignore` — project root lacks a `.gitignore` file.
[WARN] No `LICENSE` — no `LICENSE` or `LICENSE.md` file present.
[INFO] No `README.md` at the project root — `CLAUDE.md` serves as developer documentation, but a user-facing README is absent.
[INFO] `skills/repo-scan/SKILL.md` is the sole deliverable artifact. No hooks (`pre-scan.sh`, `post-scan.sh`) have been implemented yet, though `CLAUDE.md` documents them as planned.
[INFO] All `with_skill/outputs` and `without_skill/outputs` directories are currently empty — no eval run results have been captured yet.

### Summary

This project is a Claude Code skill (plugin) called `repo-scan`, designed to scan arbitrary repositories and produce a structured analysis report. The core deliverable is a single Markdown prompt file (`skills/repo-scan/SKILL.md`) that instructs Claude how to detect stack, map structure, summarize dependencies, and flag issues. An eval harness (`evals/evals.json` + per-scenario `eval_metadata.json` files) exists to validate skill behaviour, but no CI, tests, hooks, or license have been implemented, making this an early-stage, work-in-progress skill under active development.
