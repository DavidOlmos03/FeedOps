#!/usr/bin/env bats
# Validation tests for n8n workflow JSON files

# Load test helpers
load '../lib/bats-support/load'
load '../lib/bats-assert/load'
load '../lib/bats-file/load'

setup() {
    # Load test environment
    export TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export WORKFLOWS_DIR="${TEST_DIR}/workflows"
}

@test "validation: workflows directory exists" {
    assert_dir_exist "$WORKFLOWS_DIR"
}

@test "validation: 01-github-monitor.json exists" {
    assert_file_exist "${WORKFLOWS_DIR}/01-github-monitor.json"
}

@test "validation: 02-reddit-monitor.json exists" {
    assert_file_exist "${WORKFLOWS_DIR}/02-reddit-monitor.json"
}

@test "validation: 03-rss-monitor.json exists" {
    assert_file_exist "${WORKFLOWS_DIR}/03-rss-monitor.json"
}

@test "validation: 04-telegram-dispatcher.json exists" {
    assert_file_exist "${WORKFLOWS_DIR}/04-telegram-dispatcher.json"
}

@test "validation: 05-github-api-monitor.json exists" {
    assert_file_exist "${WORKFLOWS_DIR}/05-github-api-monitor.json"
}

@test "validation: 01-github-monitor.json is valid JSON" {
    run jq empty "${WORKFLOWS_DIR}/01-github-monitor.json"
    assert_success
}

@test "validation: 02-reddit-monitor.json is valid JSON" {
    run jq empty "${WORKFLOWS_DIR}/02-reddit-monitor.json"
    assert_success
}

@test "validation: 03-rss-monitor.json is valid JSON" {
    run jq empty "${WORKFLOWS_DIR}/03-rss-monitor.json"
    assert_success
}

@test "validation: 04-telegram-dispatcher.json is valid JSON" {
    run jq empty "${WORKFLOWS_DIR}/04-telegram-dispatcher.json"
    assert_success
}

@test "validation: 05-github-api-monitor.json is valid JSON" {
    run jq empty "${WORKFLOWS_DIR}/05-github-api-monitor.json"
    assert_success
}

@test "validation: github-monitor has required name field" {
    run jq -r '.name' "${WORKFLOWS_DIR}/01-github-monitor.json"
    assert_success
    [ -n "$output" ]
}

@test "validation: github-monitor has nodes array" {
    run jq -r '.nodes' "${WORKFLOWS_DIR}/01-github-monitor.json"
    assert_success
    [ "$output" != "null" ]
}

@test "validation: github-monitor has connections object" {
    run jq -r '.connections' "${WORKFLOWS_DIR}/01-github-monitor.json"
    assert_success
    [ "$output" != "null" ]
}

@test "validation: reddit-monitor has required name field" {
    run jq -r '.name' "${WORKFLOWS_DIR}/02-reddit-monitor.json"
    assert_success
    [ -n "$output" ]
}

@test "validation: reddit-monitor has nodes array" {
    run jq -r '.nodes' "${WORKFLOWS_DIR}/02-reddit-monitor.json"
    assert_success
    [ "$output" != "null" ]
}

@test "validation: rss-monitor has required name field" {
    run jq -r '.name' "${WORKFLOWS_DIR}/03-rss-monitor.json"
    assert_success
    [ -n "$output" ]
}

@test "validation: rss-monitor has nodes array" {
    run jq -r '.nodes' "${WORKFLOWS_DIR}/03-rss-monitor.json"
    assert_success
    [ "$output" != "null" ]
}

@test "validation: telegram-dispatcher has required name field" {
    run jq -r '.name' "${WORKFLOWS_DIR}/04-telegram-dispatcher.json"
    assert_success
    [ -n "$output" ]
}

@test "validation: telegram-dispatcher has nodes array" {
    run jq -r '.nodes' "${WORKFLOWS_DIR}/04-telegram-dispatcher.json"
    assert_success
    [ "$output" != "null" ]
}

@test "validation: github-api-monitor has required name field" {
    run jq -r '.name' "${WORKFLOWS_DIR}/05-github-api-monitor.json"
    assert_success
    [ -n "$output" ]
}

@test "validation: github-api-monitor has nodes array" {
    run jq -r '.nodes' "${WORKFLOWS_DIR}/05-github-api-monitor.json"
    assert_success
    [ "$output" != "null" ]
}

@test "validation: all workflows have at least one node" {
    for workflow in "${WORKFLOWS_DIR}"/*.json; do
        [ "$(basename "$workflow")" = "README.md" ] && continue

        run jq -r '.nodes | length' "$workflow"
        assert_success
        [ "$output" -gt 0 ]
    done
}

@test "validation: github-monitor nodes have required type field" {
    run jq -r '.nodes[0].type' "${WORKFLOWS_DIR}/01-github-monitor.json"
    assert_success
    [ -n "$output" ]
    [ "$output" != "null" ]
}

@test "validation: github-monitor nodes have required name field" {
    run jq -r '.nodes[0].name' "${WORKFLOWS_DIR}/01-github-monitor.json"
    assert_success
    [ -n "$output" ]
    [ "$output" != "null" ]
}

@test "validation: github-monitor nodes have position coordinates" {
    run jq -r '.nodes[0].position' "${WORKFLOWS_DIR}/01-github-monitor.json"
    assert_success
    [ "$output" != "null" ]
}

@test "validation: workflows have active/inactive status" {
    for workflow in "${WORKFLOWS_DIR}"/*.json; do
        [ "$(basename "$workflow")" = "README.md" ] && continue

        run jq -r 'has("active")' "$workflow"
        assert_success
        echo "$output" | grep -q "true"
    done
}

@test "validation: telegram-dispatcher has webhook or trigger node" {
    run jq -r '.nodes[] | select(.type | contains("Webhook") or contains("webhook") or contains("trigger")) | .type' "${WORKFLOWS_DIR}/04-telegram-dispatcher.json"
    assert_success
}

@test "validation: no duplicate node names in github-monitor" {
    # Get all node names and check for duplicates
    run sh -c "jq -r '.nodes[].name' '${WORKFLOWS_DIR}/01-github-monitor.json' | sort | uniq -d"
    assert_success
    [ -z "$output" ]
}

@test "validation: no duplicate node names in reddit-monitor" {
    run sh -c "jq -r '.nodes[].name' '${WORKFLOWS_DIR}/02-reddit-monitor.json' | sort | uniq -d"
    assert_success
    [ -z "$output" ]
}

@test "validation: workflows have settings object" {
    for workflow in "${WORKFLOWS_DIR}"/*.json; do
        [ "$(basename "$workflow")" = "README.md" ] && continue

        run jq -r 'has("settings")' "$workflow"
        assert_success
    done
}

@test "validation: all JSON files are properly formatted" {
    for workflow in "${WORKFLOWS_DIR}"/*.json; do
        # Check if file can be parsed and reformatted
        run jq -c . "$workflow"
        assert_success
    done
}
