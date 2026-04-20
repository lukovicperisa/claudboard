## Repo scan: /Users/LUP1BG/.claude/plugins/cache/claude-plugins-official/skill-creator/unknown

**Stack:** Python · Claude Code Plugin (skill) · no build tool
**Size:** ~21 files, ~9 dirs (excl. .git)

### Structure
```
.claude-plugin/plugin.json        — plugin manifest (name, author, description)
LICENSE                           — Apache 2.0
README.md                         — one-paragraph description
skills/skill-creator/
  SKILL.md                        — main skill definition (~32 KB, ~500 lines)
  agents/                         — sub-agent prompt files (analyzer.md, comparator.md, grader.md)
  assets/eval_review.html         — standalone eval review HTML template
  eval-viewer/                    — viewer.html + generate_review.py (Python, eval HTML generation)
  references/schemas.md           — JSON schema reference docs
  scripts/                        — 8 Python scripts (run_eval, run_loop, aggregate_benchmark,
                                    generate_report, improve_description, package_skill,
                                    quick_validate, utils)
```

### Dependencies (0)
No package.json, requirements.txt, pyproject.toml, or other dependency manifest present. Python scripts use only stdlib modules (`argparse`, `json`, `subprocess`, `pathlib`, `concurrent.futures`, etc.).

### Issues
[WARN] No CI — no `.github/workflows/`, `.gitlab-ci.yml`, `.circleci/`, or `Jenkinsfile`
[WARN] No tests — no `tests/`, `test/`, `__tests__/`, `*.test.*`, or `*.spec.*` files
[WARN] No .gitignore — missing `.gitignore`
[INFO] No declared Python dependencies — scripts import stdlib only; assumes `claude` CLI available on PATH at runtime

### Summary
This is an official Anthropic Claude Code plugin ("skill-creator") that provides Claude with a structured workflow for creating, evaluating, and iteratively improving Claude Code skills. It bundles a detailed SKILL.md instruction set alongside Python utility scripts for running evals, benchmarking, aggregating results, and packaging skills for distribution. Notable: no dependency manifest, no CI, and no automated tests — appropriate for a prompt-engineering/AI workflow plugin, but the Python scripts have no declared runtime requirements beyond stdlib and an assumed `claude` CLI.
