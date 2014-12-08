# This file was auto-generated by cabal2nix. Please do NOT edit manually!

{ cabal, cereal, cpphs, deepseq, haskellSrcExts, mtl, pureCdb
, testSimple, uniplate, Unixutils, vector
}:

cabal.mkDerivation (self: {
  pname = "hscope";
  version = "0.4.1";
  sha256 = "1m5mp45pvf64pnpc3lsig382177vfc232bbm9g3a8q58jrwridy7";
  isLibrary = false;
  isExecutable = true;
  buildDepends = [
    cereal cpphs deepseq haskellSrcExts mtl pureCdb uniplate vector
  ];
  testDepends = [ mtl testSimple Unixutils ];
  meta = {
    homepage = "https://github.com/bosu/hscope";
    description = "cscope like browser for Haskell code";
    license = self.stdenv.lib.licenses.bsd3;
    platforms = self.ghc.meta.platforms;
  };
})
