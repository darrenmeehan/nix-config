{ ... }:

{
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = false;
    # https://starship.rs/config/
    settings = {
      add_newline = false;

      character = {
        success_symbol = "[#  ](bold green)";
        error_symbol = "[#  ](bold red)";
      };

      time = {
        disabled = true;
        format = "[$time]($style) ";
        time_format = "%R";
      };

      battery = {
        disabled = false;
        format = "[$symbol$percentage]($style) ";
        full_symbol = "🔋";
        charging_symbol = "🔌";
        discharging_symbol = "🪫";
        display = [{ threshold = 20; }];
      };

      username = {
        disabled = false;
        show_always = true;
        format = "[$user ]($style)";
      };

      directory = {
        format = "[$path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";
        truncate_to_repo = true;
      };

      git_branch = {
        format = "[$branch]($style)";
      };

      git_status = {
        format = "[$all_status$ahead_behind ]($style)";
      };

      memory_usage = {
        disabled = true;
        threshold = -1;
        symbol = " ";
        style = "bold dimmed green";
        format = "[$ram]($style) ";
      };

      cmd_duration = {
        min_time = 2000; # Milliseconds
        show_milliseconds = false;
        disabled = false;
      };

      localip = {
        ssh_only = true;
        format = "@[$localipv4](bold blue) ";
        disabled = false;
      };

    };
  };
}
