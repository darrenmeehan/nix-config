{ lib, ... }:
# dev-1's git identity comes from the same file the laptop uses, so name, email
# and aliases have one source of truth. The one difference is the credential
# helper: the shared default is libsecret, which needs a keyring this headless
# box does not run. An empty helper resets the list (git's own semantics), and
# gh's per-host helper is a separate key so it survives.
{
  imports = [ ../../home/configs/git.nix ];
  programs.git.settings.credential.helper = lib.mkForce "";
}
