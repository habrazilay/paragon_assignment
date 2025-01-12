#!/bin/sh

set -euo pipefail

# Fetch the encryption key from Vault
echo "Fetching encryption key from Vault..."
ENCRYPTION_KEY=$(curl -s --header "X-Vault-Token: $VAULT_TOKEN" \
    "$VAULT_URL/v1/secret/data/grafana/encryption-key" | jq -r '.data.key')

# Fetch the encrypted user list from Vault and decode it
echo "Fetching encrypted user list from Vault..."
curl -s --header "X-Vault-Token: $VAULT_TOKEN" \
    "$VAULT_URL/v1/secret/data/grafana/encrypted-user-list" | \
    jq -r '.data["users.json.enc"]' | base64 --decode > scripts/encrypted/users.json.enc
echo "Encrypted file saved to scripts/encrypted/users.json.enc"

# Decrypt the user list
echo "Decrypting user list..."
openssl enc -d -aes-256-cbc -pbkdf2 -in scripts/encrypted/users.json.enc \
    -out scripts/decrypted/users.json -pass pass:"$ENCRYPTION_KEY"
echo "Decrypted file saved to scripts/decrypted/users.json"

# Parse and process the user list
echo "Processing user list..."
users=$(cat scripts/decrypted/users.json | jq -c '.[]')

echo "$users" | while read -r user; do
    username=$(echo "$user" | jq -r '.username')
    password=$(echo "$user" | jq -r '.password')
    role=$(echo "$user" | jq -r '.role')

    echo "Creating user: $username with role: $role"

    # Use Basic Auth for the API request
    curl -s -X POST "$GRAFANA_URL/api/admin/users" \
        -H "Authorization: Basic $(echo -n "$GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD" | base64)" \
        -H "Content-Type: application/json" \
        -d "{
              \"name\": \"$username\",
              \"email\": \"$username@example.com\",
              \"login\": \"$username\",
              \"password\": \"$password\",
              \"role\": \"$role\"
        }" || echo "Error creating user $username"
done

echo "All users provisioned successfully!"
