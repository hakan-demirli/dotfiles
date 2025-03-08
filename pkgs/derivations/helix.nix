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
  version = "25.01-dev";

  src = fetchFromGitHub {
    owner = "helix-editor";
    repo = "helix";
    rev = "dc4761ad3a09a1cc9a3219d75765ff098fb203af";
    sha256 = "sha256-nzGqv+4teMbOjhylRCfGsqH7XFLt5m+uwJHgGA0YpUQ=";
  };

  cargoHash = "sha256-eaWUJQS2gT9XmfY1z39LG1S+WlEL8+72srWkncU9AVI=";
  useFetchCargoVendor = true;

  # Disable fetching and building of tree-sitter grammars in favor of the custom build process in grammars.nix
  env.HELIX_DISABLE_AUTO_GRAMMAR_BUILD = "1";

  nativeBuildInputs = [
    git
    installShellFiles
    makeWrapper
  ];

  postInstall =
    let
      grammarPath = callPackage "${src}/grammars.nix" { };
    in
    ''
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
    maintainers = with maintainers; [
      danth
      yusdacra
      zowoq
    ];
  };
}
