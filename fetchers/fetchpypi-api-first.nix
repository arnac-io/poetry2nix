{ pkgs
, lib
, stdenvNoCC
}:

# Alternative PyPI fetcher that uses the JSON API first
# This is more reliable but slightly slower due to the API call
lib.makeOverridable (
  {
    # package name
    pname
  , # filename including extension
    file
  , # the version string of the dependency
    version
  , # SRI hash
    hash
  , # Options to pass to `curl`
    curlOpts ? ""
  ,
  }:
  stdenvNoCC.mkDerivation {
    name = "${pname}-${version}-${file}";
    nativeBuildInputs = [
      pkgs.curl
      pkgs.jq
    ];
    
    preferLocalBuild = true;
    impureEnvVars =
      lib.fetchers.proxyImpureEnvVars
      ++ [
        "NIX_CURL_FLAGS"
      ];

    inherit pname file version curlOpts;

    builder = builtins.toFile "fetch-pypi-api-first.sh" ''
      #!/usr/bin/env bash
      
      source $stdenv/setup
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

      echo "Fetching $pname $version ($file) using PyPI JSON API"

      # Query PyPI JSON API for the actual download URL
      if ! api_response=$($curl "https://pypi.org/pypi/$pname/json" 2>/dev/null); then
          echo "ERROR: Failed to query PyPI API for package '$pname'"
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
          echo "Available files for version $version:"
          echo "$api_response" | jq -r ".releases.\"$version\"[]?.filename" 2>/dev/null || echo "No files found"
          exit 1
      fi

      echo "Downloading from: $url"

      # Download the file
      if ! $curl "$url" --output "$out"; then
          echo "ERROR: Failed to download from: $url"
          exit 1
      fi

      echo "Successfully downloaded $file"
    '';

    outputHashMode = "flat";
    outputHashAlgo = "sha256";
    outputHash = hash;

    passthru = {
      # Will be populated after the API call, but we can't know it beforehand
      urls = [ "https://pypi.org/pypi/${pname}/json" ];
    };
  }
) 