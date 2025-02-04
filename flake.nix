{
  description = "Shovel indexer flake for indexing V3 events on Base and Mainnet";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    # Select the correct binary URL based on the system.
    binaryURL =
      if system == "x86_64-linux" then "https://indexsupply.net/bin/1.6/linux/amd64/shovel"
      else if system == "x86_64-darwin" then "https://indexsupply.net/bin/1.6/darwin/amd64/shovel"
      else builtins.throw "Unsupported system: ${system}";
  in {
    # Development shell with runtime environment variables.
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [ pkgs.curl ];
      shellHook = ''
        export PG_URL="postgres://username:password@localhost:5432/shovel"
        export MAINNET_RPC="http://reth-node:8545"
        export BASE_RPC="http://base-node:8545"
        # Set these to the block numbers from ~7 days ago.
        export MAINNET_START_BLOCK="17000000"
        export BASE_START_BLOCK="10000000"
        export MY_CONTRACT_ADDRESS="0xYourContractAddressHere"
        echo "Environment variables set: PG_URL, MAINNET_RPC, BASE_RPC, MAINNET_START_BLOCK, BASE_START_BLOCK, MY_CONTRACT_ADDRESS"
      '';
    };

    # Package that "installs" the Shovel binary and config.
    packages.${system}.shovelIndexer = pkgs.stdenv.mkDerivation {
      pname = "shovel-indexer";
      version = "1.0";
      src = null;  # no source; we simply download the binary.
      buildInputs = [ pkgs.curl ];
      installPhase = ''
        mkdir -p $out/bin
        # Use an if-then-else expression to allow an override via SHOVEL_BINARY_URL.
        curl -L -o $out/bin/shovel "${toString (if builtins.getEnv "SHOVEL_BINARY_URL" == "" then binaryURL else builtins.getEnv "SHOVEL_BINARY_URL")}"
        chmod +x $out/bin/shovel
        cp ${./shovel-config.json} $out/bin/shovel-config.json
      '';
      meta = {
        description = "Shovel indexer binary with configuration";
      };
    };

    # An application that runs the indexer.
    apps.${system}.shovel = {
      type = "app";
      program = "${self.packages.${system}.shovelIndexer}/bin/shovel -config ${self.packages.${system}.shovelIndexer}/bin/shovel-config.json";
    };

    # Provide a default package attribute for this system.
    defaultPackage.${system} = self.packages.${system}.shovelIndexer;
  };
}
