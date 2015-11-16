/* This file composes the Nix Packages collection.  That is, it
   imports the functions that build the various packages, and calls
   them with appropriate arguments.  The result is a set of all the
   packages in the Nix Packages collection for some particular
   platform. */


{ # The system (e.g., `i686-linux') for which to build the packages.
  system ? builtins.currentSystem

, # The standard environment to use.  Only used for bootstrapping.  If
  # null, the default standard environment is used.
  bootStdenv ? null

, # Non-GNU/Linux OSes are currently "impure" platforms, with their libc
  # outside of the store.  Thus, GCC, GFortran, & co. must always look for
  # files in standard system directories (/usr/include, etc.)
  noSysDirs ? (system != "x86_64-freebsd" && system != "i686-freebsd"
               && system != "x86_64-kfreebsd-gnu")

  # More flags for the bootstrapping of stdenv.
, gccWithCC ? true
, gccWithProfiling ? true

, # Allow a configuration attribute set to be passed in as an
  # argument.  Otherwise, it's read from $NIXPKGS_CONFIG or
  # ~/.nixpkgs/config.nix.
  config ? null

, crossSystem ? null
, platform ? null

  # This should be set to false when used by stdenv functions, which in the
  # end should not rely imports of this file.
, useQuickfix ? true
}:


let config_ = config; platform_ = platform; in # rename the function arguments

let

  lib = import ../../lib;

  # The contents of the configuration file found at $NIXPKGS_CONFIG or
  # $HOME/.nixpkgs/config.nix.
  # for NIXOS (nixos-rebuild): use nixpkgs.config option
  config =
    let
      toPath = builtins.toPath;
      getEnv = x: if builtins ? getEnv then builtins.getEnv x else "";
      pathExists = name:
        builtins ? pathExists && builtins.pathExists (toPath name);

      configFile = getEnv "NIXPKGS_CONFIG";
      homeDir = getEnv "HOME";
      configFile2 = homeDir + "/.nixpkgs/config.nix";

      configExpr =
        if config_ != null then config_
        else if configFile != "" && pathExists configFile then import (toPath configFile)
        else if homeDir != "" && pathExists configFile2 then import (toPath configFile2)
        else {};

    in
      # allow both:
      # { /* the config */ } and
      # { pkgs, ... } : { /* the config */ }
      if builtins.isFunction configExpr
        then configExpr { inherit pkgs; }
        else configExpr;

  # Allow setting the platform in the config file. Otherwise, let's use a reasonable default (pc)

  platformAuto = let
      platforms = (import ./platforms.nix);
    in
      if system == "armv6l-linux" then platforms.raspberrypi
      else if system == "armv7l-linux" then platforms.armv7l-hf-multiplatform
      else if system == "armv5tel-linux" then platforms.sheevaplug
      else if system == "mips64el-linux" then platforms.fuloong2f_n32
      else if system == "x86_64-linux" then platforms.pc64
      else if system == "i686-linux" then platforms.pc32
      else platforms.pcBase;

  platform = if platform_ != null then platform_
    else config.platform or platformAuto;

  # The complete set of packages, after applying the overrides
  pkgsFunWithOverride = packagesAttrs:
    lib.extend (lib.extend (pkgsFun packagesAttrs) stdenvOverrides) configOverrides;
  pkgs = lib.fix' (pkgsFunWithOverride defaultPackages);

  # List of paths that are used to build the stable channel.
  defaultPackages = {
    allPackages = import ./all-packages.nix;
    aliasedPackages = import ./all-packages-aliases.nix;
  };

  stdenvOverrides =
    # We don't want stdenv overrides in the case of cross-building,
    # or otherwise the basic overrided packages will not be built
    # with the crossStdenv adapter.
    if crossSystem == null
      then self: super: lib.optionalAttrs (super.stdenv ? overrides) (super.stdenv.overrides super)
      else self: super: {};

  # Packages can be overriden globally via the `packageOverrides'
  # configuration option, which must be a function that takes `pkgs'
  # as an argument and returns a set of new or overriden packages.
  # Each attribute in the `packageOverrides' function is called with
  # the *original* (un-overriden) attribute, if it exists, allowing
  # packageOverrides attributes to refer to the original attributes
  # (e.g. "foo = ... pkgs.foo ...").
  configOverrides =
      if config ? packageOverrides && bootStdenv == null # don't apply config overrides in stdenv boot
        then self: super: config.packageOverrides super
        else self: super: {};

  # Apply ABI compatible fixes, recompile every program with the
  # dependencies from the super set only and apply patches on the remaining
  # packages. This will recompile only programs which have changed in the
  # quickfix.
  maybeAbiCompatiblePatches = pkgs:
    if useQuickfix && builtins.pathExists ../../quickfix/pkgs/top-level/all-packages.nix then
      abiCompatiblePatches pkgs
    else
      # If there is no quickfix to apply, then there is no need for extra
      # overhead, in which case we just the fix-point of packages.
      pkgs;

  abiCompatiblePatches = pkgs: with lib;
    # assert builtins.trace "!!! Apply abiCompatiblePatches !!!" true;
    let
      # Additional list of packages which have ABI compatible fixes for the
      # stable packages. These are used by abiCompatiblePatches.
      quickfixPackages = {
        allPackages = import ../../quickfix/pkgs/top-level/all-packages.nix;
        aliasedPackages = import ../../quickfix/pkgs/top-level/all-packages-aliases.nix;
      };

      # Evaluate the set of packages from the quickfix index, with the
      # list of fixed-point packages.  These packages are unlikely to be
      # too different than the original list of packages, thus these
      # expressions should lead most of the time the same result as the
      # fixed point.
      quickFixPkgsFun = pkgsFunWithOverride quickfixPackages;

      patchDependencies = drv: hashesMap: pkgs.runCommand "quickfix-${drv.name}" { nixStore = "${pkgs.nix}/bin/nix-store"; } ''
        $nixStore --dump ${drv} | sed 's|${baseNameOf drv}|'$(basename $out)'|g;${
          concatStrings (mapAttrsToList (name: value:
            "'s|${baseNameOf name}|${baseNameOf value}|g';"
          ) hashesMap)
         } | $nixStore --restore $out
      '';

      # For each package, we check if we have the same dependencies.
      quickFixAsPatches = name: pkgs: quickfix: whatif:
        let
          # Note, we need to check the drv.outPath to add some strictness
          # to eliminate derivation which might assert when they are
          # evaluated.
          validDeps = name: drv:
            let res = builtins.tryEval (isDerivation drv && isString drv.outPath); in
            name != "_currentPackage" && res.success && res.value;

          differentDeps = x:
            # assert __trace "differentDeps: ${x.name}\n     :              : ${x.value} ?" true;
            x.name != x.value;

          # Based on the derivation, get the list of dependencies.
          #
          # :TODO: Optimize this function by only using runtime
          # dependencies of the original package set, and which are
          # computed ahead by the buildfamr.
          warnIfUnableToFindDeps = drv:
            if drv ? originalArgs then true
            else assert __trace "Security issue: Unable to locate dependencies of `${name}`." true; true;
          getDeps = drv:
            if drv ? originalArgs then filterAttrs validDeps drv.originalArgs
            else {};

          # This assumes that the originalArgs list are ordered the same
          # way, as they are both infered from the same files.
          hashesAssocList =
            let qDeps = getDeps quickfix; wDeps = getDeps whatif; in
            let names = attrNames qDeps; in
            assert warnIfUnableToFindDeps quickfix;
            # assert __trace "qDeps: ${toString (attrNames qDeps)}\ntrace: wDeps: ${toString (attrNames wDeps)}" true;
            assert names == attrNames wDeps;
            filter differentDeps (map (name: {
              name = builtins.unsafeDiscardStringContext (toString qDeps.${name});
              value = toString wDeps.${name};
            }) names);

          # If the name of the quickfix does not have the same
          # length, use the old name instead. This might cause a
          # problem if people do not use --leq while updating.
          quickfixRenamed =
            if stringLength pkgs.name == stringLength quickfix.name
            then quickfix
            else
              overrideDerivation quickfix ({
                name = pkgs.name;
              });
        in
          if length hashesAssocList != 0 then
            # One of the dependency is different.
            #throw "Is about to patch ${name}, because of ${showVal (listToAttrs hashesAssocList)}."
            patchDependencies quickfixRenamed (listToAttrs hashesAssocList)
          else
            quickfixRenamed;

      # Recursively decent into all packages until we reach a derivation,
      # in which case we execute the "f" function, otherwise, if we cannot
      # decide, such as in case of functions, then we execute the
      # "default" function with both arguments.
      zipQuickFixAsPatches = path: pkgs: quickfix: whatif:
        zipAttrsWith (name: values:
          # Somebody added / removed a packaged in quickfix?
          let pkgsName = concatStringsSep "." (path ++[name]); in
          # assert builtins.trace "zipQuickFixAsPatches (name: ${pkgsName})" true;
          assert builtins.length values == 3;
          let p = head values; q = head (tail values); w = head (tail (tail values)); in
          if name == "pkgs" then q # We should not recurse in the top-level pkgs argument.
          else if isAttrs p then
            assert isAttrs q && isAttrs w; # Do not mutate the derivation
            if isDerivation p then
              assert isDerivation q && isDerivation w;
              addErrorContext "While evaluating package ${pkgsName}" (quickFixAsPatches pkgsName p q w)
            else
              zipQuickFixAsPatches (path ++ [name]) p q w
          else
            q
        ) [pkgs quickfix whatif];

      # Pipeline of modification involved to apply security patches:
      #
      #  1. We apply security patches on top of the current set of packages.
      #
      #  2. We check what package would be recompiled, if we were to
      #     recompile instead of applying patches.
      #
      #  3. We only keep the set of packages where we only applied patches.
      #
      quickFix = quickFixPkgsFun pkgs;
      whatIf = quickFixPkgsFun abiSec;
      abiSec = zipQuickFixAsPatches ["pkgs"] pkgs quickFix whatIf;
    in
      abiSec;


  # The package compositions.  Yes, this isn't properly indented.
  pkgsFun = { allPackages, aliasedPackages }: pkgs:
    let
      defaultScope = pkgs // pkgs.xorg;
      helperFunctions = pkgs_.stdenvAdapters // pkgs_.trivial-builders;
      pkgsRet = helperFunctions // pkgs_;
      pkgs_ = allPackages {
        self = pkgs_;
        inherit pkgs system crossSystem platform bootStdenv noSysDirs
          gccWithCC gccWithProfiling config defaultScope helperFunctions;
      };

      aliases = aliasedPackages pkgs;
      tweakAlias = _n: alias: with lib;
        if alias.recurseForDerivations or false then
          removeAttrs alias ["recurseForDerivations"]
        else alias;

    in lib.mapAttrs tweakAlias aliases // pkgsRet;

in maybeAbiCompatiblePatches pkgs
