{
  pkgs,
  fetchFromGitHub,
}:
pkgs.rustPlatform.buildRustPackage {
  pname = "html-preview-lsp";
  version = "0.1.0";

  src = ../src/python/html-preview/lsp;

  cargoHash = "sha256-0gQSPS+L8OOuX3gL11DPrBNrw3O01L0LNTsHYV9oT8o=";

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
