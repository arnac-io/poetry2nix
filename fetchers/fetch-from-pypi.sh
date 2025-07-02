#!/usr/bin/env bash

# shellcheck disable=SC1091,SC2154
source "$stdenv/setup"
set -euo pipefail

curl="curl            \
 --location           \
 --max-redirs 20      \
 --retry 2            \
 --disable-epsv       \
 --cookie-jar cookies \
 --insecure           \
 --speed-time 5       \
 --progress-bar       \
 --fail               \
 $curlOpts            \
 $NIX_CURL_FLAGS"

echo "Trying to fetch with predicted URL: $predictedURL"

# Check if we should use API-first approach
if [[ "${useApiFirst:-false}" == "true" ]]; then
    echo "API-first mode enabled, querying pypi.org API directly"
    
    # Try to get the actual URL from PyPI JSON API first
    if ! api_response=$($curl "https://pypi.org/pypi/$pname/json" 2>/dev/null); then
        echo "ERROR: Failed to query PyPI API for package '$pname'"
        echo "Falling back to predicted URL..."
    else
        # Extract the URL for the specific file and version
        if url=$(echo "$api_response" | jq -r ".releases.\"$version\"[] | select(.filename == \"$file\") | .url" 2>/dev/null) && [[ -n "$url" && "$url" != "null" ]]; then
            echo "Found API URL: $url"
            if $curl "$url" --output "$out"; then
                if [[ -s "$out" ]]; then
                    echo "Successfully fetched using API-provided URL"
                    exit 0
                else
                    echo "API URL returned empty file, falling back to predicted URL..."
                    rm -f "$out"
                fi
            else
                echo "API URL failed, falling back to predicted URL..."
            fi
        else
            echo "Could not find file in API response, falling back to predicted URL..."
        fi
    fi
fi

# Try the predicted URL first (or as fallback if API-first failed)
echo "Attempting predicted URL: $predictedURL"
if $curl "$predictedURL" --output "$out"; then
    # Verify that we actually got a valid file (not an error page)
    if [[ -s "$out" ]]; then
        echo "Successfully fetched using predicted URL"
        exit 0
    else
        echo "Predicted URL returned empty file, falling back to API..."
        rm -f "$out"
    fi
else
    echo "Predicted URL failed with curl error"
fi

echo "Predicted URL '$predictedURL' failed with 404 (modern PyPI uses hash-based URLs)"
echo "This is expected for newer packages. Falling back to PyPI JSON API..."

# Try to get the actual URL from PyPI JSON API
if ! api_response=$($curl "https://pypi.org/pypi/$pname/json" 2>/dev/null); then
    echo "ERROR: Failed to query PyPI API for package '$pname'"
    echo "This might be due to:"
    echo "  - Network connectivity issues"
    echo "  - Package name mismatch"
    echo "  - PyPI API being temporarily unavailable"
    exit 1
fi

# Extract the URL for the specific file and version
if ! url=$(echo "$api_response" | jq -r ".releases.\"$version\"[] | select(.filename == \"$file\") | .url" 2>/dev/null); then
    echo "ERROR: Failed to parse PyPI API response"
    exit 1
fi

# Check if we found a URL
if [[ -z "$url" || "$url" == "null" ]]; then
    echo "ERROR: Could not find download URL for $file version $version"
    echo "Available versions for $pname:"
    echo "$api_response" | jq -r '.releases | keys[]' 2>/dev/null || echo "Failed to list versions"
    echo "Available files for version $version:"
    echo "$api_response" | jq -r ".releases.\"$version\"[]?.filename" 2>/dev/null || echo "No files found for this version"
    exit 1
fi

echo "Found actual URL: $url"

# Try to download from the API-provided URL
if ! $curl "$url" --output "$out"; then
    echo "ERROR: Failed to download from API-provided URL: $url"
    echo "This might indicate:"
    echo "  - The file has been removed from PyPI"
    echo "  - There's a temporary server issue"
    echo "  - The URL format has changed again"
    exit 1
fi

# Verify we got a valid file
if [[ ! -s "$out" ]]; then
    echo "ERROR: Downloaded file is empty from URL: $url"
    exit 1
fi

echo "Successfully fetched using API-provided URL"
