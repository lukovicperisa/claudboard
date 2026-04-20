## Repo scan: /Users/LUP1BG/.claude/plugins/cache/caveman/caveman/63e797cd753b

**Stack:** JavaScript (Node.js hooks) · Python (evals/compress scripts) · Claude Code plugin/skill framework
**Size:** ~93 files, ~48 dirs (excl. .git)

### Structure
```
63e797cd753b/
├── caveman/SKILL.md          # Core caveman communication-mode skill
├── skills/                   # 5 skills: caveman, caveman-commit, caveman-help, caveman-review, compress
├── hooks/                    # JS hooks: caveman-activate.js, caveman-mode-tracker.js, caveman-config.js
├── caveman-compress/scripts/ # Python scripts: compress.py, detect.py, cli.py, benchmark.py, validate.py
├── plugins/caveman/          # Duplicate skill+compress tree (packaged plugin form)
├── benchmarks/               # Eval runner (run.py, requirements.txt → anthropic>=0.40.0)
├── evals/                    # LLM eval harness (llm_run.py, measure.py, plot.py, prompts/, snapshots/)
├── tests/                    # test_hooks.py, verify_repo.py
├── .github/workflows/        # sync-skill.yml (CI present)
├── .claude-plugin/           # plugin.json, marketplace.json
├── CLAUDE.md + CLAUDE.original.md
├── caveman.skill             # ZIP binary (packaged skill archive)
└── docs/, rules/, commands/, .cursor/, .windsurf/, .agents/, .codex/, .clinerules/
```

### Dependencies (1 primary)
`anthropic>=0.40.0` — Anthropic Python SDK (used in compress.py and benchmarks for LLM calls via API key from env)

### Issues
[INFO] `api_key=` pattern in `caveman-compress/scripts/compress.py:37` and `plugins/caveman/skills/compress/scripts/compress.py:37` — reads from `os.environ.get("ANTHROPIC_API_KEY")`, no hardcoded value; safe.
[INFO] `CLAUDE.original.md` present alongside compressed `CLAUDE.md` — intentional backup from caveman:compress skill run.
[INFO] `caveman.skill` is a binary ZIP archive at repo root — not a large file (well under 5MB), but unusual artifact to commit.
[INFO] No `package.json`/lockfile; JS hooks have no declared deps (use only Node built-ins).

### Summary
This is the "caveman" Claude Code plugin — an ultra-compressed communication mode that cuts ~75% of LLM output tokens while preserving technical accuracy. It ships 5 skills (caveman, caveman-commit, caveman-help, caveman-review, compress), Node.js session hooks to activate/track caveman mode, Python scripts for memory-file compression via the Anthropic API, and an LLM eval harness with benchmarks and tests. Project is well-structured with CI, LICENSE, README, and a `.claude-plugin` manifest for marketplace distribution.
