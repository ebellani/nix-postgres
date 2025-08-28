{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      nixpkgs,
      devenv,
      treefmt-nix,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      perSystem =
        { pkgs, system, ... }:
        let
          treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
          pgPort = 54321;
          pgHostname = "127.0.0.1";
        in
        {
          # This sets `pkgs` to a nixpkgs with allowUnfree option set.
          _module.args.pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          # nix build
          packages = {
            # devenv up
            devenv-up = self.devShells.${system}.default.config.procfileScript;

            # devenv test
            devenv-test = self.devShells.${system}.default.config.test;
          };

          # nix run
          apps = {
          };

          # nix develop
          devShells = {
            # `nix develop --impure`
            default = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                (
                  { pkgs, lib, ... }:
                  {
                    packages = with pkgs; [
                      bash
                      gnumake
                      # For psql, etc
                      postgresql
                    ];

                    enterShell = ''
                      echo "Starting Development Environment..."
                    '';

                    # from "devenv test", needs devenv up
                    enterTest = ''
                      echo "Starting Test Environment..."
                      pg_isready -h 127.0.0.1 -p ${toString pgPort}
                      if psql -h ${pgHostname} -p ${toString pgPort} -U admin -d transcode -c "SELECT extname FROM pg_extension WHERE extname = 'pgtap';" | grep -q pgtap; then
                        exit 0
                      else
                        exit 1
                      fi
                    '';

                    services.postgres = {
                      enable = true;
                      # Pick whichever version of posgresql you want
                      package = pkgs.postgresql_17;
                      port = pgPort;
                      extensions = ext: [
                        ext.pgtap
                      ];
                      initdbArgs = [
                        "--locale=C"
                        "--encoding=UTF8"
                      ];
                      # This is how you can add custom settings
                      settings = {
                        shared_preload_libraries = "pg_stat_statements";
                        session_preload_libraries = "auto_explain";
                        # nested attr sets need to be converted to strings, otherwise
                        # postgresql.conf fails to be generated.
                        "auto_explain.log_min_duration" = 150;
                        "auto_explain.log_analyze" = true;
                        log_min_duration_statement = 0;
                        log_statement = "all";
                        compute_query_id = "on";
                        "pg_stat_statements.max" = 10000;
                        "pg_stat_statements.track" = "all";
                      };
                      initialDatabases = [
                        # If you need more custom users and DBs, just
                        # use another record.
                        {
                          # Database Name
                          name = "transcode";
                          # User who owns it
                          user = "admin";
                          # A password used for local development
                          pass = "admin";
                          # You can also point to a sql file to init
                          # the DB with SQL
                          # initialSQL = builtins.readFile ./init.sql;
                        }
                      ];
                      listen_addresses = "127.0.0.1";
                      initialScript = ''
                        -- The admin user
                        ALTER USER admin CREATEROLE;
                      '';
                    };
                  }
                )
              ];
            };
          };

          # nix fmt
          formatter = treefmtEval.config.build.wrapper;
        };

      flake = {
      };
    };
}
