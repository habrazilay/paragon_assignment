#!/bin/bash

set -euo pipefail

# Log setup
LOG_FILE="create_single_user.log"
: > "$LOG_FILE" # Clear the log file at the beginning of the script
printf "Log file: %s\n" "$LOG_FILE"

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

# User details
username="viewer1"
name="Viewer 1"
role="Viewer"

# Generate password
password=$(generate_password) || { log "Failed to generate a password. Aborting."; exit 1; }

log "Attempting to create user: $username"

# Use Basic Auth for the API request
response=$(curl -s -w "\n%{http_code}" -X POST "$grafana_url/api/admin/users" \
    -H "Authorization: Basic $(printf "%s:%s" "$admin_user" "$admin_password" | base64)" \
    -H "Content-Type: application/json" \
    -d "{
          \"name\": \"$name\",
          \"email\": \"$username@example.com\",
          \"login\": \"$username\",
          \"password\": \"$password\",
          \"role\": \"$role\"
    }")

if [[ $? -ne 0 ]]; then
    log "Error: Failed to connect to Grafana API."
    exit 1
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
