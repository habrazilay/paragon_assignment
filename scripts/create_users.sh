#!/bin/bash

set -euo pipefail

# Log setup with dynamic filename and appending for same-day logs
LOG_DIR="scripts/logs"
LOG_FILE="$LOG_DIR/create_users_$(date +'%Y-%m-%d').log"
mkdir -p "$LOG_DIR"

log() {
    local timestamp; timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    printf "%s - %s\n" "$timestamp" "$1" | tee -a "$LOG_FILE"
}

# Function to generate a random password (12 alphanumeric characters)
generate_password() {
    local password
    password=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 12)
    if [[ -z $password ]]; then
        log "Error: Failed to generate a password."
        return 1
    fi
    printf "%s" "$password"
}

# Fetch Grafana credentials from Kubernetes secrets
log "Fetching Grafana credentials from Kubernetes secrets..."
namespace="default" # Namespace containing the `grafana` secret

admin_user=$(kubectl get secret grafana -n "$namespace" -o jsonpath='{.data.admin-user}' | base64 --decode)
admin_password=$(kubectl get secret grafana -n "$namespace" -o jsonpath='{.data.admin-password}' | base64 --decode)

if [[ -z $admin_user || -z $admin_password ]]; then
    log "Error: Failed to retrieve Grafana credentials from Kubernetes secrets."
    exit 1
fi

grafana_url="http://localhost:3000"  # Replace with your Grafana URL

# Path to the input JSON file
input_file="/Users/danielschmidt/Documents/paragon_assignment/scripts/input/users.json"

if [[ ! -f "$input_file" ]]; then
    log "Error: Input file $input_file not found."
    exit 1
fi

log "Reading input file: $input_file"

# Validate JSON format
if ! jq empty "$input_file" >/dev/null 2>&1; then
    log "Error: Invalid JSON format in $input_file. Exiting."
    exit 1
fi

# Process each user from the JSON file
jq -c '.[]' "$input_file" | while read -r user; do
    username=$(echo "$user" | jq -r '.username')
    name=$(echo "$user" | jq -r '.name')
    role=$(echo "$user" | jq -r '.role')

    if [[ -z "$username" || -z "$name" || -z "$role" ]]; then
        log "Error: Missing fields for a user entry. Skipping."
        continue
    fi

    log "Attempting to create user: $username with role: $role"

    # Generate password
    password=$(generate_password) || { log "Failed to generate a password. Skipping user $username."; continue; }

    # Use Basic Auth for the API request
    response=$(curl -s -w "\n%{http_code}" -X POST "$grafana_url/api/admin/users" \
        -H "Authorization: Basic $(printf "%s:%s" "$admin_user" "$admin_password" | base64)" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg name "$name" --arg email "$username@example.com" --arg login "$username" --arg password "$password" --arg role "$role" \
            '{"name": $name, "email": $email, "login": $login, "password": $password, "role": $role}')")

    if [[ $? -ne 0 ]]; then
        log "Error: Failed to connect to Grafana API. Skipping user $username."
        continue
    fi

    # Extract HTTP status code and response body
    http_code=$(printf "%s" "$response" | tail -n1)
    response_body=$(printf "%s" "$response" | head -n1)

    log "HTTP Response Code: $http_code"
    log "HTTP Response Body: $response_body"

    if [[ "$http_code" -eq 201 || "$http_code" -eq 200 ]]; then
        log "User $username created successfully."
    else
        log "Error creating user $username. HTTP $http_code: $response_body"
    fi
done
