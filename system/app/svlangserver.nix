{ pkgs }:
let
  lib = pkgs.lib;
  buildNpmPackage = pkgs.buildNpmPackage;
  fetchFromGitHub = pkgs.fetchFromGitHub;
in
buildNpmPackage rec {
  pname = "svlangserver";
  version = "0.4.1+git";

  src = fetchFromGitHub {
    owner = "imc-trading";
    repo = pname;
    rev = "7f53c7f3394447bdd06de9566cd7240aa6cf0c8e";
    hash = "sha256-tVaRlISH6godtWFtUlIYJ55mIkTFN9dCDsGjcByp3Us=";
  };

  npmDepsHash = "sha256-7j9TE1QkqymOWKjE1tSA8n9AJ2nSyjQoDq/8jptIPwY=";

  # The prepack script runs the build script, which we'd rather do in the build phase.
  npmPackFlags = [ "--ignore-scripts" ];

  #NODE_OPTIONS = "--openssl-legacy-provider";

  meta = with lib; {
    description = "A language server for systemverilog that has been tested to work with coc.nvim, VSCode, Sublime Text 4, emacs, and Neovim";
    homepage = "https://github.com/imc-trading/svlangserver";
    license = licenses.mit;
    maintainers = with maintainers; [ wentasah ];
  };
}
