# This file contains an introspection of Nixpkgs.  This introspection
# returns a list of path to packages, which are known to be written in a
# manner which prevents them from being patched with quick fixes.
#
# The returned list looks as follow:
#
# [ { path = "abc"; error = "Alias parent derivations."; value = <CODE>; }
#   { path = "agda"; error = "Use callPackage without a derivation."; value = <CODE>; }
#   ...
# ]
#

let
  # Load Nixpkgs without any additional wrapping.
  pkgs = import ../../../. { useQuickfix = false; };
  pkgsFun = pkgs.__unfix__;

  # Annotate all derivations which are built with the original recipe.
  #
  # The goal of the "_isOriginalDerivation" tag is to detect aliases to the
  # original set of packages, and thus non-patched version of the packages.
  #
  # If after iterating one extra step we still get the original derivation,
  # this means that the patching mechanism used to apply security patches
  # will not work.
  #
  annotateOriginalPkgs = with pkgs.lib; pkgs:
    let
      recursiveConvertToFake = attrs:
        mapAttrsRecursiveCond
          (as: !isDerivation as) (path: maybeConvertToFake path)
          attrs;

      convertToFake = path: value:
        if isDerivation value then
          # assert __trace (["convertToFake::"] ++ path) true;
          (mapAttrs (name: maybeConvertToFake (path ++ [".drv" name])) value)
          // { _isOriginalDerivation = true; }
        else if isFunction value then
          x: maybeConvertToFake (path ++ [">"]) (value x)
        else
          value;

      maybeConvertToFake = path: value:
        let res = builtins.tryEval (convertToFake path value); in
        if res.success then res.value
        else value;
    in
      recursiveConvertToFake pkgs // {
        # We don't want to patch callPackages, but the override function
        # returned by it.
        inherit (pkgs) callPackage callPackages callPackage_i686;
      };

  # The way security updates are made relies on one extra evaluation of
  # Nixpkgs beyond the original fix-point. This function does the same,
  # except that before doing the extra evaluation, we flag all derivations
  # coming from the fix-point.
  #
  stepOne = pkgs.lib.recursiveUpdate (pkgsFun (annotateOriginalPkgs pkgs)) {
    # Prevent infinite recursions within the following attributes:
    allStdenvs = null;
    pkgs = null;
    pkgsi686Linux = {
      allStdenvs = null;
      pkgs = null;
      pkgsi686Linux = null;
    };
  };


  /* Recursively collect sets that verify a given predicate named `pred'
     from the set `attrs'.  The recursion is stopped when the predicate is
     verified.

     Type:
       collectWithPath ::
         (AttrSet -> Bool) -> AttrSet -> [x]

     Example:
       collectWithPath isList { a = { b = ["b"]; }; c = [1]; }
       => [ { path = ["a" "b"]; value = ["b"]; }
            { path = ["c"]; value = [1]; }
          ]

       collectWithPath (x: x ? outPath)
          { a = { outPath = "a/"; }; b = { outPath = "b/"; }; }
       => [ { path = ["a"]; value = { outPath = "a/"; }; }
            { path = ["b"]; value = { outPath = "b/"; }; }
          ]
  */
  maybeCollectWithPath = pred: attrs: with pkgs.lib;
    let
      collectInternal = path: attrs:
        # assert __trace (["maybeCollectWithPath::"] ++ path) true;
        if pred attrs then
          [ { path = concatStringsSep "." path; value = attrs; } ]
        else if isAttrs attrs then
          concatMap (name: maybeCollectInternal (path ++ [name]) attrs.${name})
            (attrNames attrs)
        else
          [];

       maybeCollectInternal = path: attrs:
         # Some evaluation of isAttrs might raise an assertion while
         # evaluating Nixpkgs, tryEval is used to work-around this issue.
         let res = builtins.tryEval (collectInternal path attrs); in
         if res.success then res.value
         else [];

    in
      maybeCollectInternal [] attrs;

  # Collect all references to potential security issues.
  collectPotentialIssues = with pkgs.lib; pkgs:
    let
      isCallPackage = attrs: isAttrs attrs && attrs ? originalArgs;
      mightBeAnIssue = attrs: isDerivation attrs || isCallPackage attrs;
    in
      maybeCollectWithPath mightBeAnIssue pkgs;

  # Look at the aggregated result from collectPotentialIssues, and map the
  # result to the corresponding error message, and return a list of all the
  # error messages related to security issues.
  securityIssues = with pkgs.lib;
    let
      isOriginalDrvAlias = drv:
        isDerivation drv && (drv._isOriginalDerivation or false);
      isCallPackageWithoutPackage = drv:
        !isDerivation drv && (isAttrs drv && drv ? originalArgs);
      isPackageWithoutCallPackage = drv:
        isDerivation drv && !(drv ? originalArgs);

      asErrorMessage = {path, value}@elem:
        if isOriginalDrvAlias value then
          "Alias parent derivations."
        else if isCallPackageWithoutPackage value then
          "Use callPackage without a derivation."
        else if isPackageWithoutCallPackage value then
          "The derivation does not have any argument list."
        else
          null;

      addErrorMessage = e: {
        inherit (e) path value;
        error = asErrorMessage e;
      };
    in
      filter (e: e.error != null) (
        map addErrorMessage (
          collectPotentialIssues stepOne));

  # Debug function which prints the list of known issues which can be
  # checked statically.
  displayIssues = issues: with pkgs.lib;
    assert __trace (''List of ${toString (length issues)} security issues:

    '' + concatMapStringsSep "\n" (e: "${e.path}: ${e.error}") issues
    ) true;
    issues;

in
  /* displayIssues */ securityIssues
