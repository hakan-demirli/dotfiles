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
    rev = "8325b9e394ebfeb501a3f1bb047bc15a87a0e0ab";
    sha256 = "sha256-MziJU6hxCmEWgjzslAaTEYsFVQFCVvgmuXNnlPjqoXQ=";
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
    torch
    torchaudio
    torchvision
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
