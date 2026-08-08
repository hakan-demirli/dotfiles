{
  pkgs,
  rev ? "99449603cc2e1cd94da9afb31160aa50e9ee8887",
  hash ? "sha256-cX9Ru9BolCyEBkqDwKDj838RgSpwqgmnx8sScDkmaSE=",
}:
pkgs.fetchFromGitHub {
  owner = "coredevices";
  repo = "PebbleOS";
  inherit rev hash;
  fetchSubmodules = true;
  leaveDotGit = false;
  passthru.upstreamRev = rev;
  passthru.upstreamTag = "v4.28.0";
}
