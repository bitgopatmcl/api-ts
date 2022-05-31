{
  description = "@api-ts/io-ts-http";

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
          };
        in {
          devShells = {
            default = pkgs.mkShell {
              name = "api-ts-shell";

              packages = with pkgs; [
                nodejs
                yarn
              ];

              #shellHook = ''
                #export PATH="$(pwd)/node_modules/.bin:$PATH"
              #'';
            };
          }; #// pkgs.lib.mapAttrs (name: package: pkgs.mkShell {
            #packages = [ pkgs.nodejs ];

            #shellHook = ''
              #export NODE_PATH=${package.deps}/node_modules:$NODE_PATH
              #export PATH=${package.deps}/node_modules/.bin:$PATH
            #'';
          #}) workspace;
        }
      );
}
