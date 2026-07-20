{
  description = "dash-mcp spike — fleet-wide mission dashboard + MCP hooks";

  inputs = {
    # Pinned to the same nixpkgs the parent nixos-config flake locks (avoids
    # GitHub API rate limits — fetched from releases.nixos.org).
    nixpkgs.url = "https://releases.nixos.org/nixpkgs/nixpkgs-26.05pre942631.fef9403a3e4d/nixexprs.tar.xz";
  };

  outputs =
    { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAll = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAll (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            buildInputs = [
              pkgs.bun
              pkgs.nodejs_22
              pkgs.process-compose
              pkgs.sqld
              pkgs.sqlite
              pkgs.jq
              pkgs.curl
            ];

            shellHook = ''
              export DASH_MCP_ROOT="$PWD"
              echo "dash-mcp devshell: bun $(bun --version), node $(node --version)"
            '';
          };
        });
    };
}
