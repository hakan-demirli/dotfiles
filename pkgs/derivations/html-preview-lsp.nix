{
  pkgs,
  fetchFromGitHub,
}:
pkgs.rustPlatform.buildRustPackage {
  pname = "html-preview-lsp";
  version = "0.1.0";

  src = ../src/python/html-preview/lsp;
  useFetchCargoVendor = true;

  cargoHash = "sha256-UTdOk/DMxTGhHbyTiIPz1V/wI6bTHDSGfO5n3b8NVBc=";

  propagatedBuildInputs = [
    pkgs.glibc
    pkgs.openssl
    pkgs.pkg-config
    pkgs.rustc
    pkgs.cargo
  ];

  nativeBuildInputs = [
    pkgs.glibc
    pkgs.openssl
    pkgs.pkg-config
    pkgs.rustc
    pkgs.cargo
  ];
}
