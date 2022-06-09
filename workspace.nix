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
  loadNodeEnv = let
      workspaceNodePaths = pkgs.lib.concatMapStringsSep ":" (dep: "${dep}/libexec") packageOut.workspaceDependencies;
    in ''
      export NODE_PATH=${workspaceNodePaths}:${packageOut.deps}/node_modules:$NODE_PATH
      export PATH=${packageOut.deps}/node_modules/.bin:$PATH
    '';
  scriptPackages = builtins.mapAttrs (name: script: pkgs.writeShellScriptBin "yarn-script-${name}" ''
      ${loadNodeEnv}
      ${pkgs.yarn}/bin/yarn run ${name} $*
    '') package.scripts;
in {
  devShells = {
    default = pkgs.mkShell {
      packages = [
        pkgs.nodejs
        pkgs.yarn
      ];

      shellHook = loadNodeEnv;
    };
  };

  packages = scriptPackages;

  apps = builtins.mapAttrs (name: script: {
    type = "app";
    program = "${scriptPackages.${name}}/bin/yarn-script-${name}";
  }) package.scripts;
}
