{ pkgs, ... }:
let
  py-slvs =
    pythonPkgs:
    pythonPkgs.buildPythonPackage {
      pname = "py-slvs";
      version = "1.0.6";

      src = pythonPkgs.fetchPypi {
        pname = "py_slvs";
        version = "1.0.6";
        sha256 = "sha256-U6T/aXy0JTC1ptL5oBmch0ytSPmIkRA8XOi31NpArnI=";
      };

      nativeBuildInputs = with pkgs; [ swig ];
      pyproject = true;

      propagatedBuildInputs = with pythonPkgs; [
        cmake
        ninja
        setuptools
        scikit-build
      ];

      dontUseCmakeConfigure = true;

      meta = with pkgs.lib; {
        description = "Python binding of SOLVESPACE geometry constraint solver";
        homepage = "https://github.com/realthunder/slvs_py";
        license = licenses.gpl3;
      };
    };

  blenderWithPySlvs = pkgs.blender.withPackages (p: [ (py-slvs p) ]);
  blender = blenderWithPySlvs.overrideAttrs (_: {
    pname = "blender";
  });
in
blender
