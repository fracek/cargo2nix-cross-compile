{ profile ? "default", targets ? [ ] }:
final: prev:

{
  rustVersion = prev.rust-bin.stable.latest.${profile}.override {
    inherit targets;
    extensions = [ "rust-src" ];
  };

  rustPlatform = prev.makeRustPlatform {
    cargo = final.rustVersion;
    rustc = final.rustVersion;
  };
}
