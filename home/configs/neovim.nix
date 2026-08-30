{ config, pkgs, ... }:

{
  # Vendored ./neovim-unwrapped copy removed (2026-08): it only carried a
  # disallowedRequisites workaround for Nix ≥ 2.24 structuredAttrs warnings;
  # 2026 nixpkgs sets __structuredAttrs itself, and the vendored 0.10.1 no
  # longer compiles against 2026 libuv.
  programs.neovim = {
    enable = true;
    vimAlias = true;
    # stateVersion < 26.05 keeps legacy behaviour; pin explicitly to silence
    # the default-change warnings.
    withRuby = true;
    withPython3 = true;
    coc.enable = true;
    coc.settings = {
      "python.linting.enabled" = true;
      "python.linting.flake8Enabled" = true;
    };
    plugins = with pkgs; [
      # Appearance
      vimPlugins.vim-airline
      vimPlugins.vim-airline-themes
      vimPlugins.vim-devicons
      vimPlugins.nerdtree
      # Git
      vimPlugins.vim-fugitive
      # Languages
      vimPlugins.vim-nix
      # CoC / Conquer of Completion
      vimPlugins.coc-pairs
      vimPlugins.coc-snippets
      vimPlugins.coc-pyright
      vimPlugins.coc-yaml
      vimPlugins.coc-json
      vimPlugins.coc-prettier
      vimPlugins.coc-markdownlint
      # Utils
      vimPlugins.fzf-vim
    ];
    extraConfig = ''
      " Airline
      let g:airline_powerline_fonts = 1
      if !exists('g:airline_symbols')
          let g:airline_symbols = {}
      endif
      let g:airline_theme = 'minimalist'
    '';
  };
}
