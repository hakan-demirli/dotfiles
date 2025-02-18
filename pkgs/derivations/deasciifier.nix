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
  # Fetch the original repo.
  repo = fetchFromGitHub {
    owner = "meacer";
    repo = "deasciifier";
    rev = "4408e671714c5a60f1aced5e91d4eb312f5d3ab0";
    sha256 = "sha256-r7RTC3+MF6jJWsFYtw0ojnfTS08azh7DJYq08WF7Skc=";
  };

  # Create a modified version of the repo without using an external patch.
  modifiedRepo = stdenv.mkDerivation {
    name = "deasciifier-modified";
    src = repo;

    # Instead of applying an external patch file, use postPatch to run shell commands.
    postPatch = ''
      # Copy the bundle.js file from website/static/ts to src/typescript/
      cp website/static/ts/bundle.js src/typescript/

      # Remove all occurrences of "./../website/static/ts" from package.json
      # The -i option modifies the file in place.
      sed -i 's|\./\.\./website/static/ts||g' src/typescript/package.json
    '';

    # We don’t need any building; we just want to output the modified source.
    buildPhase = "true";
    installPhase = ''
      mkdir -p $out
      cp -r . $out
    '';
  };

  # Use the modified repo for the TypeScript build.
  tsBuild = buildNpmPackage rec {
    pname = "deasciifier-typescript";
    version = "2.0.1";
    # Reference the typescript subdirectory inside the modified repository.
    src = "${modifiedRepo}/src/typescript";
    CHROMEDRIVER_FILEPATH = pkgs.lib.getExe chromedriver;
    npmDepsHash = "sha256-6h5M5o+wtU3CkrRJ3dvfJkXIWZQJHv6rPbDhV0TeHN8=";
    nativeBuildInputs = [ pkgs.nodejs ];
  };
in
stdenv.mkDerivation {
  pname = "deasciifier";
  version = "master";

  # Use the modified repository here.
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
    # Launch the website using Python's HTTP server.
    cd "$out/website" || exit 1
    python3 -m http.server 8000
    EOF
        chmod +x $out/bin/deasciifier
  '';
}
