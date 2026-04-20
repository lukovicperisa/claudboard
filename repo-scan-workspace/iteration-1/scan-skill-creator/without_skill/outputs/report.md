# Repository Scan Report

**Target directory:** `/Users/LUP1BG/.claude/plugins/cache/claude-plugins-official/skill-creator/unknown`
**Scan date:** 2026-04-15

---

## Overview

This directory is an official Anthropic Claude Code plugin named **skill-creator**. It is a meta-skill: a Claude Code skill whose purpose is to help users create, iterate on, evaluate, and publish other Claude Code skills. It is distributed in the Claude plugins cache and authored by Anthropic (`support@anthropic.com`).

---

## Language / Framework / Stack

| Layer | Technology |
|---|---|
| Primary language | Python 3 (standard library + `anthropic` SDK) |
| Secondary content | Markdown (skill instructions, agent prompts, schema docs) |
| UI / viewer | Vanilla HTML + CSS + JavaScript (self-contained, no build step) |
| Skill format | Custom YAML-frontmatter Markdown (`.md` / `.skill` zip) |
| External CLI dependency | `claude` (Claude Code CLI, invoked via `subprocess`) |
| Python dependencies | `anthropic`, `yaml` (PyYAML), standard library only for everything else |
| License | Apache 2.0 |

No `requirements.txt`, `pyproject.toml`, `setup.py`, or `package.json` is present. Python dependencies are implicit.

---

## Directory Structure

```
unknown/
├── .claude-plugin/
│   └── plugin.json                  # Plugin manifest (name, description, author)
├── LICENSE                          # Apache 2.0 (top-level)
├── README.md                        # One-line description of the plugin
└── skills/
    └── skill-creator/
        ├── SKILL.md                 # Main skill instructions + YAML frontmatter (480 lines)
        ├── LICENSE.txt              # Apache 2.0 (skill-level copy)
        ├── agents/
        │   ├── analyzer.md          # Instructions for post-hoc analysis subagent
        │   ├── comparator.md        # Instructions for blind A/B comparison subagent
        │   └── grader.md            # Instructions for assertion grading subagent
        ├── assets/
        │   └── eval_review.html     # HTML template for trigger-eval review UI
        ├── eval-viewer/
        │   ├── generate_review.py   # HTTP server + HTML generator for qualitative review
        │   └── viewer.html          # (referenced by generate_review.py)
        ├── references/
        │   └── schemas.md           # JSON schema documentation for all data files
        └── scripts/
            ├── __init__.py          # Empty package marker
            ├── aggregate_benchmark.py   # Aggregates grading.json files into benchmark.json
            ├── generate_report.py       # Generates HTML report from run_loop output
            ├── improve_description.py   # Uses Claude (extended thinking) to improve skill descriptions
            ├── package_skill.py         # Packages a skill folder into a .skill zip file
            ├── quick_validate.py        # Validates SKILL.md frontmatter (name, description, YAML)
            ├── run_eval.py              # Runs trigger-evaluation queries against the claude CLI
            └── run_loop.py              # Orchestrates full eval + improve loop with train/test split
            └── utils.py                 # Shared utility: parses SKILL.md frontmatter
```

---

## Key Files

### `plugin.json`
Defines the plugin identity for the Claude plugin registry: name (`skill-creator`), description, and author (Anthropic).

### `skills/skill-creator/SKILL.md`
The core of the skill. Contains YAML frontmatter (`name`, `description`) and ~480 lines of markdown instructions covering the full workflow:
- Capturing user intent and drafting a skill
- Running with-skill and without-skill eval subagents in parallel
- Grading assertions, aggregating benchmarks, and launching the review viewer
- Iterating based on user feedback
- Optimizing the skill description via a separate eval/improve loop
- Platform-specific adaptations (Claude.ai, Cowork, headless environments)
- Packaging and distributing the final skill

### `scripts/run_eval.py`
Creates a temporary `.md` command file in the project's `.claude/commands/` directory, then spawns `claude -p` as a subprocess with `--output-format stream-json --include-partial-messages`. Detects skill triggering by watching for `Skill` or `Read` tool calls in the stream that reference the skill name. Uses `ProcessPoolExecutor` for parallelism.

### `scripts/run_loop.py`
Orchestrates the description optimization loop: splits the eval set into 60/40 train/test (stratified by `should_trigger`), runs evals, calls `improve_description.py` to propose a new description using Claude with extended thinking (`budget_tokens: 10000`), and repeats up to `--max-iterations` times. Best description is selected by held-out test score to avoid overfitting. Produces a live-refreshing HTML report.

### `scripts/improve_description.py`
Calls `anthropic.Anthropic().messages.create()` with extended thinking enabled. Constructs a detailed prompt including the current description, failed/false-trigger queries, and iteration history. Enforces a 1024-character hard cap on the output description (with a follow-up re-write call if exceeded). Logs all thinking and responses to `log_dir` if provided.

### `scripts/aggregate_benchmark.py`
Reads `grading.json` files from a structured workspace directory (supports both workspace and legacy layouts), computes mean/stddev/min/max for `pass_rate`, `time_seconds`, and `tokens` per configuration, and writes `benchmark.json` + `benchmark.md`.

### `scripts/package_skill.py`
Validates a skill directory (via `quick_validate.py`), then zips its contents (excluding `evals/`, `__pycache__`, `*.pyc`, `.DS_Store`) into a `.skill` file.

### `scripts/quick_validate.py`
Checks that `SKILL.md` exists, has valid YAML frontmatter with required `name` and `description` fields, enforces kebab-case naming, and enforces character limits (name: 64 chars, description: 1024 chars).

### `eval-viewer/generate_review.py`
A self-contained Python HTTP server (stdlib only) that serves a single-page HTML review UI. Discovers runs by scanning the workspace directory for `outputs/` subdirectories, embeds all text/image output files inline (base64 for images), and handles `feedback.json` POST requests for saving user annotations. Supports `--static` mode for headless/Cowork environments.

### Agent instruction files (`agents/`)
Markdown files that serve as system-level prompts for specialized subagents:
- **grader.md**: Reads transcripts and output files, evaluates each assertion (PASS/FAIL with evidence), extracts and verifies claims, critiques the evals themselves, and writes `grading.json`.
- **comparator.md**: Blind A/B comparison using a content+structure rubric (1-5 scale per criterion), produces `comparison.json` without knowing which skill produced which output.
- **analyzer.md**: Two modes — (1) post-hoc analysis of why the winning A/B skill won; (2) pattern analysis across benchmark runs surfacing non-discriminating assertions, high-variance evals, and resource tradeoffs.

---

## Dependencies

### Runtime (Python)
| Package | Usage |
|---|---|
| `anthropic` | Claude API calls in `improve_description.py` and `run_loop.py` |
| `yaml` (PyYAML) | Frontmatter parsing in `quick_validate.py` |
| Standard library | `subprocess`, `concurrent.futures`, `http.server`, `zipfile`, `argparse`, `json`, `pathlib`, `math`, `re`, `select`, `webbrowser`, `tempfile`, `uuid`, `time`, `random`, `signal`, `base64`, `mimetypes`, `html`, `os` |

### Runtime (CLI)
| Tool | Usage |
|---|---|
| `claude` (Claude Code CLI) | Invoked as a subprocess in `run_eval.py` and `run_loop.py` to test skill triggering |

### No dependency file is present (`requirements.txt`, `pyproject.toml`, etc.)

---

## Potential Issues

### Missing dependency specification
There is no `requirements.txt`, `pyproject.toml`, `setup.py`, or any other dependency manifest. Users must manually install the `anthropic` and `PyYAML` packages. This makes the scripts brittle to install without documentation.

### No automated tests
There are no unit tests, integration tests, or a test runner configuration (`pytest`, `unittest`, `tox`, etc.) for any of the Python scripts. The scripts themselves implement eval machinery for testing Claude skills, but the scripts themselves are untested.

### No CI/CD configuration
There is no CI configuration file (`.github/workflows/`, `Makefile`, etc.). There is also no `.git` directory, which is expected since this is a distributed plugin cache, not a development repository.

### `viewer.html` not directly read
The file `eval-viewer/viewer.html` is listed in the directory but `generate_review.py` generates its own HTML inline rather than reading this file. It is unclear whether `viewer.html` is a legacy artifact or still in use.

### `yaml` import without try/except in `quick_validate.py`
If PyYAML is not installed, `quick_validate.py` will fail at import time with an unhelpful `ModuleNotFoundError`. This import is not guarded.

### Hardcoded placeholder values in `aggregate_benchmark.py`
The generated `benchmark.json` `metadata` block contains placeholder strings `"<model-name>"` for `executor_model` and `analyzer_model`. These are not populated automatically; the user or the orchestrating agent must fill them in manually or accept inaccurate metadata.

### Fragile stream-event parsing in `run_eval.py`
Skill triggering detection relies on parsing `claude -p` streaming JSON events and matching the temporary command file name in partially-accumulated JSON fragments. This approach is sensitive to changes in the Claude CLI output format.

### No `evals/` directory included
The skill instructs users to save eval test cases to `evals/evals.json` inside the skill directory, but no `evals/` directory is present in this distribution. This is by design (the `package_skill.py` script excludes `evals/` from distribution), but it means eval files must be created fresh for each use.

### Plugin version not tracked
Neither `plugin.json` nor any other file declares a version number for this plugin. There is no changelog or version history visible in this cache snapshot.

---

## Summary

This is a well-structured, sophisticated Claude Code plugin that implements a complete skill development lifecycle — from drafting to evaluation to iterative improvement to packaging. The Python tooling is clean and modular. The main practical concerns are the absence of a dependency manifest, no automated tests for the scripts themselves, and a few minor robustness issues in the eval trigger detection and benchmark metadata generation.
