{ pkgs, packageJSON }:
let
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
  scriptNames = pkgs.lib.mapAttrsToList (name: value: name) package.scripts;
  writeScripts = pkgs.lib.concatMapStringsSep "\n" (name: ''
    cat > $out/bin/yarn-script-${name} <<EOF
    #!${pkgs.bash}/bin/bash
    ${loadNodeEnv}
    ${pkgs.yarn}/bin/yarn run ${name} $*
    EOF
    chmod +x $out/bin/yarn-script-${name}
  '') scriptNames;
  scripts = pkgs.runCommand "${nodePackage}-scripts" {} ''
    mkdir -p $out/bin
    ${writeScripts}
  '';
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
    program = "${scripts}/bin/yarn-script-${name}";
  }) package.scripts;
}
