{ lib
, fetchFromGitHub
, rust-bin
, makeRustPlatform
, protobuf
, pkg-config
, openssl
, sqlite
}:

let
  rustChannel = "nightly";
  rustVersion = "2023-05-28";

  my-rust-bin = rust-bin."${rustChannel}"."${rustVersion}".default.override {
    extensions = [ "rust-analyzer" ];
  };

  rustPlatform = makeRustPlatform {
    rustc = my-rust-bin;
    cargo = my-rust-bin;
  };

in rustPlatform.buildRustPackage rec {
  pname = "buck2";
  version = "unstable-2023-07-13";

  src = fetchFromGitHub {
    owner = "facebook";
    repo = "buck2";
    rev = "21d9229a887170ea47a0f2f681cfa78092eb30c4";
    hash = "sha256-qGxwAJszMJ+OwgeCAwUT7Z4eUp4oZmdI8GiNuS0QVIA=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "perf-event-0.4.8" = "sha256-4OSGmbrL5y1g+wdA+W9DrhWlHQGeVCsMLz87pJNckvw=";
      "hyper-proxy-0.10.1" = "sha256-qxOJntADYGuBr9jnzWJjiC7ApnkmF2R+OdXBGL3jIw8=";
    };
  };

  BUCK2_BUILD_PROTOC = "${protobuf}/bin/protoc";
  BUCK2_BUILD_PROTOC_INCLUDE = "${protobuf}/include";

  nativeBuildInputs = [ protobuf pkg-config ];
  buildInputs = [ openssl sqlite ];

  doCheck = false;
  dontStrip = true; # XXX (aseipp): cargo will delete dwarf info but leave symbols for backtraces

  patches = [ /* None, for now */ ];

  # Put the Cargo.lock file in the build.
  postPatch = "cp ${./Cargo.lock} Cargo.lock";

  postInstall = ''
    mv $out/bin/buck2     $out/bin/buck
    ln -sfv $out/bin/buck $out/bin/buck2
    mv $out/bin/starlark  $out/bin/buck2-starlark
    mv $out/bin/read_dump $out/bin/buck2-read_dump
  '';
}
