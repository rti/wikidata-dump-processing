{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-anywhere.url = "github:nix-community/nixos-anywhere/1.1.0";
    nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko/v1.3.0";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ... } @ inputs: 
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
        bokeh
        dask-expr
        distributed
        setproctitle
      ];

      specialArgs = {
        inherit inputs;
      };

      # ALWAYS sync with workerCount in main.tf
      workerCount = 3;

      manager-hostname = "dask-manager";
      worker-hostnames = builtins.genList (n: "dask-worker-${toString (n+1)}") workerCount;

      mkSystemConfig = hostname: modules: nixpkgs.lib.nixosSystem {
        inherit system;
        inherit pkgs;
        inherit specialArgs;
        modules = [
          inputs.disko.nixosModules.disko
          (import ./disko-config.nix)
          ({ ... }: {
            networking.hostName = hostname;
          })
        ] ++ modules;
      };
    in
    {
      nixosConfigurations = {
        "${manager-hostname}" = mkSystemConfig manager-hostname [
          ./manager-configuration.nix
        ];
        } // 
        nixpkgs.lib.genAttrs worker-hostnames (hostname: mkSystemConfig hostname [
          ./worker-configuration.nix
       ]);

      devShell.${system} = pkgs.mkShell {
        buildInputs = with pkgs; with pkgs.python3Packages; [

          (pkgs.python3.withPackages python-packages)

          pyright
          black
          pip
          ipython
          coverage
        ];

        packages = [
          inputs.disko.packages.x86_64-linux.disko
          inputs.nixos-anywhere.packages.x86_64-linux.nixos-anywhere
          (pkgs.opentofu.withPlugins (p: [ p.hcloud ]))
          pkgs.tmux


          (pkgs.writeShellScriptBin "provision" ''
            set -e
            tofu init -reconfigure
            tofu apply -var "hcloud_token=$(pass hetzner.com/dask-api-token)"
          '')

          (pkgs.writeShellScriptBin "bootstrap" ''
            set -e

            server_ip=$(cat "./public-ipv4-manager")
            nixos-anywhere --flake ".#dask-manager" "root@''${server_ip}" &

            for file in ./public-ipv4-worker-*; do
              server_ip=$(cat "$file")
              server_number=$(echo $file | sed 's/.*-\([0-9]\+\)$/\1/')
              server_name="dask-worker-''${server_number}"
              nixos-anywhere --flake ".#''${server_name}" "root@''${server_ip}" &
            done
            wait
          '')

          (pkgs.writeShellScriptBin "deploy" ''
            set -e

            server_ip=$(cat "./public-ipv4-manager")
            nixos-rebuild switch --flake ".#dask-manager" \
              --target-host root@"''${server_ip}" --use-substitutes &

            for file in ./public-ipv4-worker-*; do
              server_ip=$(cat "$file")
              server_number=$(echo $file | sed 's/.*-\([0-9]\+\)$/\1/')
              server_name="dask-worker-''${server_number}"
              nixos-rebuild switch --flake ".#''${server_name}" \
                --target-host root@"''${server_ip}" --use-substitutes &
            done
            wait
          '')

          (pkgs.writeShellScriptBin "shell" ''
            set -e

            tmux new-session -d -s servers

            server_ip=$(cat "./public-ipv4-manager")
            tmux split-window -h "ssh root@''${server_ip}"
            tmux select-layout tiled

            for file in ./public-ipv4-worker-*; do
              server_ip=$(cat "$file")
              tmux split-window -h "ssh root@''${server_ip}"
              tmux select-layout tiled
            done

            tmux select-pane -t 0
            tmux kill-pane
            tmux select-layout tiled

            tmux setw synchronize-panes on

            tmux attach-session -t servers
          '')

        ];

        shellHook = ''
          ${pkgs.figlet}/bin/figlet "wikidata dump processing"

          cat << _EOF

        provision  - rent servers from hetzner
        bootstrap  - install nixos and deploy configuration
        deploy     - redeploy configuration
        shell      - ssh into machines using tmux
_EOF
        '';
      };
    };
}
