{
  pkgs,
  lib,
  python3,
}:
pkgs.stdenv.mkDerivation rec {
  pname = "mitype";
  version = "0.2.5";

  src = pkgs.fetchFromGitHub {
    owner = "Mithil467";
    repo = "mitype";
    rev = "cdb2da1f40611f6e44ccba50eccd135b3a503bc3";
    hash = "sha256-6jq5P1lC/C3D14l/djCTgaKPqOTJpn4EMBh2IvajiTs=";
  };

  buildInputs = [ python3 ];

  installPhase = ''
    mkdir -p $out/bin
    echo "#!/usr/bin/env bash" > $out/bin/mitype
    echo "cd ${src}" >> $out/bin/mitype
    echo '${python3}/bin/python -m mitype "$@"' >> $out/bin/mitype
    chmod +x $out/bin/mitype
  '';

  meta = with lib; {
    description = " Typing speed test in terminal ";
    homepage = "https://github.com/Mithil467/mitype";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
  };
}
