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
    version = "2023-08-05";

    src = fetchFromGitHub {
      owner = "vivekmalneedi";
      repo = pname;
      rev = "aca8ee110002bab42435830823db8d569221985e";
      hash = "sha256-dw3I4MDnjG90XSlyZZFwg7LdZfxK1T5H87oBVvqeqzM=";
    };

    cargoHash = "sha256-pWjGuLiJxM0drtLHoo381z7VSawjFKuvOTJ0qxhQtxE=";

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
