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
    rev = "d094c9d2fa9745b2c4430eef052478c64d5dd3b6";
    hash = "sha256-3KjUunXTqdesvgDSeQMoXL0LRGsGQXZJGDt+xLWGovM=";
  };

  cargoHash = "sha256-qJQD9HjSrrHdppbLNgLnXCycgzbmPePydZve3A8zGtU=";
  useFetchCargoVendor = true;

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
