{pkgs, ...}: let
  git_original = pkgs.git.overrideAttrs (oldAttrs: {
    pname = "git_original";
    postInstall =
      oldAttrs.postInstall
      or ""
      + ''
        ln -s $out/bin/git $out/bin/git_original
      '';
  });
in
  pkgs.stdenv.mkDerivation {
    name = "git_cached";

    propagatedBuildInputs = with pkgs; [
      python3
      git_original
    ];

    nativeBuildInputs = [pkgs.makeWrapper];

    dontUnpack = true;
    installPhase = ''
      install -Dm755 ${../scripts/python/git_cached.py} $out/bin/git;
      wrapProgram $out/bin/git --prefix PATH : ${pkgs.lib.makeBinPath [git_original]}
    '';
  }
