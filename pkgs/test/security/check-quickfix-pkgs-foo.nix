{ stdenv, name ? "foo-1.0.0" }:

stdenv.mkDerivation rec {
  inherit name;

  buildInputs = [ ];
  buildCommand = ''
    mkdir -p $out

    touch $out/installed
    echo ${name} >> $out/installed

    touch $out/dependency
    echo $out >> $out/dependency
  '';

  meta = with stdenv.lib; {
    homepage = https://nixos.org/;
    description = "Test case";
    longDescription = "Test case";
    license = licenses.mit;
    maintainers = [ maintainers.pierron ];
    platforms = platforms.all;
  };
}
