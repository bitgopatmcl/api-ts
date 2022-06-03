{ pkgs, nodePackage }:
let
  nodejs = pkgs.callPackage "${pkgs.path}/pkgs/development/web/nodejs/v16.nix" {
    enableNpm = false;
  };
  workspace = pkgs.yarn2nix-moretea.mkYarnWorkspace {
    src = ./.;
    extraBuildInputs = [];
    buildPhase = ''
      yarn run build
    '';
    dontStrip = true; # Weird performance hack
  };
  package = workspace.${nodePackage}
in {
  devShells = {
    default = pkgs.mkShell {
      packages = [
        pkgs.nodejs
      ];

      shellHook = ''
        export NODE_PATH=${package}/libexec/${package.pname}/node_modules:$NODE_PATH
        export PATH=${package}/libexec/${package.pname}/node_modules/.bin:$PATH
      '';
    };
  };
}
