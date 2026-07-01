{
  pkgs,
  stdenv,
  fetchFromGitHub,
  ant,
  python3,
  buildNpmPackage,
  chromedriver,
}:

let
  repo = fetchFromGitHub {
    owner = "meacer";
    repo = "deasciifier";
    rev = "4408e671714c5a60f1aced5e91d4eb312f5d3ab0";
    sha256 = "sha256-r7RTC3+MF6jJWsFYtw0ojnfTS08azh7DJYq08WF7Skc=";
  };

  modifiedRepo = stdenv.mkDerivation {
    name = "deasciifier-modified";
    src = repo;

    postPatch = ''
      cp website/static/ts/bundle.js src/typescript/

      sed -i 's|\./\.\./website/static/ts||g' src/typescript/package.json
    '';

    buildPhase = "true";
    installPhase = ''
      mkdir -p $out
      cp -r . $out
    '';
  };

  tsBuild = buildNpmPackage rec {
    pname = "deasciifier-typescript";
    version = "2.0.1";
    src = "${modifiedRepo}/src/typescript";
    CHROMEDRIVER_FILEPATH = pkgs.lib.getExe chromedriver;
    npmDepsHash = "sha256-6h5M5o+wtU3CkrRJ3dvfJkXIWZQJHv6rPbDhV0TeHN8=";
    nativeBuildInputs = [ pkgs.nodejs ];
  };
in
stdenv.mkDerivation {
  pname = "deasciifier";
  version = "master";

  src = modifiedRepo;

  nativeBuildInputs = [
    ant
    python3
    pkgs.nodejs
    pkgs.openjdk
  ];

  buildPhase = ''
    export JAVA_HOME=${pkgs.openjdk}
    ant -v build-all

    mkdir -p src/typescript/out
    cp -r ${tsBuild}/lib src/typescript/out
  '';

  installPhase = ''
        mkdir -p $out
        cp -r output $out/
        cp -r website $out/
        cp -r src/typescript/out $out/ts_build

        mkdir -p $out/bin
        cat > $out/bin/deasciifier <<EOF
    #!/bin/sh
    cd "$out/website" || exit 1
    python3 -m http.server 8000
    EOF
        chmod +x $out/bin/deasciifier
  '';
}
