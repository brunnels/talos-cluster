#!/bin/bash
#
# Description:
# This script reads from standard input, finds tokens in the format "ak://<path>/<key>",
# and replaces them with a specific value from the JSON secret fetched from the Akeyless vault
# using the 'akeyless' CLI.
#
# Prerequisites:
# 1. The 'akeyless' CLI must be installed on your system.
# 2. The 'jq' CLI must be installed for parsing JSON (e.g., `sudo apt-get install jq`).
# 3. You must be authenticated with Akeyless (`akeyless login`).
#
# Follow the instructions to install the Akeyless CLI and add it to your PATH:
#   https://docs.akeyless.io/docs/cli
#
# The easiest way to configure authentication is to configure the Akeyless CLI with the following command:
#   akeyless configure --access-type api_key --access-id <your_api_access_id> --access-key <your_api_access_key>
#
# Usage:
# Pipe any string or file content into this script.
#
# Example:
# Given a secret at path 'app-prod/db' with content '{"password":"secret_pass"}',
# the following command...
#   echo "db_password: ak://app-prod/db/password" | ./inject.sh
# ...will output:
#   db_password: secret_pass

set -e
set -u
set -o pipefail

while IFS= read -r line || [[ -n "$line" ]]; do
  while true; do
    if ! [[ "$line" =~ (ak://[a-zA-Z0-9/_.-]+) ]]; then
      break
    fi

    token="${BASH_REMATCH[0]}"
    full_path="${token#ak://}"

    if [[ "$full_path" != *"/"* ]]; then
      echo "Error: Invalid token format. Expected ak://<path>/<key>, but got $token" >&2
      exit 1
    fi

    secret_name="${full_path%/*}"
    json_key="${full_path##*/}"

    secret_json=$(akeyless get-secret-value --name "$secret_name")

    if ! echo "$secret_json" | jq -e "has(\"$json_key\")" > /dev/null; then
      echo "Error: Key '$json_key' not found in secret '$secret_name'." >&2
      exit 1
    fi

    secret_value=$(echo "$secret_json" | jq -r ".\"$json_key\"")

    line="${line/"$token"/"$secret_value"}"
  done

  echo "$line"
done
