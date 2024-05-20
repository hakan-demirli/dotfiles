{
  lib,
  rustPlatform,
  git,
  installShellFiles,
  makeWrapper,
  fetchFromGitHub,
  callPackage,
}:
rustPlatform.buildRustPackage rec {
  pname = "helix";
  version = "24.03-dev";

  src = fetchFromGitHub {
    owner = "helix-editor";
    repo = "helix";
    rev = "2301430e37a98192de7864faa2d8c1b84860f400";
    sha256 = "sha256-Ay87mjRXLGwBtgKW+SdfrsyUlDIygPQksaZXTV9PMSM=";
  };

  cargoHash = "sha256-3hTp9zf8cqOHlOURVT7dqz1ejl1U13VpZG+WDYcRPzI=";

  # disable fetching and building of tree-sitter grammars in favor of the custom build process in grammars.nix
  env.HELIX_DISABLE_AUTO_GRAMMAR_BUILD = "1";

  nativeBuildInputs = [git installShellFiles makeWrapper];

  postInstall = let
    grammarPath = callPackage "${src}/grammars.nix" {};
  in ''
    # We self build the grammar files
    rm -r runtime/grammars

    mkdir -p $out/lib
    cp -r runtime $out/lib
    ln -s ${grammarPath} $out/lib/runtime/grammars

    installShellCompletion contrib/completion/hx.{bash,fish,zsh}
    mkdir -p $out/share/{applications,icons/hicolor/256x256/apps}
    cp contrib/Helix.desktop $out/share/applications
    cp contrib/helix.png $out/share/icons/hicolor/256x256/apps
  '';

  postFixup = ''
    wrapProgram $out/bin/hx --set HELIX_RUNTIME $out/lib/runtime
  '';

  meta = with lib; {
    description = "A post-modern modal text editor";
    homepage = "https://helix-editor.com";
    license = licenses.mpl20;
    mainProgram = "hx";
    maintainers = with maintainers; [danth yusdacra zowoq];
  };
}
