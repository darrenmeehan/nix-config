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
    rev = "f8e3ecd5459cdcef8590f044f3b70d7003a22300";
  };
  pi-curam-security = {
    url = "file:///home/darrenmeehan/code/pi-curam-security";
    rev = "037d1aac655fb1de32fcc9f7571949c141522577";
  };
}
