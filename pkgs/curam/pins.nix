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
    rev = "bab91fa82c6007db4f9d6625a6fcd22df9f0e1ce";
  };
  curam-membrane = {
    url = "file:///home/darrenmeehan/code/curam-membrane";
    rev = "8ea6051c0f9bbaa0706a297332e5baef8a7472e3";
  };
}
