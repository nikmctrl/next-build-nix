{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nix-filter.url = "github:numtide/nix-filter";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nix-filter, flake-utils }:
  let 
     pkgs = nixpkgs.legacyPackages.aarch64-darwin;
     nodejs = pkgs.nodejs-18_x;
  in
  {
    packages.aarch64-darwin.node_modules = pkgs.stdenv.mkDerivation {
      name = "node_modules";

      src = nix-filter {
        root = ./.;
        include = [
          ./package.json
          ./package-lock.json
        ];
      };

      # HACK: break the nix sandbox so we can fetch the dependencies. This
      # requires Nix to have `sandbox = relaxed` in its config.
      __noChroot = true;

      configurePhase = ''
        # NPM writes cache directories etc to $HOME.
        export HOME=$TMP
      '';

      buildInputs = [ nodejs ];

      # Pull all the dependencies
      buildPhase = ''
        ${nodejs}/bin/npm ci
      '';

      # NOTE[z]: The folder *must* be called "node_modules". Don't ask me why.
      #          That's why the content is not directly added to $out.
      installPhase = ''
        mkdir $out
        mv node_modules $out/node_modules
      '';
    };

    packages.aarch64-darwin.my-frontend = nixpkgs.stdenv.mkDerivation {
      name = "my-frontend";
      # Use the current folder as the input, without node_modules
      src = nix-filter {
        root = ./.;
        exclude = [
          ./.next
          ./node_modules
        ];
      };

      nativeBuildInputs = [ nodejs ];

      buildPhase = "npm run build";

      configurePhase = ''
        # Get the node_modules from its own derivation
        ln -sf ${self.packages.aarch64-darwin.node_modules}/node_modules node_modules
        export HOME=$TMP
      '';

      # TODO: move to different derivation
      doCheck = true;
      checkPhase = ''
        npm run test
      '';

      # This is specific to nextjs. Typically you would copy ./dist to $out or
      # something like that.
      installPhase = ''
        # Use the standalone nextjs version
        mv .next/standalone $out

        # Copy non-generated static files
        cp -R public $out/public

        # Also copy generated static files
        mv .next/static $out/.next/static

        # Re-link the node_modules
        rm $out/node_modules
        mv node_modules $out/node_modules

        # Wrap the script
        cat <<ENTRYPOINT > $out/entrypoint
        #!${pkgs.stdenv.shell}
        exec "$(type -p node)" "$out/server.js" "$$@"
        ENTRYPOINT
        chmod +x $out/entrypoint
      '';
    };
  };
}
