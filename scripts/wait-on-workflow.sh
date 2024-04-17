#!/bin/bash

# Set the maximum waiting time (in minutes) and initialize the counter
max_wait="${MAX_WAIT}"
timeout="${TIMEOUT}"
interval="${INTERVAL}"
counter=0

# Check if WORKFLOW is a run ID or a workflow name
if [[ ! "$WORKFLOW" =~ \.ya?ml$ ]]; then
  run_id="${WORKFLOW}" # Run ID of the target workflow
else
  workflow_name="${WORKFLOW}" # Name of the target workflow
fi

# If run_id is not provided get we will need the head commit SHA
if [ -z "$run_id" ]; then
  # Check if SHA is valid
  if [[ ! "$SHA" =~ ^[0-9a-f]{40}$ ]]; then
    echo "❌ Invalid commit SHA provided. Exiting."
    exit 1
  fi
fi

if [ "$VERBOSE" == "true" ]; then
  echo "ℹ️ Inputs:"
  echo "ℹ️   Repository: ${REPOSITORY}"
  if [ -n "$run_id" ]; then
    echo "ℹ️   Workflow run ID: ${run_id}"
  else
    echo "ℹ️   Workflow file name: ${workflow_name}"
    echo "ℹ️   Commit SHA: ${SHA}"
  fi
  echo "ℹ️   Maximum wait time: ${max_wait} minutes"
  echo "ℹ️   Timeout for the workflow to complete: ${timeout} minutes"
  echo "ℹ️   Interval between checks: ${interval} seconds"
  echo "ℹ️   Verbose: ${VERBOSE}"
fi

# Check if run_id is provided. If not, get the run ID of the target workflow
if [ -z "$run_id" ]; then
  # Wait on the workflow to be triggered
  while true; do
    if [ "$VERBOSE" == "true" ] || [ $counter -eq 0 ]; then
      echo "⏳ Waiting on the workflow to be triggered..."
    fi

    response=$(curl -s -H "Accept: application/vnd.github+json" -H "Authorization: token $GITHUB_TOKEN" \
      "https://api.github.com/repos/${REPOSITORY}/actions/workflows/${workflow_name}/runs")
    if echo "$response" | grep -q "API rate limit exceeded"; then
      echo "❌ API rate limit exceeded. Please try again later."
      exit 1
    elif echo "$response" | grep -q "Not Found"; then
      echo "❌ Invalid input provided (repository or workflow ID). Please check your inputs."
      exit 1
    fi

    run_id=$(echo "$response" | \
      jq -r --arg sha "$SHA" '[.workflow_runs | sort_by(.created_at)[] | select(.head_sha == $sha)] | last | .id')
    if [ -n "$run_id" ] && [ $run_id != "null" ]; then
      echo "🎉 Workflow triggered! Run ID: $run_id"
      break
    fi

    # Increment the counter and check if the maximum waiting time is reached
    counter=$((counter + 1))
    if [ $((counter * interval)) -ge $((max_wait * 60)) ]; then
      echo "❌ Maximum waiting time for the workflow to be triggered has been reached. Exiting."
      exit 1
    fi

    sleep $interval
  done
fi

echo "run-id=${run_id}" >> $GITHUB_OUTPUT

# Wait on the triggered workflow to complete and check its conclusion
timeout_counter=0
while true; do
  if [ "$VERBOSE" == "true" ] || [ $timeout_counter -eq 0 ]; then
    echo "⌛ Waiting on the workflow to complete..."
  fi

  run_data=$(curl -s -H "Accept: application/vnd.github+json" -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/${REPOSITORY}/actions/runs/$run_id")
  if echo "$run_data" | grep -q "API rate limit exceeded"; then
    echo "❌ API rate limit exceeded. Please try again later."
    exit 1
  elif echo "$run_data" | grep -q "Not Found"; then
    echo "❌ Invalid input provided (repository or run ID). Please check your inputs."
    exit 1
  fi

  status=$(echo "$run_data" | jq -r '.status')

  if [ "$status" = "completed" ]; then
    conclusion=$(echo "$run_data" | jq -r '.conclusion')
    echo "conclusion=${conclusion}" >> $GITHUB_OUTPUT
    echo "✅ The workflow has been completed with result: $conclusion"
    break
  fi

  # Increment the timeout counter and check if the timeout has been reached
  timeout_counter=$((timeout_counter + 1))
  if [ $((timeout_counter * interval)) -ge $((timeout * 60)) ]; then
    echo "❌ Timeout waiting on the workflow to complete. Exiting."
    exit 1
  fi

  sleep $interval
done
