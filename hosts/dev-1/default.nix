# ============================================================================
# Host — dev-1 (Proxmox VM on the LAN)
#
# A machine that keeps pi running when the laptop is closed. The agent process
# lives on this VM inside tmux and its session files live on this VM's disk, so
# a closed lid, a dropped SSH connection or a dead Wi-Fi link stops nothing:
# reattach and the same session is there. See hosts/dev-1/README.md.
#
# Also the general dev box for rust / npm / fly / docker work.
# ============================================================================

{ config, lib, pkgs, ... }:

let
  # The extension set, settings and guardrails file shared with the laptop —
  # see pkgs/pi-bolt/pi-config.nix. dev-1 leaves curam-membrane out (work in
  # progress), so it compiles in the same four extensions the laptop does and
  # none of the curam-membrane ones.
  piConfig = import ../../pkgs/pi-bolt/pi-config.nix {
    inherit pkgs;
    curam-membrane = false;
  };
  # jit on, for the same reason the laptop has it: opensec-pi-fff reaches its
  # native library through bun:ffi, whose calls a JIT generates. `cpu` stays at
  # the default (baseline x86-64) because this image is built on the laptop and
  # run on a different CPU — `native` would tie it to the build machine.
  piBolt = (pkgs.pi-bolt.withExtensions piConfig.extensions).override {
    jitSupport = true;
  };
in
{
  imports = [ ./hardware-configuration.nix ];

  # pi-bolt is not in nixpkgs; same overlay the home configs use. It stays in
  # systemPackages (not the user profile) because `pi-bolt service install`
  # points its unit at /run/current-system/sw/bin/pi-bolt.
  nixpkgs.overlays = [
    (final: prev: {
      pi-extensions = final.callPackage ../../pkgs/pi-extensions/default.nix { };
      pi-bolt = final.callPackage ../../pkgs/pi-bolt/package.nix { };
    })
  ];

  # ── Identity ─────────────────────────────────────────────────────────────
  system.stateVersion = "26.11";
  networking.hostName = "dev-1";
  time.timeZone = "Europe/Dublin";

  # ── Network ──────────────────────────────────────────────────────────────
  # DHCP on the Proxmox bridge (same pattern as hosts/media, hosts/app-node).
  networking.networkmanager.enable = true;
  # This box uses NetworkManager, not networkd — the default networkd
  # wait-online unit times out on every switch and makes `nixos-rebuild switch`
  # exit 4 (the reason hosts/app-node disables it too).
  systemd.network.wait-online.enable = false;
  services.qemuGuest.enable = true;

  # Tailscale: the phone's route in. The Pi-Bolt Android app talks to
  # `pi-bolt service` over the tailnet when the laptop/phone is away from the
  # LAN, and a 100.x address is stable where a Cloudflare quick tunnel gets a
  # new hostname on every restart. Same pattern as hosts/media.
  services.tailscale.enable = true;

  # ── SSH: the only way in, and the reason the box is reachable at all ──────
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      MaxAuthTries = 3;
      # Don't drop an idle client mid-run; a sleeping laptop reattaches instead
      # of leaving a half-open connection behind.
      ClientAliveInterval = 300;
      ClientAliveCountMax = 3;
    };
  };
  # ── Firewall ─────────────────────────────────────────────────────────────
  # 22 for me; 48123 for the Pi-Bolt phone app on the LAN (the remote-control
  # service listens on every interface at `remoteControl.port`, which is 48123
  # when the setting is 0). Nothing else is exposed, and there is no port
  # forwarding on the router.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    22
    48123
  ];
  # Everything over Tailscale is already authenticated end to end, so the
  # tailnet interface is trusted rather than punched through per port — the
  # concrete reason the phone can reach 48123 from outside the LAN.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # ── User ─────────────────────────────────────────────────────────────────
  users.users.drn = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    # `pi-bolt service install` writes a systemd --user unit. On a headless box
    # the user manager only exists while an SSH session does, so without
    # lingering the phone service dies with the connection — the exact failure
    # that makes remote control look broken.
    linger = true;
    # Bootstrap hash, same one hosts/rocinante ships. Change it on the VM with
    # `passwd` after first login (it is in git).
    initialHashedPassword = "$y$j9T$Ua3zZctnVLe2shI6PbePh0$PGsx86ZGX/x8yu6lg4fWeB6VKL1LaL2qEyh89q4imeA";
    openssh.authorizedKeys.keys = [
      # dev machine (darrenmeehan@fedora)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK5LOFpTvGdlomaMjY33qWhvybAVYJLZ9efU6wny2NUq hi@drn.ie"
      # ops (home-k8s, the key the app-node workflow uses)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHSmchQ7JS1UcyBy2lMoYuBQs/6H/VgqB+TrArRE6QDW home-k8s"
    ];
  };

  # ── Nix ──────────────────────────────────────────────────────────────────
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # direnv + nix-direnv build on the user's behalf, and `nix build` from a
    # project flake needs to add its own substituters/GC roots.
    trusted-users = [ "root" "@wheel" ];
  };
  # A dev box eats disk; reclaim it rather than fill the VM.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # ── Rust build headroom ──────────────────────────────────────────────────
  # No disk swap (hardware-configuration.nix): a link step that outruns RAM
  # would get OOM-killed rather than slow down. zram gives 8G (half of RAM) of
  # compressed in-memory swap, which suits rustc/lld spikes and costs no disk.
  zramSwap.enable = true;

  # ── Docker (docker build / compose, images cached on the VM disk) ────────
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # ── Dev toolchain ────────────────────────────────────────────────────────
  # No global Rust toolchain: each repo provides rustc/cargo/rust-analyzer from
  # its own flake devShell (templates/rust), loaded by direnv. Same rule as
  # every other machine here — see AGENTS.md.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  environment.systemPackages = with pkgs; [
    git
    curl
    jq
    vim
    htop
    ripgrep # pi's own grep/find tools shell out to these
    fd
    nodejs_26 # npm included
    # pi installs its extension packages into ~/.pi/agent/npm with npm, and a
    # dependency of one of them (node-pty) has no prebuild for Node 26, so
    # node-gyp rebuilds it: that needs a Python and a C/C++ toolchain on PATH.
    # Without these the install fails with "Could not find any Python".
    python3
    gnumake
    gcc
    flyctl
    docker-compose
    herdr # agent multiplexer: the durable pi session lives in its background server
    piBolt # this box's build: the laptop's extensions minus curam-membrane (see the let)
    pi-coding-agent # node pi: cached by nixpkgs, useful when pi-bolt misbehaves
  ];
}
