{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    devenv.url = "github:cachix/devenv";
  };

  outputs = { self, nixpkgs, devenv, ... } @ inputs:
    let
      systems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = f: builtins.listToAttrs (map (name: { inherit name; value = f name; }) systems);
      PGHOSTADDR = "127.0.0.1";
      PGUSER = "admin";
      PGDATABASE = "transcorder";
      PGPASSWORD = "admin";
      PGPORT = 54321;
    in
      {
        packages = forAllSystems (system:
          let
            _pkgs = nixpkgs.legacyPackages."${system}";
          in {
            devenv-up = self.devShells.${system}.services.config.procfileScript;
          });
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in {
          services = devenv.lib.mkShell {
            inherit pkgs inputs;
            modules = [{
              services.postgres = {
                enable = true;
                package = pkgs.postgresql;
                extensions =
                  p: with p; [
                    pgtap
                  ];

                initdbArgs = [
                  "--locale=C"
                  "--encoding=UTF8"
                ];

                initialDatabases = [
                  { name = "transcorder"; }
                ];

                port = PGPORT;
                listen_addresses = PGHOSTADDR;

                initialScript = ''
                  create user ${PGUSER} with password '${PGPASSWORD}' superuser;
                  alter database ${PGDATABASE} owner to ${PGUSER};
                '';
              };
              enterShell = ''
                devenv up
              '';
            }];
          };

          default = pkgs.mkShell {
            packages = (with pkgs; [
              postgresql_15
            ]);
            env = {
              LOCALE_ARCHIVE =
                pkgs.lib.optionalString
                  pkgs.stdenv.isLinux
                  "${pkgs.glibcLocales}/lib/locale/locale-archive";
              LANG = "en_US.UTF-8";
              # https://www.postgresql.org/docs/current/libpq-envars.html
              PGHOSTADDR = PGHOSTADDR;
              PGUSER = PGUSER;
              PGDATABASE = PGDATABASE;
              PGPASSWORD = PGPASSWORD;
              PGPORT = PGPORT;
            };
          };
        });
      };
}
