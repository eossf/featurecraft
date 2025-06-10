#!/bin/bash

# Iterate over each non-empty, non-comment line in .env and export as TF_VAR_<key>
while IFS='=' read -r key value; do
  # Skip empty lines and lines starting with #
  [[ -z "$key" || "$key" =~ ^# ]] && continue
  # Remove possible carriage return and whitespace
  key=$(echo "$key" | tr -d '\r' | xargs | tr '[:upper:]' '[:lower:]')
  value=$(echo "$value" | tr -d '\r' | xargs)
  if [[ "$key" =~ pass|password|key|token ]]; then
    echo "$key=$(echo "${value:0:3}******")"
  else
    echo "$key=$value"
  fi
  export TF_VAR_"$key"="$value"
done < .env