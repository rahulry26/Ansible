#!/bin/bash

# Azure DevOps Variables
ORG_URL="https://dev.azure.com/YOUR_ORG"  # Organization URL
PAT="YOUR_PERSONAL_ACCESS_TOKEN"  # Store securely

# List of projects to scan (modify this with actual project names)
PROJECTS=("Project1" "Project2" "Project3")

# Define the domain keyword to filter pipelines (modify this based on naming conventions)
DOMAIN_FILTER="DomainA"

# Temporary file to track already reported failures
FAILED_PIPELINES_FILE="/tmp/failed_pipelines.log"
touch $FAILED_PIPELINES_FILE  # Ensure the file exists

# Function to get failed pipelines for a given project
get_failed_pipelines() {
    local project_name=$1
    local start_time=$2
    local end_time=$3
    
    az devops configure --defaults organization=$ORG_URL project=$project_name

    # Fetch failed pipelines filtered by domain
    az pipelines runs list --status failed \
        --query "[?contains(definition.name, '$DOMAIN_FILTER') && startTime >= '$start_time' && startTime <= '$end_time'].[id,definition.name]" \
        --output tsv
}

# Function to check for new failures and track them
check_for_failures() {
    local start_time=$1
    local end_time=$2
    local new_failures=0

    for project in "${PROJECTS[@]}"; do
        failed_pipelines=$(get_failed_pipelines "$project" "$start_time" "$end_time")

        while IFS=$'\t' read -r pipeline_id pipeline_name; do
            if ! grep -q "$pipeline_id" "$FAILED_PIPELINES_FILE"; then
                echo "$pipeline_id - $pipeline_name" >> "$FAILED_PIPELINES_FILE"
                new_failures=1
            fi
        done <<< "$failed_pipelines"
    done

    echo "$new_failures"  # Return 1 if new failures were found, else return 0
}

# Main script logic
current_time=$(date +"%H:%M")

if [ "$current_time" == "10:00" ]; then
    start_time=$(date -u -d 'today 00:00' +"%Y-%m-%dT%H:%M:%SZ")  # Scan from midnight to 10 AM
    end_time=$(date -u -d 'today 10:00' +"%Y-%m-%dT%H:%M:%SZ")
else
    start_time=$(date -u -d '30 minutes ago' +"%Y-%m-%dT%H:%M:%SZ")  # Scan last 30 minutes
    end_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
fi

check_for_failures "$start_time" "$end_time"  # Execute failure check
