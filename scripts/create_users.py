import os
import json
import base64
import secrets
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import padding
from pathlib import Path

# Encryption key from Vault
ENCRYPTION_KEY = os.getenv("VAULT_ENCRYPTION_KEY", None)

if not ENCRYPTION_KEY:
    print("Error: VAULT_ENCRYPTION_KEY environment variable is not set.")
    exit(1)


def validate_users_file(file_path):
    """Validate that the provided file is a JSON file with the correct format."""
    try:
        with open(file_path, "r") as f:
            users = json.load(f)

        if not isinstance(users, list):
            raise ValueError("The JSON file must contain a list of user objects.")

        for user in users:
            if not all(key in user for key in ("username", "name", "role")):
                raise ValueError(f"Each user must have 'username', 'name', and 'role'. Found: {user}")

        return users
    except (json.JSONDecodeError, ValueError) as e:
        print(f"Error: Invalid JSON format in {file_path}. {e}")
        exit(1)


def generate_password(length=12):
    """Generate a password without special characters."""
    alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return ''.join(secrets.choice(alphabet) for _ in range(length))


def encrypt_data(data, key):
    """Encrypt data using AES-256-CBC."""
    backend = default_backend()
    cipher = Cipher(algorithms.AES(key), modes.CBC(key[:16]), backend=backend)
    encryptor = cipher.encryptor()

    padder = padding.PKCS7(algorithms.AES.block_size).padder()
    padded_data = padder.update(data) + padder.finalize()

    return encryptor.update(padded_data) + encryptor.finalize()


def main():
    # Get input file path
    input_file = input("Enter the full path to the input users.json file: ").strip()
    if not os.path.isfile(input_file):
        print(f"Error: The file {input_file} does not exist.")
        exit(1)

    # Validate JSON structure
    print(f"Validating JSON structure in {input_file}...")
    users = validate_users_file(input_file)
    print("JSON structure validated.")

    # Assign passwords to users
    for user in users:
        length = 12 if user["role"] in ("Admin", "Editor") else 8
        password = generate_password(length=length)
        user["password"] = base64.b64encode(password.encode()).decode()
        print(f"Generated password for {user['username']} (role: {user['role']})")

    # Ask for output path
    output_file = input("Enter the full path to save the encrypted users.json file: ").strip()
    output_dir = Path(output_file).parent
    if not output_dir.exists():
        print(f"Error: The directory {output_dir} does not exist.")
        exit(1)

    # Encrypt user data
    print("Encrypting user data...")
    serialized_users = json.dumps(users).encode()
    encryption_key = base64.b64decode(ENCRYPTION_KEY)
    encrypted_data = encrypt_data(serialized_users, encryption_key)

    # Save the encrypted file
    with open(output_file, "wb") as f:
        f.write(base64.b64encode(encrypted_data))
    print(f"Encrypted user list saved to: {output_file}")


if __name__ == "__main__":
    main()
