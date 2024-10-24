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
  version = "24.07-dev";

  src = fetchFromGitHub {
    owner = "helix-editor";
    repo = "helix";
    rev = "101a74bf6edbbfdf9b0628a0bdbbc307ebe10ff2";
    sha256 = "sha256-x8qkGujBPuOefXPyjcaB8Ot0IYkQBy6O2ZYb8NrnB3k=";
  };

  cargoHash = "sha256-HbO1EWDlsOaXvKEXhwPoVw7XaJw+hVAvH8ayQ7Gxh+Q=";

  # disable fetching and building of tree-sitter grammars in favor of the custom build process in grammars.nix
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
