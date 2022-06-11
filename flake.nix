{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, flake-compat }:
    flake-utils.lib.eachDefaultSystem
      (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        workspace = pkgs.yarn2nix-moretea.mkYarnWorkspace {
          src = ./.;
          extraBuildInputs = [];
          buildPhase = ''
            yarn run build
          '';
          dontStrip = true; # Weird performance hack
        };
        # Duplicated from yarn2nix-moretea's version
        reformatPackageName = pname:
          let
            parts = builtins.tail (builtins.match "^(@([^/]+)/)?([^/]+)$" pname);
            non-null = builtins.filter (x: x != null) parts;
          in builtins.concatStringsSep "-" non-null;
        tsconfigJsons = pkgs.lib.mapAttrs (name: package: ''
          {
            "compilerOptions": {
              "baseUrl": "${package.deps}/node_modules",
              "typeRoots": [
                "${package.deps}/node_modules/@types"
              ]
            }
          }
        '') workspace;
        writeTsconfigJsons = pkgs.lib.mapAttrsToList (name: tsconfig: ''
          cat > $out/${reformatPackageName name}-tsconfig.json <<EOF
          ${tsconfig}
          EOF
        '') tsconfigJsons;
        tsconfigs = pkgs.runCommand "api-ts-tsconfigs" {} ''
          mkdir -p $out
          ${builtins.concatStringsSep "\n" writeTsconfigJsons}
        '';
      in {
        devShells = {
          default = pkgs.mkShell {
            packages = with pkgs; [ nodejs ];

            shellHook = ''
              if [[ -d $(pwd)/.tsconfigs || -L $(pwd)/.tsconfigs ]]; then
                rm -rf $(pwd)/.tsconfigs
              fi

              ln -s ${tsconfigs} $(pwd)/.tsconfigs
            '';
          };
        };
      }
      );
}
