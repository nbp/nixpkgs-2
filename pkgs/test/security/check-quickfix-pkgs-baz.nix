{ stdenv, bar, name ? "baz-1.0.0" }:

stdenv.mkDerivation rec {
  inherit name;

  buildInputs = [ bar ];
  buildCommand = ''
    mkdir -p $out

    touch $out/installed
    cat ${bar}/installed >> $out/installed
    echo ${name} >> $out/installed

    touch  $out/dependency
    cat ${bar}/dependency >> $out/dependency
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
