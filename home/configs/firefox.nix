{
  # Keep the legacy profile location (~/.mozilla/firefox) — silences the
  # configPath default-change warning without moving profiles.
  programs.firefox = {
    enable = true;
    configPath = ".mozilla/firefox";
  };
}
