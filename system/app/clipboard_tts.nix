{pkgs}: let
  dataFile = pkgs.fetchurl {
    url = "https://huggingface.co/rhasspy/piper-voices/blob/v1.0.0/en/en_GB/jenny_dioco/medium/en_GB-jenny_dioco-medium.onnx";
    sha256 = "";
  };
  jsonFile = pkgs.fetchurl {
    url = "https://huggingface.co/rhasspy/piper-voices/blob/v1.0.0/en/en_GB/jenny_dioco/medium/en_GB-jenny_dioco-medium.onnx.json";
    sha256 = "";
  };
  rvcFile = pkgs.fetchzip {
    url = "https://huggingface.co/Dolyfin/RVC2Models/blob/main/AmberEN4.0_e210_s23520.zip";
    sha256 = "";
  };
in
  pkgs.stdenv.mkDerivation {
    name = "clipboard_tts";
    propagatedBuildInputs = [
      pkgs.ffmpeg-full # full version for ffplay
      pkgs.piper-tts
      pkgs.wl-clipboard
      (pkgs.stdenv.lib.python3.withPackages (pythonPackages:
        with pythonPackages; [
          clipboard
          requests
          gradio_client
        ]))
    ];
    dontUnpack = true;

    shellHook = ''
      export MODEL_PATH=$out/${dataFile.name}
      export RVC_COMMAND=$out/rvc_api/infer.py
      export RVC_MODEL=$out/${rvcFile.name}
      export RVC_INDEX=$out/${rvcFile.index}
    '';

    installPhase = ''
      mkdir -p $out/bin
      cp ${../scripts/python/clipboard_tts.py} $out
      cp ${dataFile} $out
      cp ${rvcFile}  $out
      cp ${jsonFile} $out
      ln -s $out/clipboard_tts.py $out/bin/clipboard_tts
      chmod +x $out/bin/clipboard_tts
    '';
  }
