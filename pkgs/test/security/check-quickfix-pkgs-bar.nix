{ stdenv, foo, name ? "bar-1.0.0" }:

stdenv.mkDerivation rec {
  inherit name;

  buildInputs = [ foo ];
  buildCommand = ''
    mkdir -p $out

    touch $out/installed
    cat ${foo}/installed >> $out/installed
    echo ${name} >> $out/installed

    touch  $out/dependency
    cat ${foo}/dependency >> $out/dependency
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
