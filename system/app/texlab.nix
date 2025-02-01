{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  help2man,
  installShellFiles,
  nix-update-script,
}:

let
  isCross = stdenv.hostPlatform != stdenv.buildPlatform;
in
rustPlatform.buildRustPackage rec {
  pname = "texlab";
  version = "5.21.11";

  src = fetchFromGitHub {
    owner = "hakan-demirli";
    repo = "texlab";
    rev = "5a53c7a4c88b19df418fbf4ba4da2a45d199e4af";
    hash = "sha256-Lg0cZJWPwejSRESTV7U0/WC3A0qBJpj4RRuSCLuEaz4=";
  };

  cargoHash = "sha256-YU4/qdkZhjjzgza7R6yWG/pqwGWt0WkHMDuSMxuCcCo=";

  outputs = [ "out" ] ++ lib.optional (!isCross) "man";

  nativeBuildInputs = [ installShellFiles ] ++ lib.optional (!isCross) help2man;

  # When we cross compile we cannot run the output executable to
  # generate the man page
  postInstall = lib.optionalString (!isCross) ''
    # TexLab builds man page separately in CI:
    # https://github.com/latex-lsp/texlab/blob/v5.21.0/.github/workflows/publish.yml#L110-L114
    help2man --no-info "$out/bin/texlab" > texlab.1
    installManPage texlab.1
  '';

  passthru.updateScript = nix-update-script { };

  meta = with lib; {
    description = "Implementation of the Language Server Protocol for LaTeX";
    homepage = "https://github.com/latex-lsp/texlab";
    changelog = "https://github.com/latex-lsp/texlab/blob/v${version}/CHANGELOG.md";
    license = licenses.mit;
    maintainers = with maintainers; [
      doronbehar
      kira-bruneau
    ];
    platforms = platforms.all;
    mainProgram = "texlab";
  };
}
