# This file was auto-generated by cabal2nix. Please do NOT edit manually!

{ cabal, filepath, gtk3, mtl, text, vcswrapper }:

cabal.mkDerivation (self: {
  pname = "vcsgui";
  version = "0.1.0.0";
  sha256 = "0wxalzil8ypvwp0z754m7g3848963znwwrjysdxp5q33imzbp60z";
  isLibrary = true;
  isExecutable = true;
  buildDepends = [ filepath gtk3 mtl text vcswrapper ];
  meta = {
    homepage = "https://github.com/forste/haskellVCSGUI";
    description = "GUI library for source code management systems";
    license = "GPL";
    platforms = self.stdenv.lib.platforms.linux;
  };
})
