{ stdenv, fetchurl, zlib, readline }:

let version = "9.0.8"; in

stdenv.mkDerivation rec {
  name = "postgresql-${version}";
  
  src = fetchurl {
    url = "mirror://postgresql/source/v${version}/${name}.tar.bz2";
    sha256 = "1hhb9kaayrs3bqm1afg8g4p9mr3mc8hskrgy24hnwfablsl1p652";
  };

  buildInputs = [ zlib readline ];

  LC_ALL = "C";

  passthru = {
    inherit readline;
    psqlSchema = "9.0";
  };

  meta = {
    homepage = http://www.postgresql.org/;
    description = "A powerful, open source object-relational database system";
    license = "bsd";
  };
}
