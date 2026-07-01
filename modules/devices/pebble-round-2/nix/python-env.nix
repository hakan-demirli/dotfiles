{
  pkgs,
}:
let
  ps = pkgs.python313Packages;

  nanopb = ps.buildPythonPackage rec {
    pname = "nanopb";
    version = "0.4.9.1";
    pyproject = true;

    src = ps.fetchPypi {
      inherit pname version;
      hash = "sha256-liRN5OQbmGrFd4GW5mcIGVutUD6V3s5dw6LnOVJ9fiY=";
    };

    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace-fail 'requires = ["poetry>=0.12"]' 'requires = ["poetry-core>=1.0.0"]' \
        --replace-fail 'build-backend = "poetry.masonry.api"' 'build-backend = "poetry.core.masonry.api"'
    '';

    build-system = [ ps.poetry-core ];
    dependencies = [ ps.protobuf ];

    doCheck = false;

    pythonImportsCheck = [ "nanopb.generator.nanopb_generator" ];
  };

  libclang-1811 = ps.buildPythonPackage rec {
    pname = "libclang";
    version = "18.1.1";
    format = "wheel";

    src = ps.fetchPypi {
      inherit pname version format;
      dist = "py2.py3";
      python = "py2.py3";
      abi = "none";
      platform = "manylinux2010_x86_64";
      hash = "sha256-xTMJHYo7v3RgoAy2wacdqTv/4UjxcsfQOxwx+/iqKgs=";
    };

    doCheck = false;
    pythonImportsCheck = [ "clang.cindex" ];
  };

  libpebble2 = ps.buildPythonPackage rec {
    pname = "libpebble2";
    version = "0.0.31";
    pyproject = true;

    src = ps.fetchPypi {
      inherit pname version;
      hash = "sha256-VWfxwt2VhodObxalNAuj/4gFPOvB+9poKUL44um29Mk=";
    };

    build-system = [ ps.setuptools ];
    dependencies = [
      ps.websocket-client
      ps.pyserial
      ps.six
    ];

    doCheck = false;

    pythonImportsCheck = [ "libpebble2" ];
  };
in
pkgs.python313.withPackages (p: [
  p.pillow
  p.freetype-py
  p.ply
  p.pyusb
  p.pyserial
  p.sh
  p.pypng
  p.pexpect
  p.cobs
  p.svg-path
  p.requests
  p.gitpython
  p.pyelftools
  p.pycryptodome
  p.mock
  p.bitarray
  p.pep8
  p.polib
  p.intelhex
  p.protobuf
  p.grpcio-tools
  p.kconfiglib
  p.meson
  p.ninja
  p.certifi
  p.packaging
  p.pyyaml
  p.prompt-toolkit

  p.websocket-client
  p.six

  nanopb
  libpebble2
  libclang-1811

  p.pip
  p.setuptools
  p.wheel
])
