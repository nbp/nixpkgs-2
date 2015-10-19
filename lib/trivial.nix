rec {

  # Identity function.
  id = x: x;

  # Constant function.
  const = x: y: x;

  # Named versions corresponding to some builtin operators.
  concat = x: y: x ++ y;
  or = x: y: x || y;
  and = x: y: x && y;
  mergeAttrs = x: y: x // y;

  # Take a function and evaluate it with its own returned value.
  fix = f: let x = f x; in x;

  # Like fix but with a way to escape the recursion
  fix' = f: let x = f x // { __unfix__ = f; }; in x;

  # Given a fix-able function and an overriding
  # function, this applies the overrides and
  # returns another fix-able function
  extend = rattrs: f: self: let super = rattrs self; in super // f self super;

  # Flip the order of the arguments of a binary function.
  flip = f: a: b: f b a;

  # Pull in some builtins not included elsewhere.
  inherit (builtins)
    pathExists readFile isBool isFunction
    isInt add sub lessThan
    seq deepSeq genericClosure;

  # Return the Nixpkgs version number.
  nixpkgsVersion =
    let suffixFile = ../.version-suffix; in
    readFile ../.version
    + (if pathExists suffixFile then readFile suffixFile else "pre-git");

  # Whether we're being called by nix-shell.
  inNixShell = builtins.getEnv "IN_NIX_SHELL" == "1";

  # Return minimum/maximum of two numbers.
  min = x: y: if x < y then x else y;
  max = x: y: if x > y then x else y;

}
