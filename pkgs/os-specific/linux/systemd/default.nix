{ stdenv, fetchurl, pkgconfig, intltool, gperf, libcap, udev, dbus, kmod
, xz, pam, acl, cryptsetup, libuuid, m4, utillinux, usbutils, pciutils
, glib
}:

stdenv.mkDerivation rec {
  name = "systemd-185";

  src = fetchurl {
    url = "http://www.freedesktop.org/software/systemd/${name}.tar.xz";
    sha256 = "1iwp41xvpq0x2flhhs8lpyjbfyg1220ahmy7037zdjy26w9g82br";
  };

  buildInputs =
    [ pkgconfig intltool gperf libcap udev dbus kmod xz pam acl
      cryptsetup libuuid m4 usbutils pciutils glib
    ];

  configureFlags =
    [ "--localstatedir=/var"
      "--sysconfdir=/etc"
      "--with-distro=other"
      "--with-rootprefix=$(out)"
      "--with-rootprefix=$(out)"
      "--with-dbusinterfacedir=$(out)/share/dbus-1/interfaces"
      "--with-dbuspolicydir=$(out)/etc/dbus-1/system.d"
      "--with-dbussystemservicedir=$(out)/share/dbus-1/system-services"
      "--with-dbussessionservicedir=$(out)/share/dbus-1/services"
    ];

  preConfigure =
    ''
      # FIXME: patch this in systemd properly (and send upstream).
      for i in src/remount-fs/remount-fs.c src/core/mount.c src/core/swap.c src/fsck/fsck.c; do
        test -e $i
        substituteInPlace $i \
          --replace /bin/mount ${utillinux}/bin/mount \
          --replace /bin/umount ${utillinux}/bin/umount \
          --replace /sbin/swapon ${utillinux}/sbin/swapon \
          --replace /sbin/swapoff ${utillinux}/sbin/swapoff \
          --replace /sbin/fsck ${utillinux}/sbin/fsck
      done
    '';

  installFlags = "localstatedir=$(TMPDIR)/var sysconfdir=$(out)/etc";

  # Get rid of configuration-specific data.
  postInstall =
    ''
      mkdir -p $out/example/systemd
      mv $out/lib/{modules-load.d,binfmt.d,sysctl.d,tmpfiles.d} $out/example
      mv $out/lib/systemd/{system,user} $out/example/systemd
    '';

  enableParallelBuilding = true;
  
  meta = {
    homepage = http://www.freedesktop.org/wiki/Software/systemd;
    description = "A system and service manager for Linux";
  };
}
