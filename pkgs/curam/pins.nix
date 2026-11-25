# The two curam checkouts, by commit. `builtins.fetchGit` with an explicit rev is
# forced only when the engine or the driver is actually built: a derivation, not
# a flake input. That matters because nix fetches every flake input of a flake
# for every output, so as inputs these two made any evaluation of this repo — on
# media, app-node, mgmt — fail on machines that do not have the checkouts.
#
# Cost of that laziness: uncommitted work is not built. Commit in the checkout,
# then `make pin-curam` to move these revs.
{
  curam-security = {
    url = "file:///home/darrenmeehan/code/curam-security";
    rev = "d5820b852900a6586396ae0345a01d776512c318";
  };
  pi-curam-security = {
    url = "file:///home/darrenmeehan/code/pi-curam-security";
    rev = "92bedc3699b49b906584fa0562e0f244a993b393";
  };
}
