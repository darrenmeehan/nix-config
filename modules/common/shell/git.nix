{ config, pkgs, lib, ... }:

{

  options = {
    gitName = lib.mkOption {
      type = lib.types.str;
      description = "Name to use for git commits";
    };
    gitEmail = lib.mkOption {
      type = lib.types.str;
      description = "Email to use for git commits";
    };
  };

  config = {

    home-manager.users.root.programs.git = {
      enable = true;
      # extraConfig.safe.directory = config.dotfilesPath;
    };

    home-manager.users.${config.user} = {
      programs = {
        git = {
          enable = true;
          userName = config.gitName;
          userEmail = config.gitEmail;
          extraConfig = {
            core.pager =
              "${pkgs.git}/share/git/contrib/diff-highlight/diff-highlight | less -F";
            interactive.difffilter =
              "${pkgs.git}/share/git/contrib/diff-highlight/diff-highlight";
            pager = { branch = "false"; };
            # safe = { directory = config.dotfilesPath; };
            pull = { ff = "only"; };
            push = { autoSetupRemote = "true"; };
            init = { defaultBranch = "master"; };
            rebase = { autosquash = "true"; };
            gpg = {
              format = "ssh";
              ssh.allowedSignersFile = "~/.config/git/allowed-signers";
            };
            # commit.gpgsign = true;
            # tag.gpgsign = true;
          };
          ignores = [ ".direnv/**" "result" ];
          includes = [{
            path = "~/.config/git/personal";
            condition = "gitdir:~/dev/personal/";
          }];
        };
        fish.shellAbbrs = {
          g = "git";
          gs = "git status";
          gd = "git diff";
          gds = "git diff --staged";
          gdp = "git diff HEAD^";
          ga = "git add";
          gaa = "git add -A";
          gac = "git commit -am";
          gc = "git commit -m";
          gca = "git commit --amend --no-edit";
          gcae = "git commit --amend";
          gu = "git pull";
          gp = "git push";
          gl = "git log --graph --decorate --oneline -20";
          gll = "git log --graph --decorate --oneline";
          gco = "git checkout";
          gcom = ''
            git switch (git symbolic-ref refs/remotes/origin/HEAD | cut -d"/" -f4)'';
          gcob = "git switch -c";
          gb = "git branch";
          gpd = "git push origin -d";
          gbd = "git branch -d";
          gbD = "git branch -D";
          gr = "git reset";
          grh = "git reset --hard";
          gm = "git merge";
          gcp = "git cherry-pick";
          cdg = "cd (git rev-parse --show-toplevel)";
        };
      };
      # Personal git config
      # TODO: fix with variables
      xdg.configFile."git/personal".text = ''
        [user]
            name = "${config.fullName}"
            email = "hi@drn.ie
            signingkey = ~/.ssh/id_ed25519
        [commit]
            gpgsign = true
        [tag]
            gpgsign = true
      '';

      #   xdg.configFile."git/allowed-signers".text = ''
      #     hi@drn.ie ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB+AbmjGEwITk5CK9y7+Rg27Fokgj9QEjgc9wST6MA3s
      #   '';

      # Required for fish commands
      home.packages = with pkgs; [ fish fzf bat ];
    };

  };

}
