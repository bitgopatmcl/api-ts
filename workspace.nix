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
  packageModules = workspace.${nodePackage}.overrideAttrs (attrs: {
    buildPhase = "";
    doDist = false;
  });
  loadNodeEnv = let
      workspaceNodePaths = pkgs.lib.concatMapStringsSep ":" (dep: "${workspace.${reformatPackageName dep.pname}}/libexec") packageModules.workspaceDependencies;
    in ''
      export NODE_PATH=${packageModules}/libexec/${packageModules.pname}/node_modules:$NODE_PATH
      export PATH=${packageModules}/libexec/${packageModules.pname}/node_modules/.bin:$PATH
    '';
  scripts = builtins.mapAttrs (name: script: pkgs.writeShellScriptBin "yarn-script-${name}" ''
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

  #checks = {
    #default = scripts.test;
  #};

  apps = builtins.mapAttrs (name: script: {
    type = "app";
    program = "${script}/bin/yarn-script-${name}";
  }) scripts;
}
