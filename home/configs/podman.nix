{ ... }:
# Rootless podman reads $HOME/.config/containers first, then /etc/containers,
# then /usr/share/containers (podman's own error message lists that order).
# Owning these here means the Fedora `containers-common` RPM is not needed --
# it was autoremoved with the podman RPM and `podman run` then failed with
# "config file not found: no policy.json file found".
#
# What containers-common also ships and this deliberately omits: storage.conf
# (rootless already picks the `overlay` driver via nix's fuse-overlayfs, which
# the podman wrapper puts on PATH) and containers.conf (built-in defaults).
{
  xdg.configFile."containers/policy.json".text = ''
    {
      "default": [
        {
          "type": "insecureAcceptAnything"
        }
      ]
    }
  '';

  # Without this, short names fail to resolve:
  #   short-name "alpine" did not resolve to an alias and no
  #   containers-registries.conf(5) was found
  xdg.configFile."containers/registries.conf".text = ''
    unqualified-search-registries = ["docker.io"]
  '';
}
