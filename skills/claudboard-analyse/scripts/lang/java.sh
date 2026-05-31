#!/usr/bin/env bash
# java.sh — Java/Kotlin wide-scan greps for discover.sh.
# Sourced by discover.sh. Defines run_java_scan(repo, outfile).

run_java_scan() {
  local repo="$1"
  local outfile="$2"

  # ── Skill trigger counts ─────────────────────────────────────────────────
  local t_rest_controller t_controller t_feign_client t_kafka_listener
  local t_rabbit_listener t_repository t_scheduled t_async t_event_listener
  local t_aspect t_message_mapping t_graphql t_shell_component t_validator
  local t_security_filter

  _java_count() { grep -rc "$1" --include='*.java' --include='*.kt' "${repo}/src" 2>/dev/null | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}'; }

  t_rest_controller=$(_java_count '@RestController')
  t_controller=$(_java_count '@Controller')
  t_feign_client=$(_java_count '@FeignClient')
  t_kafka_listener=$(_java_count '@KafkaListener\|@KafkaHandler')
  t_rabbit_listener=$(_java_count '@RabbitListener')
  t_repository=$(_java_count '@Repository')
  t_scheduled=$(_java_count '@Scheduled\|@EnableScheduling')
  t_async=$(_java_count '@Async\|@EnableAsync\|CompletableFuture')
  t_event_listener=$(_java_count '@EventListener\|ApplicationEvent')
  t_aspect=$(_java_count '@Aspect\|@Around\|@Before\|@After')
  t_message_mapping=$(_java_count '@MessageMapping')
  t_graphql=$(_java_count '@GraphQlController\|@QueryMapping\|@MutationMapping')
  t_shell_component=$(_java_count '@ShellComponent')
  t_validator=$(_java_count 'implements Validator\|ConstraintValidator')
  t_security_filter=$(_java_count 'SecurityFilterChain\|@EnableMethodSecurity')

  # Best example: smallest file containing the trigger (first match by wc -l)
  _java_best_example() {
    local pattern="$1"
    local dir="${repo}/src"
    local found
    found=$(grep -rl "$pattern" --include='*.java' --include='*.kt' "$dir" 2>/dev/null | head -20)
    if [ -z "$found" ]; then echo ""; return; fi
    echo "$found" | while read -r f; do
      wc -l < "$f" | tr -d ' '
      echo " $f"
    done | sort -n | head -1 | awk '{print $2}' | sed "s|$repo/||"
  }

  local be_rest be_kafka be_feign be_aspect
  be_rest=$(_java_best_example '@RestController')
  be_kafka=$(_java_best_example '@KafkaListener')
  be_feign=$(_java_best_example '@FeignClient')
  be_aspect=$(_java_best_example '@Aspect')

  # ── Anti-patterns ────────────────────────────────────────────────────────
  local ap_field_inj ap_broad_ex ap_null_ret ap_reflection ap_todo
  local ap_date_util ap_console ap_star_imports

  ap_field_inj=$(grep -rc '@Autowired' --include='*.java' --include='*.kt' "${repo}/src/main" 2>/dev/null | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}')
  ap_broad_ex=$(grep -rc 'catch (Exception\|catch (Throwable' --include='*.java' "${repo}/src/main" 2>/dev/null | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}')
  ap_null_ret=$(grep -rc 'return null;' --include='*.java' "${repo}/src/main" 2>/dev/null | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}')
  ap_reflection=$(grep -rc 'ReflectionUtils\|getDeclaredField\|setAccessible\|Method\.invoke\|ParameterizedType' --include='*.java' "${repo}/src/main" 2>/dev/null | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}')
  ap_todo=$(grep -rc 'TODO\|FIXME\|HACK' --include='*.java' --include='*.kt' "${repo}/src" 2>/dev/null | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}')
  ap_date_util=$(grep -rc 'import java\.util\.Date' --include='*.java' "${repo}/src/main" 2>/dev/null | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}')
  ap_console=$(grep -rc 'System\.out\.print\|System\.err\.print' --include='*.java' "${repo}/src/main" 2>/dev/null | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}')
  ap_star_imports=$(grep -rc 'import .*\.\*;' --include='*.java' "${repo}/src/main" 2>/dev/null | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}')

  # ── Conventions ──────────────────────────────────────────────────────────
  local field_inj const_inj di_style slf4j_annot slf4j_factory logging_style

  field_inj="${ap_field_inj:-0}"
  const_inj=$(grep -rc 'private final' --include='*.java' "${repo}/src/main" 2>/dev/null | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}')
  if [ "${field_inj:-0}" -gt "${const_inj:-0}" ] 2>/dev/null; then
    di_style="field"
  elif [ "${const_inj:-0}" -gt 0 ] 2>/dev/null; then
    di_style="constructor"
  else
    di_style="unknown"
  fi

  slf4j_annot=$(grep -rl '@Slf4j' --include='*.java' "${repo}/src" 2>/dev/null | wc -l | tr -d ' ')
  slf4j_factory=$(grep -rl 'LoggerFactory.getLogger' --include='*.java' "${repo}/src" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${slf4j_annot:-0}" -gt "${slf4j_factory:-0}" ] 2>/dev/null; then
    logging_style="slf4j-annotation"
  elif [ "${slf4j_factory:-0}" -gt 0 ] 2>/dev/null; then
    logging_style="slf4j-factory"
  elif [ "${slf4j_annot:-0}" -gt 0 ] 2>/dev/null; then
    logging_style="mixed"
  else
    logging_style="unknown"
  fi

  # ── God class candidates ─────────────────────────────────────────────────
  local god_classes_json
  god_classes_json=$(
    find "$repo" -name '*.java' -path '*/src/main/*' ! -path '*/test/*' 2>/dev/null \
    | xargs wc -l 2>/dev/null \
    | grep -v ' total$' \
    | awk '{print $1, $2}' \
    | sort -rn \
    | awk -v repo="$repo" '$1 > 300 {print "{\"file\":\"" $2 "\",\"loc\":" $1 "}"}' \
    | sed "s|\"$repo/|\"| " \
    | head -10 \
    | jq -sc . 2>/dev/null || echo '[]'
  )

  # ── Inheritance map ──────────────────────────────────────────────────────
  local inheritance_map_json
  inheritance_map_json=$(
    grep -rh '^[[:space:]]*public abstract class\|^[[:space:]]*abstract class' \
      --include='*.java' "${repo}/src" 2>/dev/null \
    | grep -oE '[A-Za-z][A-Za-z0-9_]*(<[^>]*>)?' \
    | grep -v 'abstract\|class\|public\|protected\|final' \
    | sort -u \
    | head -20 \
    | while read -r base; do
        count=$(grep -rl "extends $base" --include='*.java' "${repo}/src" 2>/dev/null | wc -l | tr -d ' ')
        sample=$(grep -rl "extends $base" --include='*.java' "${repo}/src" 2>/dev/null | head -1 | sed "s|$repo/||")
        if [ "${count:-0}" -ge 2 ] 2>/dev/null; then
          printf '{"base":"%s","subclasses":%s,"sample_file":"%s"}\n' "$base" "$count" "$sample"
        fi
      done \
    | jq -sc . 2>/dev/null || echo '[]'
  )

  # ── Output JSON ──────────────────────────────────────────────────────────
  jq -n \
    --argjson t_rest "${t_rest_controller:-0}" \
    --argjson t_ctrl "${t_controller:-0}" \
    --argjson t_feign "${t_feign_client:-0}" \
    --argjson t_kafka "${t_kafka_listener:-0}" \
    --argjson t_rabbit "${t_rabbit_listener:-0}" \
    --argjson t_repo "${t_repository:-0}" \
    --argjson t_sched "${t_scheduled:-0}" \
    --argjson t_async "${t_async:-0}" \
    --argjson t_event "${t_event_listener:-0}" \
    --argjson t_aspect "${t_aspect:-0}" \
    --argjson t_ws "${t_message_mapping:-0}" \
    --argjson t_gql "${t_graphql:-0}" \
    --argjson t_shell "${t_shell_component:-0}" \
    --argjson t_valid "${t_validator:-0}" \
    --argjson t_sec "${t_security_filter:-0}" \
    --arg be_rest "${be_rest:-}" \
    --arg be_kafka "${be_kafka:-}" \
    --arg be_feign "${be_feign:-}" \
    --arg be_aspect "${be_aspect:-}" \
    --argjson ap_fi "${ap_field_inj:-0}" \
    --argjson ap_be "${ap_broad_ex:-0}" \
    --argjson ap_nr "${ap_null_ret:-0}" \
    --argjson ap_rf "${ap_reflection:-0}" \
    --argjson ap_td "${ap_todo:-0}" \
    --argjson ap_du "${ap_date_util:-0}" \
    --argjson ap_con "${ap_console:-0}" \
    --argjson ap_si "${ap_star_imports:-0}" \
    --arg di_style "${di_style:-unknown}" \
    --arg log_style "${logging_style:-unknown}" \
    --argjson god_classes "${god_classes_json:-[]}" \
    --argjson inheritance_map "${inheritance_map_json:-[]}" \
    '{
      skill_triggers: {
        "@RestController":     {count: $t_rest,   best_example: $be_rest},
        "@Controller":         {count: $t_ctrl,   best_example: ""},
        "@FeignClient":        {count: $t_feign,  best_example: $be_feign},
        "@KafkaListener":      {count: $t_kafka,  best_example: $be_kafka},
        "@RabbitListener":     {count: $t_rabbit, best_example: ""},
        "@Repository":         {count: $t_repo,   best_example: ""},
        "@Scheduled":          {count: $t_sched,  best_example: ""},
        "@Async":              {count: $t_async,  best_example: ""},
        "@EventListener":      {count: $t_event,  best_example: ""},
        "@Aspect":             {count: $t_aspect, best_example: $be_aspect},
        "@MessageMapping":     {count: $t_ws,     best_example: ""},
        "@GraphQlController":  {count: $t_gql,    best_example: ""},
        "@ShellComponent":     {count: $t_shell,  best_example: ""},
        "ConstraintValidator": {count: $t_valid,  best_example: ""},
        "SecurityFilterChain": {count: $t_sec,    best_example: ""}
      },
      anti_patterns: {
        field_injection:        $ap_fi,
        broad_exception_catch:  $ap_be,
        null_returns:           $ap_nr,
        reflection:             $ap_rf,
        todo_fixme:             $ap_td,
        legacy_date:            $ap_du,
        console_print:          $ap_con,
        star_imports:           $ap_si
      },
      conventions: {
        java_di_style:  $di_style,
        java_logging:   $log_style
      },
      god_class_candidates: $god_classes,
      inheritance_map:      $inheritance_map
    }' > "$outfile"
}
