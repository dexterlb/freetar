{
  description = "Application packaged using poetry2nix";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, uv2nix, pyproject-nix, pyproject-build-systems }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        lib = nixpkgs.lib;
        pkgs = nixpkgs.legacyPackages.${system};
        python = pkgs.python312;

        workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
        overlay = workspace.mkPyprojectOverlay {
          sourcePreference = "wheel"; # or sourcePreference = "sdist";
        };
        pyprojectOverrides = final: prev: {
          # some dependencies need specific overrides
          jsmin = prev.jsmin.overrideAttrs (old: {
            nativeBuildInputs =
              old.nativeBuildInputs
              ++ final.resolveBuildSystem {
                setuptools = [ ];
              };
          });
        };

        # Construct package set
        pythonSet =
          # Use base package set from pyproject.nix builders
          (pkgs.callPackage pyproject-nix.build.packages {
            inherit python;
          }).overrideScope
            (
              lib.composeManyExtensions [
                pyproject-build-systems.overlays.default
                overlay
                pyprojectOverrides
              ]
            );

          venv-pkg = (pythonSet.mkVirtualEnv "freetar-env" workspace.deps.default)
            .overrideAttrs (old: {
              meta = (old.meta or {}) // {
                mainProgram = "freetar";
              };
            });
      in
      {
        packages = {
          freetar = venv-pkg;
          # freetar = pyproject-nix.build.util.mkApplication {
          #   venv = venv-pkg;
          #   package = pythonSet.freetar;
          # };
          default = self.packages.${system}.freetar;
        };

        devShells.default = pkgs.mkShell {
          packages = [ venv-pkg pkgs.uv ];
          env = {
            UV_NO_SYNC = "1";
            UV_PYTHON = "${venv-pkg}/bin/python";
            UV_PYTHON_DOWNLOADS = "never";
          };

          shellHook = ''
            # Undo dependency propagation by nixpkgs.
            unset PYTHONPATH

            # Get repository root using git. This is expanded at runtime by the editable `.pth` machinery.
            export REPO_ROOT=$(git rev-parse --show-toplevel)

            echo 'use `uv run freetar` to start freetar'
          '';
        };
      });
}
