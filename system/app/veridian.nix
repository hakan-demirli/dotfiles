{
  lib,
  fetchFromGitHub,
  rustPlatform,
  openssl,
  cmake,
  pkg-config,
  withSlang ? false,
}:

rustPlatform.buildRustPackage rec {
  pname = "veridian";
  version = "unstable-2024-08-08";

  src = fetchFromGitHub {
    owner = "vivekmalneedi";
    repo = pname;
    rev = "e156ac3f97408c816883659035687aa704064415";
    hash = "sha256-brILumMj2OIEVksGM4JHNkITheL6h4o7amnZ1ZRyb+M=";
  };

  cargoHash = "sha256-TSGjuS+mVpLr6eCBlC5gpbCuTIJ0aAM60s5ufw4MPUs=";

  cargoFlags = [ "--all-features" ]; # Optional: Add Cargo flags as needed

  nativeBuildInputs = lib.optionals withSlang [
    pkg-config
    rustPlatform.bindgenHook
    cmake
  ];

  buildInputs = lib.optionals withSlang [ openssl ];

  buildFeatures = lib.optionals withSlang [ "slang" ];

  patches = lib.optionals withSlang [
    ./veridian.patch
  ];

  SLANG_DIR = lib.optionalString withSlang (
    builtins.fetchTarball {
      name = "slang-linux-0.7";
      url = "https://github.com/MikePopoloski/slang/releases/download/v0.7/slang-linux.tar.gz";
      sha256 = "sha256:1mib4n73whlj7dvp6gxlq89v3cq3g9jrhhz9s5488g9gzw4x21bk";
    }
  );
  # cmakeFlags = lib.optionals withSlang [ "-DCMAKE_PREFIX_PATH=${SLANG_DIR}" ];

  doCheck = false;

  meta = with lib; {
    description = "A SystemVerilog language server";
    homepage = "https://github.com/vivekmalneedi/veridian";
    license = licenses.mit;
    maintainers = with maintainers; [ hakan-demirli ];
    platforms = platforms.linux;
    mainProgram = "veridian";
  };
}
