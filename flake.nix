{
  description = "Application packaged using poetry2nix";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, poetry2nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # see https://github.com/nix-community/poetry2nix/tree/master#api for more functions and examples.
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (poetry2nix.lib.mkPoetry2Nix { inherit pkgs; }) mkPoetryApplication defaultPoetryOverrides;
      in
      {
        packages = {
          freetar = mkPoetryApplication {
            projectDir = self;
            overrides = defaultPoetryOverrides.extend
              (self: super: {
                lesscpy = super.lesscpy.overridePythonAttrs
                  (old: {
                    buildInputs = (old.buildInputs or [ ]) ++ [ super.setuptools ];
                  });
                flask-minify = super.flask-minify.overridePythonAttrs
                  (old: {
                    buildInputs = (old.buildInputs or [ ]) ++ [ super.setuptools ];
                  });
                itsdangerous = super.itsdangerous.overridePythonAttrs (
                  old: {
                    buildInputs = (old.buildInputs or [ ]) ++ [ super.flit-core ];
                  }
                );
                jinja2 = super.jinja2.overridePythonAttrs (
                  old: {
                    buildInputs = (old.buildInputs or [ ]) ++ [ super.flit-core ];
                  }
                );
              });
          };
          default = self.packages.${system}.freetar;
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.freetar ];
          packages = [ pkgs.poetry ];
        };
      });
}
