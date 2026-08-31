{ config, pkgs, lib, ... }:

{
  options = {
    services.tailscale-serve = {
      enable = lib.mkEnableOption "Tailscale Serve proxy";
      port = lib.mkOption {
        type = lib.types.port;
        default = 80;
      };
      target = lib.mkOption {
        type = lib.types.str;
      };
    };
  };

  config = lib.mkIf config.services.tailscale-serve.enable {
    # Auth check — warns if not authenticated
    systemd.services.tailscale-auth-check = {
      description = "Tailscale authentication check";
      after = [ "tailscale.service" ];
      wants = [ "tailscale.service" ];
      wantedBy = [ "multi-user.target" ];
      script = ''
        if ! ${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null | ${pkgs.jq}/bin/jq -e '.BackendState == "Running"' > /dev/null 2>&1; then
          echo "⚠️  Tailscale not authenticated. Run: sudo tailscale up"
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    # Tailscale Serve — proxies :port → http://target
    systemd.services.tailscale-serve = {
      description = "Tailscale Serve proxy :${toString config.services.tailscale-serve.port} → ${config.services.tailscale-serve.target}";
      after = [ "tailscale.service" ];
      wants = [ "tailscale.service" ];
      wantedBy = [ "multi-user.target" ];
      script = ''
        ${pkgs.tailscale}/bin/tailscale serve --bg \
          --http ${toString config.services.tailscale-serve.port} \
          / http://${config.services.tailscale-serve.target}
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };
  };
}