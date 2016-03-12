
let
  processAllPackagesArgs = {defaultScope, ...}: rec {
    lib = import ../../../lib;
    callPackage = lib.callPackageWith defaultScope;
  };

  defaultPackages = {
    allPackages = x: import ../../../pkgs/top-level/all-packages.nix x // (
      with (processAllPackagesArgs x); {
        foo = callPackage ./check-quickfix-pkgs-foo.nix { };
        bar = callPackage ./check-quickfix-pkgs-bar.nix { }; # depends on foo
        baz = callPackage ./check-quickfix-pkgs-baz.nix { }; # depends on bar
        qux = callPackage ./check-quickfix-pkgs-qux.nix { }; # depends on baz
      });
    aliasedPackages = import ../../../pkgs/top-level/all-packages-aliases.nix;
  };

  # Only change the foo package which is used explicitly by bar, and
  # indirectly by baz.
  quickfixPackages = {
    allPackages = x: defaultPackages.allPackages x // (
      with (processAllPackagesArgs x); {
        bar = callPackage ./check-quickfix-pkgs-bar.nix {
          name = "bar-1.0.1";
        };
      });
    aliasedPackages = defaultPackages.aliasedPackages;
  };

  withoutFix = import ../../../. {
    inherit defaultPackages quickfixPackages;
    useQuickfix = false;
  };

  withFix = import ../../../. {
    inherit defaultPackages quickfixPackages;
    useQuickfix = true;
  };

in

  withoutFix.stdenv.mkDerivation {
    name = "check-quickfix";
    buildInputs = [];
    buildCommand = ''
      set -x;

      : Check that fixes are correctly applies:
      test ${withoutFix.foo} = ${withFix.foo}
      test \! ${withoutFix.bar} = ${withFix.bar}
      test \! ${withoutFix.baz} = ${withFix.baz}
      test \! ${withoutFix.qux} = ${withFix.qux}

      : Sanity checks
      grep -q ${withoutFix.foo} ${withoutFix.bar}/dependency
      grep -q ${withoutFix.foo.name} ${withoutFix.bar}/installed
      grep -q ${withoutFix.foo} ${withoutFix.baz}/dependency
      grep -q ${withoutFix.foo.name} ${withoutFix.baz}/installed
      grep -q ${withoutFix.foo} ${withoutFix.qux}/dependency
      grep -q ${withoutFix.foo.name} ${withoutFix.qux}/installed

      grep -q ${withoutFix.bar} ${withoutFix.baz}/dependency
      grep -q ${withoutFix.bar.name} ${withoutFix.baz}/installed
      grep -q ${withoutFix.bar} ${withoutFix.qux}/dependency
      grep -q ${withoutFix.bar.name} ${withoutFix.qux}/installed

      grep -q ${withoutFix.baz} ${withoutFix.qux}/dependency
      grep -q ${withoutFix.baz.name} ${withoutFix.qux}/installed

      : Check that fixes involve recompilation of fixed packages:
      grep -q ${withFix.bar} ${withFix.bar}/dependency
      grep -q ${withFix.bar.name} ${withFix.bar}/installed

      : Check that fixes do not involve recompilation of dependent packages:
      grep -q ${withFix.bar} ${withFix.baz}/dependency
      grep -q ${withoutFix.bar.name} ${withFix.baz}/installed
      grep -q ${withFix.baz} ${withFix.qux}/dependency
      grep -q ${withoutFix.baz.name} ${withFix.qux}/installed

      : Check that fixes are applied transitively:
      grep -q ${withFix.bar} ${withFix.qux}/dependency
      grep -q ${withoutFix.bar.name} ${withFix.qux}/installed

      mkdir -p $out
      echo success > $out/result
    '';
  }
