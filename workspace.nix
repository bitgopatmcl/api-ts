{ pkgs, packageJSON }:
let
  nodejs = pkgs.callPackage "${pkgs.path}/pkgs/development/web/nodejs/v16.nix" {
    enableNpm = false;
  };
  package = pkgs.lib.importJSON packageJSON;
  # Duplicated from yarn2nix-moretea's version
  reformatPackageName = pname:
    let
      parts = builtins.tail (builtins.match "^(@([^/]+)/)?([^/]+)$" pname);
      non-null = builtins.filter (x: x != null) parts;
    in builtins.concatStringsSep "-" non-null;
  nodePackage = reformatPackageName package.name;
  workspace = pkgs.yarn2nix-moretea.mkYarnWorkspace {
    src = ./.;
    extraBuildInputs = [];
    buildPhase = ''
      yarn run build
    '';
    dontStrip = true; # Weird performance hack
  };
  packageOut = workspace.${nodePackage};
  scriptPackages = builtins.mapAttrs (name: script: pkgs.writeShellScriptBin "yarn-script-${name}" ''
      NODE_PATH=${packageOut}/libexec/${packageOut.pname}/node_modules:$NODE_PATH
      PATH=${packageOut}/libexec/${packageOut.pname}/node_modules/.bin:$PATH
      ${pkgs.yarn}/bin/yarn run ${name} $*
    '') package.scripts;
in {
  devShells = {
    default = pkgs.mkShell {
      packages = [
        pkgs.nodejs
      ];

      shellHook = ''
        export NODE_PATH=${packageOut}/libexec/${packageOut.pname}/node_modules:$NODE_PATH
        export PATH=${packageOut}/libexec/${packageOut.pname}/node_modules/.bin:$PATH
      '';
    };
  };

  packages = scriptPackages;

  apps = builtins.mapAttrs (name: script: {
    type = "app";
    program = "${scriptPackages.${name}}/bin/yarn-script-${name}";
  }) package.scripts;
}
