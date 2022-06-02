{
  description = "api-ts";

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
          nodejs = pkgs.callPackage "${pkgs.path}/pkgs/development/web/nodejs/v16.nix" {
            enableNpm = false;
          };
          workspace = pkgs.yarn2nix-moretea.mkYarnWorkspace {
            src = ./.;
            #extraBuildInputs = [ pkgs.jq ];
            buildPhase = ''
              #strippedConfig="$(jq '.references = []' tsconfig.json)" && echo -E "$\{strippedConfig\}" > tsconfig.json
              yarn run build
            '';
            dontStrip = true; # Weird performance hack
          };
        in {
          devShells = {
            default = pkgs.mkShell {
              name = "api-ts-shell";

              packages = with pkgs; [
                nodejs
                yarn
              ];
            };
          } // pkgs.lib.mapAttrs (name: package: pkgs.mkShell {
            packages = [
              pkgs.nodejs
            ];

            shellHook = ''
              echo ${package}
              export NODE_PATH=${package}/libexec/${package.pname}/node_modules:$NODE_PATH
              export PATH=${package}/libexec/${package.pname}/node_modules/.bin:$PATH
            '';
          }) workspace;
        }
      );
}
