{ pkgs
, lib
, stdenvNoCC
, pyproject-nix
}:
let
  inherit (builtins) substring elemAt;
  inherit (lib) toLower;

  inherit (pyproject-nix.lib.pypa) matchWheelFileName;
  inherit (pyproject-nix.lib.eggs) matchEggFileName;

  # Predict URL from the PyPI index.
  # Args:
  #   pname: package name
  #   file: filename including extension
  #   hash: SRI hash
  #   kind: Language implementation and version tag
  predictURLFromPypi =
    {
      # package name
      pname
    , # filename including extension
      file
    }:
    let
      matchedWheel = matchWheelFileName file;
      matchedEgg = matchEggFileName file;
      kind =
        if matchedWheel != null then "wheel"
        else if matchedEgg != null then elemAt matchedEgg 2
        else "source";
      
      # Handle special cases where PyPI uses different URL patterns
      # Some packages use sha256 hashes in their URLs instead of the old pattern
      firstChar = toLower (substring 0 1 file);
      
      # Try the traditional pattern first, but be prepared for it to fail
      # The newer PyPI infrastructure sometimes uses different URL structures
      traditionalURL = "https://files.pythonhosted.org/packages/${kind}/${firstChar}/${pname}/${file}";
      
      # Alternative patterns that some packages might use
      # Note: The fallback script will handle the actual URL discovery
    in
    traditionalURL;
in
lib.mapAttrs (_: func: lib.makeOverridable func) {
  /*
    Fetch from the PyPI index.

    At first we try to fetch the predicated URL but if that fails we
    will use the Pypi API to determine the correct URL.

    Type: fetchFromPypi :: AttrSet -> derivation
    */
  fetchFromPypi =
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
    , # Use API-first approach for better reliability with modern PyPI
      useApiFirst ? false  # Default false; set true for packages with URL prediction issues
    }:
    let
      predictedURL = predictURLFromPypi { inherit pname file; };
    in
    stdenvNoCC.mkDerivation {
      name = file;
      nativeBuildInputs = [
        pkgs.curl
        pkgs.jq
      ];
      isWheel = lib.strings.hasSuffix "whl" file;
      system = "builtin";

      preferLocalBuild = true;
      impureEnvVars =
        lib.fetchers.proxyImpureEnvVars
        ++ [
          "NIX_CURL_FLAGS"
        ];

      inherit pname file version curlOpts predictedURL useApiFirst;

      builder = ./fetch-from-pypi.sh;

      outputHashMode = "flat";
      outputHashAlgo = "sha256";
      outputHash = hash;

      passthru = {
        urls = [ predictedURL ]; # retain compatibility with nixpkgs' fetchurl
      };
    };

  # Alternative fetcher that always uses PyPI JSON API first
  # More reliable but slightly slower
  # Recommended for packages with URL prediction issues (e.g., Arpeggio, newer packages)
  fetchFromPypiApiFirst = import ./fetchpypi-api-first.nix { inherit pkgs lib stdenvNoCC; };
}
