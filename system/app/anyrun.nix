{pkgs}:
pkgs.rustPlatform.buildRustPackage rec {
  pname = "anyrun";
  version = "unstable-2023-12-01";

  src = pkgs.fetchFromGitHub {
    owner = "kirottu";
    repo = "anyrun";
    rev = "e14da6c37337ffa3ee1bc66965d58ef64c1590e5";
    hash = "sha256-hI9+KBShsSfvWX7bmRa/1VI20WGat3lDXmbceMZzMS4=";
  };

  cargoHash = "sha256-4OuMSwkj1qesF22qMCGaECMDu7ZHPk72+2jm24qcs2Y=";

  strictDeps = true;
  enableParallelBuilding = true;
  doCheck = true;

  nativeBuildInputs = [
    pkgs.pkg-config
    pkgs.wrapGAppsHook
  ];

  buildInputs =
    [
      pkgs.atk
      pkgs.cairo
      pkgs.gdk-pixbuf
      pkgs.glib
      pkgs.gtk3
      pkgs.gtk-layer-shell
      pkgs.pango
    ]
    ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
      pkgs.darwin.apple_sdk.frameworks.Security
    ]
    ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
      pkgs.wayland
    ];

  preFixup = ''
    gappsWrapperArgs+=(
     --prefix ANYRUN_PLUGINS : $out/lib
    )
  '';

  postInstall = ''
    install -Dm444 anyrun/res/style.css examples/config.ron -t $out/share/doc/${pname}/examples/
  '';

  passthru.updateScript = pkgs.unstableGitUpdater {};

  meta = {
    description = "A wayland-native, highly customizable runner";
    homepage = "https://github.com/kirottu/anyrun";
    license = pkgs.lib.licenses.gpl3Only;
    maintainers = with pkgs.lib.maintainers; [eclairevoyant NotAShelf];
    mainProgram = "anyrun";
    platforms = pkgs.lib.platforms.linux ++ pkgs.lib.platforms.darwin;
  };
}
