{
  rustPlatform,
  fetchFromGitHub,
  lib,

  installShellFiles,
  stdenv,
  darwin,

  imagemagick,
}:

rustPlatform.buildRustPackage rec {
  pname = "yazi";
  version = "git";

  src = fetchFromGitHub {
    owner = "sxyazi";
    repo = "yazi";
    rev = "f5598ebb8adf13b78e24b9456c9ae32605687817";
    hash = "sha256-OlJaVXv5YTzXG8ShEKK9XIs2LoUjG4VA7fvQwwTlL2g";
  };

  cargoLock.lockFile = "${src}/Cargo.lock";

  env.YAZI_GEN_COMPLETIONS = true;

  nativeBuildInputs = [
    installShellFiles
    imagemagick
  ];
  buildInputs = lib.optionals stdenv.isDarwin (with darwin.apple_sdk.frameworks; [ Foundation ]);

  postInstall = ''
    installShellCompletion --cmd yazi \
      --bash ./yazi-boot/completions/yazi.bash \
      --fish ./yazi-boot/completions/yazi.fish \
      --zsh  ./yazi-boot/completions/_yazi

    # Resize logo
    for RES in 16 24 32 48 64 128 256; do
      mkdir -p $out/share/icons/hicolor/"$RES"x"$RES"/apps
      magick assets/logo.png -resize "$RES"x"$RES" $out/share/icons/hicolor/"$RES"x"$RES"/apps/yazi.png
    done

    mkdir -p $out/share/applications
    install -m644 assets/yazi.desktop $out/share/applications/
  '';

  meta = with lib; {
    description = "Blazing fast terminal file manager written in Rust, based on async I/O";
    homepage = "https://github.com/sxyazi/yazi";
    license = licenses.mit;
    mainProgram = "yazi";
  };
}
