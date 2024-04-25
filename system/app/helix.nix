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
    rev = "109f53fb60f1b126c4c9afd97dd75972725d04ac";
    sha256 = "sha256-F97EVDCdoZOTiBOlmli922VhMcR065W/6TqXlfavLVg=";
  };

  cargoHash = "sha256-slHaUmdHOs6OKdEw/ucUO/IehibFl5KG/ISo8gQTM4E=";

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
