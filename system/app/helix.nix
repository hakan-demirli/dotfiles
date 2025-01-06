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
    owner = "tdaron";
    repo = "helix";
    rev = "c5a06ef8306c61dd16470deb1c020ea9a5fdb6e1";
    sha256 = "sha256-C0ylnLXsfis4L/XePk4udnNpI7m1zNPZ8NfZ5DmthyU=";
  };

  cargoHash = "sha256-UVlSb3TV2m4tXIOlDNZeOf7AWfglIdbkCwA1Xn+FotM=";

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
