{
  pkgs,
}:
let
  readlinefzf = pkgs.stdenv.mkDerivation {
    pname = "readline-fzf-for-qalc";
    version = "0.1";
    src = ./libqalculate_fzf.c;
    buildInputs = [ pkgs.readline ];
    dontConfigure = true;
    dontUnpack = true;
    buildPhase = ''
      runHook preBuild
      $CC -shared -fPIC -o readline_fzf.so $src -lreadline
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm644 readline_fzf.so $out/lib/readline_fzf.so
      runHook postInstall
    '';
  };
in
pkgs.stdenv.mkDerivation {
  pname = pkgs.libqalculate.pname + "-fzf";
  version = pkgs.libqalculate.version;
  dontUnpack = true;
  nativeBuildInputs = [ pkgs.makeWrapper ];
  installPhase = ''
    mkdir -p $out/bin

    # Copy all binaries except qalc
    for bin in ${pkgs.libqalculate}/bin/*; do
      binname=$(basename "$bin")
      if [ "$binname" != "qalc" ]; then
        ln -s "$bin" "$out/bin/$binname"
      fi
    done

    # Create wrapped qalc
    makeWrapper ${pkgs.libqalculate}/bin/qalc $out/bin/qalc \
      --prefix LD_PRELOAD : "${readlinefzf}/lib/readline_fzf.so" \
      --prefix PATH : "${pkgs.lib.makeBinPath [ pkgs.fzf ]}"

    # Copy other directories if needed
    for dir in ${pkgs.libqalculate}/*; do
      dirname=$(basename "$dir")
      if [ "$dirname" != "bin" ]; then
        ln -s "$dir" "$out/$dirname"
      fi
    done
  '';
  passthru = pkgs.libqalculate.passthru;
}
