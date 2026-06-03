#!/usr/bin/env bash
# _common.sh — Shared detection helpers for discover.sh.
# Sourced (not executed directly). All functions take REPO_PATH as $1.

# Dirs to always exclude from scans.
_EXCL='! -path */node_modules/* ! -path */.venv/* ! -path */vendor/* ! -path */.gradle/* ! -path */target/* ! -path */dist/* ! -path */build/* ! -path */out/* ! -path */__pycache__/*'

# Count source files (all languages), excluding generated dirs.
count_source_files() {
  local repo="$1"
  find "$repo" -type f \
    \( -name '*.java' -o -name '*.kt' -o -name '*.kts' \
       -o -name '*.ts' -o -name '*.tsx' \
       -o -name '*.js' -o -name '*.mjs' \
       -o -name '*.py' \
       -o -name '*.go' \
       -o -name '*.rs' \
       -o -name '*.cs' \) \
    ! -path '*/node_modules/*' \
    ! -path '*/.venv/*' \
    ! -path '*/vendor/*' \
    ! -path '*/.gradle/*' \
    ! -path '*/target/*' \
    ! -path '*/dist/*' \
    ! -path '*/build/*' \
    ! -path '*/out/*' \
    ! -path '*/__pycache__/*' \
    2>/dev/null \
  | wc -l | tr -d ' '
}

# Detect languages from build file presence. Outputs a JSON array string.
detect_languages() {
  local repo="$1"
  local langs=()

  # Java / Kotlin
  if find "$repo" -maxdepth 4 \
       \( -name 'pom.xml' -o -name 'build.gradle' -o -name 'build.gradle.kts' \) \
       ! -path '*/.gradle/*' ! -path '*/target/*' 2>/dev/null | grep -q .; then
    langs+=("java")
  fi

  # TypeScript / JavaScript
  if find "$repo" -maxdepth 4 -name 'package.json' \
       ! -path '*/node_modules/*' 2>/dev/null | grep -q .; then
    langs+=("typescript")
  fi

  # Python
  if find "$repo" -maxdepth 4 \
       \( -name 'pyproject.toml' -o -name 'requirements.txt' -o -name 'setup.py' \) \
       ! -path '*/.venv/*' 2>/dev/null | grep -q .; then
    langs+=("python")
  fi

  # Go
  if find "$repo" -maxdepth 4 -name 'go.mod' 2>/dev/null | grep -q .; then
    langs+=("go")
  fi

  # Rust
  if find "$repo" -maxdepth 4 -name 'Cargo.toml' \
       ! -path '*/target/*' 2>/dev/null | grep -q .; then
    langs+=("rust")
  fi

  # .NET / C#
  if find "$repo" -maxdepth 4 \
       \( -name '*.csproj' -o -name '*.sln' \) 2>/dev/null | grep -q .; then
    langs+=("dotnet")
  fi

  if [ ${#langs[@]} -eq 0 ]; then
    echo '[]'
  else
    printf '%s\n' "${langs[@]}" | jq -R . | jq -sc .
  fi
}

# Detect build files by category. Outputs a JSON object string.
detect_build_files() {
  local repo="$1"
  local java_files ts_files py_files go_files rs_files dotnet_files common_files

  java_files=$(find "$repo" -maxdepth 4 \
    \( -name 'pom.xml' -o -name 'build.gradle' -o -name 'build.gradle.kts' \
       -o -name 'settings.gradle' -o -name 'settings.gradle.kts' \) \
    ! -path '*/.gradle/*' ! -path '*/target/*' 2>/dev/null \
    | sed "s|$repo/||" | sort | jq -R . | jq -sc . 2>/dev/null || echo '[]')

  ts_files=$(find "$repo" -maxdepth 4 \
    \( -name 'package.json' -o -name 'tsconfig.json' \
       -o -name 'jest.config.*' -o -name 'vite.config.*' -o -name 'next.config.*' \) \
    ! -path '*/node_modules/*' 2>/dev/null \
    | sed "s|$repo/||" | sort | jq -R . | jq -sc . 2>/dev/null || echo '[]')

  py_files=$(find "$repo" -maxdepth 4 \
    \( -name 'pyproject.toml' -o -name 'requirements.txt' -o -name 'setup.py' \
       -o -name 'Pipfile' -o -name 'pytest.ini' -o -name 'conftest.py' \) \
    ! -path '*/.venv/*' 2>/dev/null \
    | sed "s|$repo/||" | sort | jq -R . | jq -sc . 2>/dev/null || echo '[]')

  go_files=$(find "$repo" -maxdepth 4 \
    \( -name 'go.mod' -o -name 'go.sum' -o -name 'Makefile' \) 2>/dev/null \
    | sed "s|$repo/||" | sort | jq -R . | jq -sc . 2>/dev/null || echo '[]')

  rs_files=$(find "$repo" -maxdepth 4 \
    \( -name 'Cargo.toml' -o -name 'Cargo.lock' \) \
    ! -path '*/target/*' 2>/dev/null \
    | sed "s|$repo/||" | sort | jq -R . | jq -sc . 2>/dev/null || echo '[]')

  dotnet_files=$(find "$repo" -maxdepth 4 \
    \( -name '*.csproj' -o -name '*.sln' -o -name 'global.json' \) 2>/dev/null \
    | sed "s|$repo/||" | sort | jq -R . | jq -sc . 2>/dev/null || echo '[]')

  common_files=$(
    {
      find "$repo" -maxdepth 4 \
        \( -name 'Dockerfile' -o -name 'docker-compose.yml' \
           -o -name 'azure-pipelines.yml' -o -name 'Jenkinsfile' \
           -o -name '.gitlab-ci.yml' -o -name 'CLAUDE.md' \
           -o -name '.mcp.json' -o -name 'Pulumi.yaml' \
           -o -name 'kustomization.yaml' \) 2>/dev/null
      find "$repo/.github/workflows" -name '*.yml' 2>/dev/null
      true  # ensure brace group exits 0 even if .github/workflows doesn't exist
    } | sed "s|$repo/||" | sort -u | jq -R . | jq -sc .
  )
  common_files="${common_files:-[]}"

  jq -n \
    --argjson java       "$java_files" \
    --argjson typescript "$ts_files" \
    --argjson python     "$py_files" \
    --argjson go         "$go_files" \
    --argjson rust       "$rs_files" \
    --argjson dotnet     "$dotnet_files" \
    --argjson common     "$common_files" \
    '{java:$java, typescript:$typescript, python:$python, go:$go, rust:$rust, dotnet:$dotnet, common:$common}'
}

# Compute ref_load_signals booleans. Each outputs literal "true" or "false".
compute_messaging_signal() {
  local repo="$1"
  if grep -rqiE 'kafka|rabbitmq|amqp|activemq|solace|@SqsListener|jms\.send|JmsTemplate|spring\.cloud\.stream' \
       --include='*.java' --include='*.kt' --include='*.ts' --include='*.py' \
       --include='*.go' --include='*.rs' --include='*.cs' \
       --include='*.yml' --include='*.yaml' --include='*.properties' \
       "$repo" 2>/dev/null; then
    echo 'true'
  else
    echo 'false'
  fi
}

compute_streaming_signal() {
  local repo="$1"
  if grep -rqiE 'WebSocket|SseEmitter|ServerSentEvent|@MessageMapping|rsocket|server-sent' \
       --include='*.java' --include='*.kt' --include='*.ts' --include='*.py' \
       --include='*.go' --include='*.rs' --include='*.cs' \
       "$repo" 2>/dev/null; then
    echo 'true'
  else
    echo 'false'
  fi
}

compute_graphql_signal() {
  local repo="$1"
  if grep -rqiE 'graphql|@GraphQlController|@QueryMapping|@Resolver|GraphQLModule|type-graphql|apollo' \
       --include='*.java' --include='*.kt' --include='*.ts' --include='*.py' \
       --include='*.go' --include='*.rs' --include='*.cs' \
       --include='*.graphql' --include='*.gql' \
       "$repo" 2>/dev/null; then
    echo 'true'
  else
    echo 'false'
  fi
}

compute_architectural_signal() {
  local repo="$1"
  if grep -rqiE 'saga|cqrs|outbox|EventStore|CommandHandler|QueryHandler|@Aggregate|@SagaOrchestrator|event.sourcing' \
       --include='*.java' --include='*.kt' --include='*.ts' --include='*.py' \
       --include='*.go' --include='*.rs' --include='*.cs' \
       "$repo" 2>/dev/null; then
    echo 'true'
  else
    echo 'false'
  fi
}
