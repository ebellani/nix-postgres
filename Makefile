# Compilers/tools and flags
NIX := nix
NIXFLAGS := -L --impure

# Directories
TST_DIR := test

.PHONY: clean
clean: ## remove state of the local database
	rm -rf .devenv/state/postgres

.PHONY: database
database: clean ## starts up a local PostgreSQL cleaning the local environment. This will hang and delete your local ephemeral database data.
	nix develop . $(NIXFLAGS)
