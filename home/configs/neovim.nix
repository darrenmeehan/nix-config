{ config, pkgs, ... }:

let
  # Vendored copy of nixpkgs' neovim-unwrapped derivation
  # (./neovim-unwrapped/) with the `disallowedRequisites` attr removed:
  # Nix ≥ 2.24 ignores it under structuredAttrs and warns on every build
  # (the warning first surfaced when home-manager was switched here — the
  # module wraps programs.neovim.package itself). The cc-reference removal
  # is already done by the same package's postInstall remove-references-to
  # step, so behaviour is unchanged.
  fixedNeovim = pkgs.callPackage ./neovim-unwrapped/package.nix {
    CoreServices = null; # darwin-only, unused on Linux
    lua = pkgs.luajit;   # same choice all-packages.nix makes on x86_64-linux
  };

in {
  # vim plugin builds pull neovim-unwrapped via their require-check hook;
  # point the whole pkgs set at the fixed derivation so no code path
  # instantiates the stock (warning-emitting) one.
  nixpkgs.overlays = [ (final: prev: { neovim-unwrapped = fixedNeovim; }) ];

  programs.neovim = {
    enable = true;
    package = fixedNeovim;
    vimAlias = true;
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
      vimPlugins.coc-python
      vimPlugins.coc-pyright
      vimPlugins.coc-go
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
