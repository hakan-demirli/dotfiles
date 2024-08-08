{
  lib,
  fetchFromGitHub,
  rustPlatform,
  openssl,
  pkg-config,
  withSlang ? false,
  sv-lang,
}:
rustPlatform.buildRustPackage (
  rec {
    pname = "veridian";
    version = "2024-08-08";

    src = fetchFromGitHub {
      owner = "vivekmalneedi";
      repo = pname;
      rev = "e156ac3f97408c816883659035687aa704064415";
      hash = "sha256-brILumMj2OIEVksGM4JHNkITheL6h4o7amnZ1ZRyb+M=";
    };

    cargoHash = "sha256-MAeFbr4e64vHS9baQprOb5r96bNMQDS3aRb48KkAhGk=";

    doCheck = false;

    meta = with lib; {
      description = "A SystemVerilog language server";
      homepage = "https://github.com/vivekmalneedi/veridian";
      license = licenses.mit;
      maintainers = [ ];
    };
  }
  // (lib.optionalAttrs withSlang {
    patches = [ ./0001-Allow-building-with-slang-when-off-line.patch ];
    #SLANG_DIR = "${sv-lang}";     # nixpkgs has too new version
    SLANG_DIR = builtins.fetchTarball {
      name = "slang-linux-0.7";
      url = "https://github.com/MikePopoloski/slang/releases/download/v0.7/slang-linux.tar.gz";
      sha256 = "sha256:1mib4n73whlj7dvp6gxlq89v3cq3g9jrhhz9s5488g9gzw4x21bk";
    };
    buildFeatures = [ "slang" ];
    nativeBuildInputs = [
      pkg-config
      rustPlatform.bindgenHook
    ];
    buildInputs = [ openssl ];
  })
)
