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
    version = "2024-06-11";

    src = fetchFromGitHub {
      owner = "vivekmalneedi";
      repo = pname;
      rev = "966a49601ecb94a7e8a4a155ca97c4abc7ef26a9";
      hash = "sha256-WdL8DgF5Ff7A+vcTs1DsrVgHZVezkwlqPL/Gr5JNwpQ=";
    };

    cargoHash = "sha256-zyo0czRq8yGSHlTks2jnRo8XuK6DcaO+7KdqrxCIXN4=";

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
