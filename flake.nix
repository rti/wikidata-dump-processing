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

      hostnameScheduler = "dask-scheduler";
      hostnamesWorkers = builtins.genList (n: "dask-worker-${toString (n+1)}") workerCount;

      devPackages = with pkgs; with pkgs.python3Packages; [
        (pkgs.python3.withPackages python-packages)
        pyright
        black
        pip
        ipython
        coverage
     ];

      mkSystemConfig = hostname: modules: nixpkgs.lib.nixosSystem {
        inherit system;
        inherit pkgs;
        inherit specialArgs;
        modules = [
          inputs.disko.nixosModules.disko
          (import ./disko-config.nix)
          ({ ... }: {
            networking.hostName = hostname;
            environment.systemPackages = devPackages;
          })
        ] ++ modules;
      };
    in
    {
      nixosConfigurations = {
        "${hostnameScheduler}" = mkSystemConfig hostnameScheduler [
          ./configuration-scheduler.nix
        ];
      } // nixpkgs.lib.genAttrs hostnamesWorkers (hostname: mkSystemConfig hostname [
        ./configuration-worker.nix
      ]);

      devShell.${system} = pkgs.mkShell {
        packages = 
          devPackages ++ 
          [

          inputs.disko.packages.x86_64-linux.disko
          inputs.nixos-anywhere.packages.x86_64-linux.nixos-anywhere
          (pkgs.opentofu.withPlugins (p: [ p.hcloud p.hetznerdns ]))
          pkgs.tmux

          (pkgs.writeShellScriptBin "provision" ''
            set -e
            tofu init -reconfigure
            tofu apply \
              -var "hcloud_token=$(pass hetzner.com/dask-api-token)" \
              -var "hdns_token=$(pass apitoken/hetznerdns)"
          '')

          (pkgs.writeShellScriptBin "bootstrap" ''
            set -e

            server_ip=$(cat "./public-ipv4-scheduler")
            nixos-anywhere --flake ".#dask-scheduler" "root@''${server_ip}" &

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

            server_ip=$(cat "./public-ipv4-scheduler")
            nixos-rebuild switch --flake ".#dask-scheduler" \
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

          (pkgs.writeShellScriptBin "shell-workers" ''
            set -e

            tmux new-session -d -s workers

            for file in ./public-ipv4-worker-*; do
              server_ip=$(cat "$file")
              tmux split-window -h "ssh root@''${server_ip}"
              tmux select-layout tiled
            done

            tmux select-pane -t 0
            tmux kill-pane
            tmux select-layout tiled

            tmux setw synchronize-panes on

            tmux attach-session -t workers
          '')

          (pkgs.writeShellScriptBin "shell-schduler" ''
            set -e

            server_ip=$(cat "./public-ipv4-scheduler")
            ssh root@''${server_ip}
          '')
        ];

        shellHook = ''
          ${pkgs.figlet}/bin/figlet "wikidata dump processing"

          cat << _EOF

        provision      - rent servers from hetzner
        bootstrap      - install nixos and deploy configuration
        deploy         - redeploy configuration
        shell-workers  - ssh into worker machines using tmux
        shell-schduler - ssh into scheduler machine
_EOF
        '';
      };
    };
}
