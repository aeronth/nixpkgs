#!/usr/bin/env perl

use strict;
use warnings qw<all>;
use Getopt::Std;

my $gencmd = "# Generated by: " . join(" ", $0, @ARGV) . "\n";

our $opt_v;
our $opt_p;
our $opt_r;
our $opt_t;
getopts "v:p:t:r:";

my $OPAM_RELEASE = $opt_v // "2.0.0";
my $OPAM_TAG = $opt_t // $OPAM_RELEASE;
my $OPAM_GITHUB_REPO = $opt_r // "ocaml/opam";
my $OPAM_RELEASE_URL = "https://github.com/$OPAM_GITHUB_REPO/archive/$OPAM_TAG.zip";
my $OPAM_RELEASE_SHA256 = `nix-prefetch-url \Q$OPAM_RELEASE_URL\E`;
chomp $OPAM_RELEASE_SHA256;

my $OPAM_BASE_URL = "https://raw.githubusercontent.com/$OPAM_GITHUB_REPO/$OPAM_TAG";
my $OPAM_OPAM = `curl -L --url \Q$OPAM_BASE_URL\E/opam-devel.opam`;
my($OCAML_MIN_VERSION) = $OPAM_OPAM =~ /^  "ocaml" \{>= "(.*)"}$/m
  or die "could not parse ocaml version bound\n";

print <<"EOF";
{ stdenv, lib, fetchurl, makeWrapper, getconf,
  ocaml, unzip, ncurses, curl, bubblewrap, Foundation
}:

assert lib.versionAtLeast ocaml.version "$OCAML_MIN_VERSION";

let
  srcs = {
EOF

my %urls = ();
my %md5s = ();

open(SOURCES, "-|", "curl", "-L", "--url", "$OPAM_BASE_URL/src_ext/Makefile.sources");
while (<SOURCES>) {
  if (/^URL_(?!PKG_)([-\w]+)\s*=\s*(\S+)$/) {
    $urls{$1} = $2;
  } elsif (/^MD5_(?!PKG_)([-\w]+)\s*=\s*(\S+)$/) {
    $md5s{$1} = $2;
  }
}
for my $src (sort keys %urls) {
  my ($sha256,$store_path) = split /\n/, `nix-prefetch-url --print-path \Q$urls{$src}\E`;
  system "echo \Q$md5s{$src}\E' *'\Q$store_path\E | md5sum -c 1>&2";
  die "md5 check failed for $urls{$src}\n" if $?;
  print <<"EOF";
    "$src" = fetchurl {
      url = "$urls{$src}";
      sha256 = "$sha256";
    };
EOF
}

print <<"EOF";
    opam = fetchurl {
      url = "$OPAM_RELEASE_URL";
      sha256 = "$OPAM_RELEASE_SHA256";
    };
  };
in stdenv.mkDerivation {
  pname = "opam";
  version = "$OPAM_RELEASE";

  strictDeps = true;

  nativeBuildInputs = [ makeWrapper unzip ocaml curl ];
  buildInputs = [ ncurses getconf ]
    ++ lib.optionals stdenv.isLinux [ bubblewrap ]
    ++ lib.optionals stdenv.isDarwin [ Foundation ];

  src = srcs.opam;

  postUnpack = ''
EOF
for my $src (sort keys %urls) {
  my($ext) = $urls{$src} =~ /(\.(?:t(?:ar\.|)|)(?:gz|bz2?))$/
    or die "could not find extension for $urls{$src}\n";
  print <<"EOF";
    ln -sv \${srcs."$src"} \$sourceRoot/src_ext/$src$ext
EOF
}
print <<'EOF';
  '';

EOF
if (defined $opt_p) {
  print "  patches = [ ";
  for my $patch (split /[, ]/, $opt_p) {
    $patch =~ s/^(?=[^\/]*$)/.\//;
    print "$patch ";
  }
  print "];\n\n";
}
print <<'EOF';
  preConfigure = ''
    substituteInPlace ./src_ext/Makefile --replace "%.stamp: %.download" "%.stamp:"
    patchShebangs src/state/shellscripts
  '';

  postConfigure = "make lib-ext";

  # Dirty, but apparently ocp-build requires a TERM
  makeFlags = ["TERM=screen"];

  outputs = [ "out" "installer" ];
  setOutputFlags = false;

  # change argv0 to "opam" as a workaround for
  # https://github.com/ocaml/opam/issues/2142
  postInstall = ''
    mv $out/bin/opam $out/bin/.opam-wrapped
    makeWrapper $out/bin/.opam-wrapped $out/bin/opam \
      --argv0 "opam" \
      --suffix PATH : ${unzip}/bin:${curl}/bin:${lib.optionalString stdenv.isLinux "${bubblewrap}/bin:"}${getconf}/bin \
      --set OPAM_USER_PATH_RO /run/current-system/sw/bin:/nix/
    $out/bin/opam-installer --prefix=$installer opam-installer.install
  '';

  doCheck = false;

  meta = with lib; {
    description = "A package manager for OCaml";
    homepage = "https://opam.ocaml.org/";
    changelog = "https://github.com/ocaml/opam/raw/${version}/CHANGES";
    maintainers = [ maintainers.marsam ];
    license = licenses.lgpl21Only;
    platforms = platforms.all;
  };
}
EOF
print $gencmd;
