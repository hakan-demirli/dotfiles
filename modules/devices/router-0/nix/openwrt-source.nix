{ pkgs }:
let
  upstreamRev = "07a5e432c83aa5c5b8ef21caf84fc1d051dfcadc";

  src = pkgs.fetchFromGitHub {
    owner = "openwrt";
    repo = "openwrt";
    rev = upstreamRev;
    hash = "sha256-OcbWmSi2fpZiCgPeR+E87kc4odbtrG7WcgoVRilRZwg=";
  };
in
pkgs.runCommand "openwrt-source-be10000"
  {
    nativeBuildInputs = [
      pkgs.git
      pkgs.gnupatch
    ];
    passthru = {
      inherit upstreamRev;
      patchSet = ../openwrt/patches;
    };
  }
  ''
    cp -r --no-preserve=mode,ownership ${src} $out
    chmod -R u+w $out
    cd $out

    # `git apply` needs a git repo. Initialise an ephemeral one.
    git init -q .
    git config user.name  openwrt-be10000
    git config user.email openwrt-be10000@local
    git add -A
    git -c gc.auto=0 commit -q -m "upstream openwrt @ ${upstreamRev}"

    for patch in ${../openwrt/patches}/*.patch; do
      echo "applying $(basename "$patch")"
      git -c user.name=local -c user.email=local@be10000 am --keep-cr "$patch"
    done

    # Strip git internals. The downstream build doesn't need them, and they
    # bloat the closure.
    rm -rf .git
  ''
