# This file was auto-generated by cabal2nix. Please do NOT edit manually!

{ cabal, aeson, async, autoUpdate, blazeBuilder, blazeHtml
, blazeMarkup, caseInsensitive, cereal, clientsession, conduit
, conduitExtra, cookie, dataDefault, deepseq, exceptions
, fastLogger, hspec, httpTypes, HUnit, liftedBase, monadControl
, monadLogger, mtl, mwcRandom, network, parsec, pathPieces
, primitive, QuickCheck, random, resourcet, safe, shakespeare
, streamingCommons, text, time, transformers, transformersBase
, unixCompat, unorderedContainers, vector, wai, waiExtra, waiLogger
, warp, word8
}:

cabal.mkDerivation (self: {
  pname = "yesod-core";
  version = "1.4.4.4";
  sha256 = "0l4a49a3y1m257zkzmvqwg5cm6shxzssgd143qqzhg1svikavv82";
  buildDepends = [
    aeson autoUpdate blazeBuilder blazeHtml blazeMarkup caseInsensitive
    cereal clientsession conduit conduitExtra cookie dataDefault
    deepseq exceptions fastLogger httpTypes liftedBase monadControl
    monadLogger mtl mwcRandom parsec pathPieces primitive random
    resourcet safe shakespeare text time transformers transformersBase
    unixCompat unorderedContainers vector wai waiExtra waiLogger warp
    word8
  ];
  testDepends = [
    async blazeBuilder conduit conduitExtra hspec httpTypes HUnit
    liftedBase mwcRandom network pathPieces QuickCheck random resourcet
    shakespeare streamingCommons text transformers wai waiExtra
  ];
  jailbreak = true;
  meta = {
    homepage = "http://www.yesodweb.com/";
    description = "Creation of type-safe, RESTful web applications";
    license = self.stdenv.lib.licenses.mit;
    platforms = self.ghc.meta.platforms;
  };
})
