{pkgs}: let
  dataFile = pkgs.fetchurl {
    url = "https://huggingface.co/rhasspy/piper-voices/blob/v1.0.0/en/en_GB/jenny_dioco/medium/en_GB-jenny_dioco-medium.onnx";
    sha256 = "";
  };
  jsonFile = pkgs.fetchurl {
    url = "https://huggingface.co/rhasspy/piper-voices/blob/v1.0.0/en/en_GB/jenny_dioco/medium/en_GB-jenny_dioco-medium.onnx.json";
    sha256 = "";
  };
in
  pkgs.stdenv.mkDerivation {
    name = "clipboard_tts";
    propagatedBuildInputs = [
      (pkgs.stdenv.lib.python3.withPackages (pythonPackages:
        with pythonPackages; [
          clipboard
          requests
          gradio_client
        ]))
    ];
    dontUnpack = true;

    src = ../scripts/python/clipboard_tts;

    installPhase = ''
      mkdir -p $out/bin
      cp -r $src/* $out/
      cp ${dataFile} $out/src/
      cp ${jsonFile} $out/src/
      ln -s $out/clipboard_tts.py $out/bin/clipboard_tts
      chmod +x $out/bin/clipboard_tts
    '';
  }
