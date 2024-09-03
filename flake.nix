{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { 
        inherit system; 
        # config = {
        #   rocmSupport = true;
        # }; 
      };
      python-packages = ps: with ps; [
        torch
        tqdm
        sentence-transformers
        transformers
        psycopg
        aiofiles
        dask
        dask-expr
        distributed
        setproctitle
      ];
    in
    {
      devShell.${system} = pkgs.mkShell {
        buildInputs = with pkgs; with pkgs.python310Packages; [

          (pkgs.python3.withPackages python-packages)

          pyright
          black
          pip
          ipython
          coverage
        ];

        shellHook = ''
          ${pkgs.figlet}/bin/figlet "wikidata dump processing"

          cat << _EOF
Hello World!
_EOF
        '';
      };
    };
}
