# Stack Detectors: Python

## Detection Heuristics

| File | What to extract |
|------|----------------|
| `pyproject.toml` | `[project]` name/version/dependencies, `[tool.poetry]`, `[tool.ruff]`, `[tool.mypy]` |
| `requirements.txt` | Direct dependency list |
| `requirements-dev.txt` / `requirements-test.txt` | Dev/test deps separate → good hygiene |
| `setup.py` / `setup.cfg` | Legacy packaging |
| `Pipfile` | Pipenv → environment management |
| `uv.lock` | uv → modern Python package manager |
| `.python-version` | Python version pinned |
| `pytest.ini` / `conftest.py` | pytest configuration |
| `mypy.ini` / `[tool.mypy]` | Type checking enforced |
| `ruff.toml` / `[tool.ruff]` | Ruff linting/formatting |
| `.pre-commit-config.yaml` | Pre-commit hooks |

**Framework detection:**
- `fastapi` → FastAPI (modern async API)
- `flask` → Flask (lightweight API)
- `django` → Django (full-stack)
- `anthropic` → Claude/Anthropic SDK
- `openai` → OpenAI SDK
- `pydantic` → Data validation
- `sqlalchemy` → ORM
- `celery` → Task queue
- `langchain` → LangChain (LLM orchestration)

---

## Wide Scan Grep Patterns

### Custom patterns

```bash
# Abstract base classes and protocols
grep -rn 'class.*ABC\|class.*Protocol\|class.*BaseModel\|@abstractmethod' --include='*.py' src/

# Class inheritance
grep -rn '^class.*(' --include='*.py' src/ | grep -v '():\|object):'  # non-trivial inheritance
```

### Anti-pattern signals

```bash
# God class candidates
find . -name '*.py' ! -path '*/.venv/*' ! -path '*/test*' \
  | xargs wc -l 2>/dev/null | sort -rn | head -20

# Broad exception catching
grep -rn 'except Exception\|except:\|bare except' --include='*.py' src/

# Type ignore
grep -rn '# type: ignore\|# noqa' --include='*.py' src/

# TODO/FIXME/HACK
grep -rc 'TODO\|FIXME\|HACK' --include='*.py' src/ | grep -v ':0$'
```

### Convention frequency

```bash
# Type hints presence
grep -rl 'def .*->.*:' --include='*.py' src/ | wc -l  # functions with return types
grep -rl 'def ' --include='*.py' src/ | wc -l  # total function files
```

### Security posture signals

```bash
# Django security framework
grep -rl 'django.contrib.auth\|@login_required\|@permission_required\|authenticate\|has_perm' \
  --include='*.py' src/

# Django middleware and custom auth
grep -rn 'AuthenticationMiddleware\|PermissionMiddleware\|class.*Middleware' --include='*.py' src/

# FastAPI security
grep -rl 'OAuth2PasswordBearer\|HTTPBearer\|Depends.*Security\|SecurityScopes\|@api_key_header' \
  --include='*.py' src/

# FastAPI auth dependencies
grep -rn 'def get_current_user\|def verify_token\|def check_permission' --include='*.py' src/

# Flask-Login and session management
grep -rl 'flask_login\|@login_required\|LoginManager\|current_user\|login_user' \
  --include='*.py' src/

# CORS configuration
grep -rl 'CORSMiddleware\|flask_cors\|CORS(\|@cross_origin\|add_cors_headers' \
  --include='*.py' src/

# Endpoint count vs auth-decorated endpoint count (coverage gap detection)
TOTAL_ROUTES=$(grep -rc '@app\.route\|@router\.get\|@router\.post\|@router\.put\|@router\.delete\|@router\.patch' \
  --include='*.py' src/ | awk -F: '{s+=$2}END{print s}')
AUTH_ROUTES=$(grep -rc '@login_required\|@permission_required\|Depends.*get_current_user\|Depends.*verify_token' \
  --include='*.py' src/ | awk -F: '{s+=$2}END{print s}')
# If AUTH_ROUTES < TOTAL_ROUTES: flag potential unprotected routes

# Secret management patterns
grep -rn 'os\.getenv\|os\.environ\|config\.get\|settings\.' --include='*.py' src/ \
  | grep -i 'secret\|password\|token\|key\|api' | head -10

# Password hashing
grep -rl 'pbkdf2\|bcrypt\|argon2\|make_password\|check_password' --include='*.py' src/

# SQL injection protection (parameterized queries)
grep -rn 'execute.*%s\|execute.*?\|session\.query\|select.*from' --include='*.py' src/ | head -10
```

### API surface signals

```bash
# Flask route tally by HTTP method
FLASK_GET=$(grep -rc '@app\.route.*methods.*GET\|@app\.get\|@bp\.get' --include='*.py' src/ | awk -F: '{s+=$2}END{print s}')
FLASK_POST=$(grep -rc '@app\.route.*methods.*POST\|@app\.post\|@bp\.post' --include='*.py' src/ | awk -F: '{s+=$2}END{print s}')
FLASK_PUT=$(grep -rc '@app\.route.*methods.*PUT\|@app\.put\|@bp\.put' --include='*.py' src/ | awk -F: '{s+=$2}END{print s}')
FLASK_DELETE=$(grep -rc '@app\.route.*methods.*DELETE\|@app\.delete\|@bp\.delete' --include='*.py' src/ | awk -F: '{s+=$2}END{print s}')
# Report: "Flask routes - GET:N POST:M PUT:P DELETE:Q"

# FastAPI route tally by HTTP method
FASTAPI_GET=$(grep -rc '@router\.get\|@app\.get' --include='*.py' src/ | awk -F: '{s+=$2}END{print s}')
FASTAPI_POST=$(grep -rc '@router\.post\|@app\.post' --include='*.py' src/ | awk -F: '{s+=$2}END{print s}')
FASTAPI_PUT=$(grep -rc '@router\.put\|@app\.put' --include='*.py' src/ | awk -F: '{s+=$2}END{print s}')
FASTAPI_DELETE=$(grep -rc '@router\.delete\|@app\.delete' --include='*.py' src/ | awk -F: '{s+=$2}END{print s}')
FASTAPI_PATCH=$(grep -rc '@router\.patch\|@app\.patch' --include='*.py' src/ | awk -F: '{s+=$2}END{print s}')
# Report: "FastAPI routes - GET:N POST:M PUT:P DELETE:Q PATCH:R"

# Django URL patterns
grep -rn 'path(\|re_path(\|url(' --include='*.py' --include='urls.py' src/ | wc -l

# API versioning (URL-based)
grep -rn '@app\.route.*v[0-9]\|@router\..*prefix.*v[0-9]\|path.*v[0-9]' \
  --include='*.py' src/ | grep -oP '/v\d+/' | sort -u
# If versions found: report "URL-based versioning: v1, v2..." else "No versioning detected"

# OpenAPI / Swagger documentation tooling
grep -rl 'from fastapi import.*OpenAPI\|swagger_ui\|redoc\|@api_view\|drf_yasg' \
  --include='*.py' src/

# API routers and blueprints (modularization signal)
grep -rl 'APIRouter\|Blueprint\|Router(' --include='*.py' src/ | wc -l

# GraphQL endpoints
grep -rl 'graphene\|strawberry\|ariadne\|@strawberry\.type\|GraphQLView' --include='*.py' src/

# WebSocket endpoints
grep -rn '@app\.websocket\|@router\.websocket\|async def.*websocket' --include='*.py' src/
```

### Observability signals

```bash
# Structured logging - structlog
grep -rl 'import structlog\|structlog\.get_logger\|structlog\.configure' --include='*.py' src/
grep -rn 'structlog\.processors\|JSONRenderer\|KeyValueRenderer' --include='*.py' src/ | wc -l

# Python stdlib logging setup
grep -rn 'logging\.getLogger\|logging\.config\|dictConfig\|fileConfig' --include='*.py' src/ | wc -l

# OpenTelemetry tracing
grep -rl 'opentelemetry\|from opentelemetry import\|TracerProvider\|@tracer\.start_as_current_span' \
  --include='*.py' src/
grep -rn 'trace\.get_tracer\|SpanProcessor\|instrument_app' --include='*.py' src/ | wc -l

# Prometheus metrics
grep -rl 'prometheus_client\|from prometheus_client import\|Counter\|Gauge\|Histogram\|Summary' \
  --include='*.py' src/
grep -rn '@Gauge\|@Counter\|\.inc(\|\.set(\|\.observe(' --include='*.py' src/ | wc -l

# Sentry error tracking
grep -rl 'import sentry_sdk\|sentry_sdk\.init\|@sentry_sdk\.capture' --include='*.py' src/
grep -rn 'capture_exception\|capture_message\|set_context\|set_tag' --include='*.py' src/ | wc -l

# Django Debug Toolbar
grep -r 'debug_toolbar\|DEBUG_TOOLBAR' --include='*.py' --include='settings.py' src/

# Custom metrics and monitoring
grep -rn 'class.*Metric\|def track_\|def record_\|def measure_' --include='*.py' src/ | head -10

# Health check endpoints
grep -rn '@app\.route.*health\|@router\.get.*health\|path.*health\|def health_check' \
  --include='*.py' src/

# APM integrations (New Relic, DataDog, Elastic)
grep -rl 'newrelic\|ddtrace\|elasticapm\|import newrelic\|import ddtrace' --include='*.py' src/
```

### Dependency deep-scan signals

```bash
# requirements.txt version pinning analysis
if [ -f requirements.txt ]; then
  TOTAL_DEPS=$(grep -v '^#\|^$\|^-' requirements.txt | wc -l)
  PINNED_DEPS=$(grep -E '==|~=|===|\^' requirements.txt | wc -l)
  # Report: "requirements.txt: N/M deps pinned (X% coverage)"
fi

# Poetry lockfile presence
if [ -f poetry.lock ]; then
  echo "poetry.lock present - full dependency graph locked"
  # Check if poetry.lock is in sync with pyproject.toml
  grep -A5 '\[tool\.poetry\.dependencies\]' pyproject.toml 2>/dev/null | head -10
fi

# uv lockfile presence
if [ -f uv.lock ]; then
  echo "uv.lock present - modern Python package manager in use"
fi

# Pipenv Pipfile.lock
if [ -f Pipfile.lock ]; then
  echo "Pipfile.lock present - Pipenv dependency locking"
fi

# Security scanning tools in CI/CD
grep -r 'pip-audit\|safety check\|bandit\|semgrep\|snyk' \
  .github/workflows/*.yml .gitlab-ci.yml azure-pipelines.yml Makefile 2>/dev/null

# pip-audit in pre-commit
grep -r 'pip-audit\|safety' .pre-commit-config.yaml 2>/dev/null

# Dependency confusion protection (private index)
grep -rn 'index-url\|extra-index-url\|trusted-host' requirements.txt pip.conf setup.py pyproject.toml 2>/dev/null

# Outdated dependency check tooling
grep -r 'pip list --outdated\|poetry show --outdated\|pipenv update --outdated' \
  Makefile .github/workflows/*.yml 2>/dev/null

# SBOM generation
grep -r 'cyclonedx\|sbom\|pip-licenses\|pipdeptree' \
  .github/workflows/*.yml azure-pipelines.yml Makefile pyproject.toml 2>/dev/null

# Dependency version conflicts (multi-requirements files)
if [ -f requirements.txt ] && [ -f requirements-dev.txt ]; then
  # Extract common packages and compare versions
  grep -oP '^[a-zA-Z0-9_-]+' requirements.txt > /tmp/req-main.txt 2>/dev/null
  grep -oP '^[a-zA-Z0-9_-]+' requirements-dev.txt > /tmp/req-dev.txt 2>/dev/null
  comm -12 <(sort /tmp/req-main.txt) <(sort /tmp/req-dev.txt) | head -5
  # If common deps found: flag potential version conflicts
fi

# Transitive dependency analysis (check for deep trees)
grep -r 'pipdeptree\|pip-tree\|johnnydep' Makefile .github/workflows/*.yml 2>/dev/null
```

---

## Notes

All grep patterns exclude virtual environments (`.venv/`, `venv/`, `env/`), build output (`dist/`, `build/`, `__pycache__/`), and test fixtures by default. Adjust `src/` path to match actual project structure (`app/`, root-level `.py` files, etc.).

For Django projects, also check:
- `settings.py` for `INSTALLED_APPS`, `MIDDLEWARE`, `DATABASES`, `CACHES`, `LOGGING`
- `urls.py` for URL routing patterns
- `admin.py` for Django admin customizations

For FastAPI projects, also check:
- `main.py` or `app.py` for app instantiation and router includes
- `dependencies.py` or `deps.py` for shared dependency injection functions
- `schemas.py` or `models.py` for Pydantic models vs ORM models

For multi-module Python projects (monorepos):
- Look for `pyproject.toml` at multiple levels
- Check for shared library in `libs/`, `shared/`, or `common/`
- Detect namespace packages (`__init__.py` patterns)
