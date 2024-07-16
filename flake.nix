{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.napalm.url = "github:nix-community/napalm";

  # NOTE: This is optional, but is how to configure napalm's env
  inputs.napalm.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, napalm }: 
  let
    system = "aarch64-darwin";
  in {
    # Assuming the flake is in the same directory as package-lock.json
    packages."${system}".next-app = napalm.legacyPackages."${system}".buildPackage ./. { };
  };
}