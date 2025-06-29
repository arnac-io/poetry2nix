{poetry2nix, pkgs, lib } :
let
  # Import the fetcher functions needed for URL fixes
  inherit (poetry2nix) fetchFromPypi;
  
  isDarwin = lib.strings.hasSuffix "darwin" builtins.currentSystem;
  # Use post overrides to hook after the default poetry overrides are applied, make sure you know what you are doing
  postOverrides = poetry2nix.overrides.withoutDefaults
      (final: prev: {
        rich = prev.rich.overridePythonAttrs (
        old: {
            buildInputs = [ ];
          }
        );

        arpeggio = prev.arpeggio.overridePythonAttrs (old: {
          src = fetchFromPypi {
            pname = old.pname;
            inherit (old) version;
            file = old.src.name;
            hash = old.src.outputHash;
            useApiFirst = true;
          };
        });

        # Consider adding similar fixes for other packages with URL issues
        # anyio = prev.anyio.overridePythonAttrs (old: {
        #   src = fetchFromPypi {
        #     pname = old.pname;
        #     inherit (old) version;
        #     file = old.src.name;
        #     hash = old.src.outputHash;
        #     useApiFirst = true;
        #   };
        # });

        pyee = prev.pyee.overridePythonAttrs (old: {
              # Current poetry2nix override appears to be broken: `sed: can't read setup.py: No such file or directory`.
              postPatch = "";
        });

        fastapi = prev.fastapi.overridePythonAttrs (old: {
          propagatedBuildInputs = [ ];
        });

        eth-hash = prev.eth-hash.overridePythonAttrs (old: {
          # Current poetry2nix override appears to be broken: `substitute(): ERROR: file 'setup.py' does not exist`.
          preConfigure = "";
        });

        eth-keys = prev.eth-keys.overridePythonAttrs (old: {
          # Current poetry2nix override appears to be broken: `substitute(): ERROR: file 'setup.py' does not exist`.
          preConfigure = "";
        });

        rlp = prev.rlp.overridePythonAttrs (old: {
          # Current poetry2nix override appears to be broken: `substitute(): ERROR: file 'setup.py' does not exist`.
          preConfigure = "";
        });

        eth-keyfile = prev.eth-keyfile.overridePythonAttrs (old: {
          # Current poetry2nix override appears to be broken: `substitute(): ERROR: file 'setup.py' does not exist`.
          preConfigure = "";
        });

        web3 = prev.web3.overridePythonAttrs (old: {
          # Current poetry2nix override appears to be broken: `substitute(): ERROR: file 'setup.py' does not exist`.
          preConfigure = "";
        });

        ckzg = prev.ckzg.overridePythonAttrs (old: {
          # Current poetry2nix override appears to be broken: `substitute(): ERROR: file 'src/Makefile' does not exist`.
          postPatch = "";
        });
    });
in
  poetry2nix.overrides.withDefaults
      (final: prev: {
        grpc-stubs = prev.grpc-stubs.overridePythonAttrs
        (
          old: {
            buildInputs = (old.buildInputs or [ ]) ++ [ prev.setuptools ];
          }
        );

        grpcio-health-checking = prev.grpcio-health-checking.overridePythonAttrs
        (
          old: {
            buildInputs = (old.buildInputs or [ ]) ++ [ prev.setuptools ];
          }
        );

        # ... (all your other existing overrides)
        # Many packages using preferWheel = true to avoid build issues
        # Many packages adding setuptools to buildInputs
        
        # Example of packages that might benefit from URL fix:
        # If you encounter 404 errors with these, consider adding similar useApiFirst fixes
        
        ddtrace = prev.ddtrace.override { preferWheel = true;};
        protobuf = prev.protobuf.override { preferWheel = true; };
        fastapi = prev.fastapi.override { preferWheel = true; };
        pandas = prev.pandas.override { preferWheel = true; };
        
        # Custom package with complex build setup
        pysui-fastcrypto = prev.pysui-fastcrypto.overridePythonAttrs (old: rec {
          src = pkgs.fetchFromGitHub {
            owner = "FrankC01";
            repo = "pysui-fastcrypto";
            rev = "8cd03773559416fb43cd751228330e7268623e5e";
            hash = "sha256-DAfoKq7cnhIT1zF9HhEDJGDyTNFePJJj6CSuX97lOMw=";
          };
          cargoDeps = pkgs.rustPlatform.importCargoLock {
            lockFile = "${src.out}/Cargo.lock";
          };
          buildInputs = (old.buildInputs or [ ]) ++ lib.optionals isDarwin [
            pkgs.libiconv
          ];
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
            pkgs.rustPlatform.cargoSetupHook
            pkgs.rustPlatform.maturinBuildHook
          ];
        });

        # More packages with preferWheel for performance/compatibility
        watchfiles = prev.watchfiles.override { preferWheel = true; };
    }) ++ postOverrides 