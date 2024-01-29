{
  lib,
  fetchFromGitHub,
  rustPlatform,
  openssl,
  pkg-config,
  withSlang ? false,
  sv-lang,
}:
rustPlatform.buildRustPackage (rec {
    pname = "veridian";
    version = "2023-08-05";

    src = fetchFromGitHub {
      owner = "vivekmalneedi";
      repo = pname;
      rev = "de0f90f10a444a0bf9e28ff2f512d61788754d39";
      hash = "sha256-+VKrY0JjiVvdNyAFOZWntdS4rc9e8oSKUgR39nwteL8=";
    };

    cargoHash = "sha256-FcxcJU9UlksCBER8RZ4lwYy2/IsxouYkfTYSMtWiOtY=";

    doCheck = false;

    meta = with lib; {
      description = "A SystemVerilog language server";
      homepage = "https://github.com/vivekmalneedi/veridian";
      license = licenses.mit;
      maintainers = [];
    };
  }
  // (lib.optionalAttrs withSlang {
    patches = [./0001-Allow-building-with-slang-when-off-line.patch];
    #SLANG_DIR = "${sv-lang}";     # nixpkgs has too new version
    SLANG_DIR = builtins.fetchTarball {
      name = "slang-linux-0.7";
      url = "https://github.com/MikePopoloski/slang/releases/download/v0.7/slang-linux.tar.gz";
      sha256 = "sha256:1mib4n73whlj7dvp6gxlq89v3cq3g9jrhhz9s5488g9gzw4x21bk";
    };
    buildFeatures = ["slang"];
    nativeBuildInputs = [pkg-config rustPlatform.bindgenHook];
    buildInputs = [openssl];
  }))
