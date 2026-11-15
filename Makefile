default: help

HOSTNAME=$(shell hostname)

# `nixos-rebuild` will use the current host, if none is specified
.PHONY: build-nixos
build-nixos: ## Build NixOS configuration
	nixos-rebuild build --flake .

# `nixos-rebuild` will use the current host, if none is specified
.PHONY: switch-nixos
switch-nixos: ## Switch NixOS configuration
	nixos-rebuild switch --flake .

.PHONY: bootstrap-hm
bootstrap-hm: ## Bootstrap Home-Manager configuration
	nix build --no-link .#homeConfigurations.$(USER)@$(HOSTNAME).activationPackage
	$(shell nix path-info .#homeConfigurations.$(USER)@$(HOSTNAME).activationPackage)/activate

.PHONY: build-hm
build-hm: ## Build Home-Manager configuration
	home-manager build --flake .#$(USER)@$(HOSTNAME)

.PHONY: switch-hm
switch-hm: ## Switch Home-Manager configuration
	home-manager switch --flake .#$(USER)@$(HOSTNAME)

.PHONY: deploy-app-node
deploy-app-node: ## Full deploy on app-node: NixOS config + app (requires Tailscale)
	ssh -t darren@app-node /opt/nix-config/scripts/deploy-app.sh

PROVISION_HOST ?= app-node
VMID ?= 100
PVE ?= root@pve
.PHONY: provision-vm
provision-vm: ## Provision a VM on PVE from a built VMA image (PROVISION_HOST=media VMID=101 PVE=root@pve)
	./scripts/provision-vm.sh "$(PROVISION_HOST)" "$(VMID)" "$(PVE)"

.PHONY: deploy-media
media: ## Pull + switch the media VM (requires Tailscale/ssh)
	ssh drn@media 'cd /opt/nix-config && git pull && sudo nixos-rebuild switch --flake /opt/nix-config#media'

.PHONY: deploy-dev-1
# `pi-bolt service` runs a systemd --user unit whose ExecStart is a /nix/store
# path, so a pi-bolt bump leaves it pointing at the old one (which GC may then
# delete). Restarting it after the switch re-execs the new binary; no-op when
# the service was never installed.
dev-1: ## Pull + switch the dev-1 VM (requires ssh)
	ssh drn@dev-1 'cd /opt/nix-config && git pull && sudo nixos-rebuild switch --flake /opt/nix-config#dev-1; pi-bolt service restart || true'

.PHONY: lock
lock: ## Update lock file
	nix flake update

.PHONY: pin-curam
pin-curam: ## Move pkgs/curam/pins.nix to the checkouts' current HEADs
	./scripts/pin-curam.sh

.PHONY: gc
gc: ## Garbage collect
	nix-collect-garbage

.PHONY: check-pi-bolt
check-pi-bolt: ## Start pi-bolt on a pty, fail if an extension does not load (no model call)
	./scripts/check-pi-bolt.sh

.PHONY: bench-pi-bolt
bench-pi-bolt: ## Time to first prompt, min/median/max over 10 starts
	./scripts/check-pi-bolt.sh 10

.PHONY: help
help: ## This menu
	@grep -P "##\s(.*)$$" $(MAKEFILE_LIST) | sed 's/:.*##/:/'
