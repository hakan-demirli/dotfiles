{
  pkgs,
  fetchFromGitHub,
}:

let
  pedalboard = pkgs.callPackage ./pedalboard.nix { };
  noisereduce = pkgs.callPackage ./noisereduce.nix { };
  local-attention = pkgs.callPackage ./local-attention.nix { };
in
pkgs.stdenv.mkDerivation rec {
  pname = "rvc-cli";
  version = "2.0";

  src = fetchFromGitHub {
    owner = "hakan-demirli";
    repo = "rvc-cli";
    rev = "47db4efaa62b711eb021db5a4b5da1750287ce31";
    sha256 = "sha256-OOMgbA3oGmOxLgoFAstci4HpJ269EYSaoKfi1k2xMRI=";
  };

  installPhase = ''
    mkdir -p $out/bin
    cp -r ${src}/* $out/

    cat <<EOF > $out/rvc_cli
    #!/usr/bin/env bash

    export PYTHONPATH=$PYTHONPATH:$out
    cd $out
    exec ${pkgs.python3Packages.python.interpreter} $out/rvc_cli.py "\$@"
    EOF

    ln -s $out/rvc_cli $out/bin/rvc_cli
    chmod +x $out/bin/rvc_cli
  '';

  propagatedBuildInputs = with pkgs.python3Packages; [
    numpy
    requests
    tqdm
    wget
    pydantic
    fastapi
    starlette
    ffmpeg-python
    faiss
    librosa
    pyworld
    scipy
    soundfile
    parselmouth
    numba
    # torch with cuda takes 8 hours to build! Using torch- bin instead
    # (torch.override { cudaSupport = enableCuda; })
    torch-bin
    torchvision-bin
    torchaudio-bin
    torchcrepe
    einops
    transformers
    matplotlib
    tensorboard
    gradio
    certifi
    antlr4-python3-runtime
    ffmpy
    tensorboardx
    pypresence
    beautifulsoup4
    flask
    samplerate
    six
    pydub
    onnx
    onnxruntime
    julius
    resampy
    beartype
    rotary-embedding-torch
    pedalboard
    noisereduce
    local-attention
  ];
}
