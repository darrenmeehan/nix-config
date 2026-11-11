{
  programs.ghostty = {
    enable = true;
    # Font/padding mirror configs/alacritty.nix so both terminals look alike.
    settings = {
      font-family = "DejaVu Sans Mono for Powerline";
      font-size = 12;
      window-padding-x = 4;
      window-padding-y = 4;
      theme = "Carbonfox";
    };
  };
}
