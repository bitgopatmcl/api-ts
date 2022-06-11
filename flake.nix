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
        tsconfigJsons = pkgs.lib.mapAttrs (name: package: let
          dirname = dep: pkgs.lib.last (pkgs.lib.splitString "/" dep.pname);
          paths = builtins.map (dep: ''"${dep.pname}": ["../${dirname dep}/src"]'') package.workspaceDependencies;
          references = builtins.map (dep: ''{ "path": "../packages/${dirname dep}" }'') package.workspaceDependencies;
          depPaths = pkgs.lib.mapAttrsToList (name: version: let
            depPackageJson = pkgs.lib.importJSON "${package.deps}/node_modules/${name}";
            typings = "${package.deps}/node_modules/${name}/package.json";
          in ''"${name}": ["${typings}"]'') (package.package.dependencies or {});
        in ''
          {
            "compilerOptions": {
              "paths": {
              }
            }
          }
        '') workspace;
        writeTsconfigJsons = pkgs.lib.mapAttrsToList (name: tsconfig: ''
          cat > $out/${reformatPackageName name}-tsconfig.json <<EOF
          ${tsconfig}
          EOF
        '') tsconfigJsons;
        linkNodeModules = pkgs.lib.mapAttrsToList (name: package: ''
          ln -s ${package.deps}/node_modules $out/${name}-modules
        '') workspace;
        tsconfigs = pkgs.runCommand "api-ts-tsconfigs" {} ''
          mkdir -p $out
          ${builtins.concatStringsSep "\n" linkNodeModules}
        '';
      in {
        devShells = {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nodejs
              yarn
            ];

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
