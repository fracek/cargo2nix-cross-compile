{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
    cargo2nix.url = "github:cargo2nix/cargo2nix/release-0.11.0";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, cargo2nix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # setup overlay with stable rust.
        overlays = [
          (import rust-overlay)
          (import ./nix/overlay.nix { profile = "default"; })
          cargo2nix.overlays.default
        ];

        # update packages to use the current system and overlay.
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        rustPkgs = pkgs.rustBuilder.makePackageSet {
          packageFun = import ./Cargo.nix;
          rustToolchain = pkgs.rustVersion;
        };

        dockerizeCrateBin = { crate, volumes ? null, ports ? null }:
          pkgs.dockerTools.buildImage {
            name = crate.name;
            # we're publishing images, so make it less confusing
            tag = "latest";
            created = "now";
            copyToRoot = with pkgs.dockerTools; [
              usrBinEnv
              binSh
              caCertificates
            ];
            config = {
              Entrypoint = [
                "${crate.bin}/bin/${crate.name}"
              ];
              Volumes = volumes;
              ExposedPorts = ports;
            };
          };

        cross =
          let
            overlays = [
              (import rust-overlay)
              (import ./nix/overlay.nix {
                profile = "minimal";
                targets = [ "aarch64-unknown-linux-gnu" ];
              })
              cargo2nix.overlays.default
            ];

            pkgsCross = import nixpkgs {
              inherit system overlays;
              crossSystem = {
                config = "aarch64-unknown-linux-gnu";
              };
            };

            rustPkgsCross = pkgsCross.rustBuilder.makePackageSet {
              packageFun = import ./Cargo.nix;
              rustToolchain = pkgsCross.rustVersion;
            };
          in
          {
            my-app = rustPkgsCross.workspace.my-app { };
          };
      in
      {
        # format with `nix fmt`
        formatter = pkgs.nixpkgs-fmt;

        # development shells. start with `nix develop`.
        devShells = {
          default = rustPkgs.workspaceShell {
            LIBCLANG_PATH = pkgs.lib.makeLibraryPath [ pkgs.llvmPackages.libclang.lib ];
            nativeBuildInputs = with pkgs; [
              clang
              pkg-config
              llvmPackages.libclang
              protobuf
            ];
          };
        };

        packages = {
          inherit cross;

          # binaries
          my-app = rustPkgs.workspace.my-app { };
        };
      }
    );
}
