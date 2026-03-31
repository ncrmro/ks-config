{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./ssh.nix
  ];
  # UV - Fast Python package installer and resolver written in Rust
  # https://github.com/astral-sh/uv
  programs.uv.enable = true;

  # K9s - Kubernetes CLI and TUI to manage your clusters
  # https://k9scli.io/
  programs.k9s.enable = true;

  # Git LFS - Git extension for versioning large files
  # https://git-lfs.com/
  programs.git.lfs.enable = true;

  # AWS CLI - Official Amazon AWS command-line interface
  # https://aws.amazon.com/cli/
  programs.awscli.enable = true;

  home.packages = with pkgs; [
    # Kubectl - Kubernetes command-line tool
    # https://kubernetes.io/docs/reference/kubectl/
    kubectl

    # Helm - The package manager for Kubernetes
    # https://helm.sh/
    kubernetes-helm

    # LogCLI - Grafana Loki's command-line tool for querying logs
    # https://grafana.com/docs/loki/latest/tools/logcli/
    # no package in nixos atm
    #logcli

    # Lazydocker - Simple terminal UI for docker and docker-compose
    # https://github.com/jesseduffield/lazydocker
    lazydocker

    # traceroute # Does not work on macOS

    # htop - Interactive process viewer
    # https://htop.dev/
    # Provided by Keystone
    # htop

    # Zip - Compression and file packaging utility
    zip

    # Unzip - Extraction utility for .zip archives
    unzip

    # Devenv - Fast, declarative, reproducible dev environments
    # https://devenv.sh/
    devenv

    # Python 3.12 - High-level programming language
    # https://www.python.org/
    # python312Full removed in unstable - use python312 instead (bluetooth/tkinter now default)
    python312
    python312Packages.pip

    # Alejandra - The Uncompromising Nix Code Formatter
    # https://github.com/kamadorueda/alejandra
    alejandra

    # Does not support Network Manager
    # impala # TUI for managing wifi

    # Eza - Modern replacement for ls with colors and git integration
    # https://github.com/eza-community/eza
    # Provided by Keystone
    # eza

    # Tree - Recursive directory listing program
    # https://gitlab.com/OldManProgrammer/unix-tree
    # Provided by Keystone
    # tree

    # jq - Command-line JSON processor
    # https://jqlang.github.io/jq/
    # Provided by Keystone
    # jq

    # yq - Command-line YAML/XML/TOML processor (jq wrapper)
    # https://github.com/mikefarah/yq
    # Provided by Keystone
    # yq

    # SOPS - Simple and flexible tool for managing secrets
    # https://github.com/getsops/sops
    sops

    # GNU Stow - Symlink farm manager for installing software
    # https://www.gnu.org/software/stow/
    stow

    # httpie # Better curl
    # # diffsitter # Better diff

    # Marksman - Language server for Markdown
    # https://github.com/artempyanykh/marksman
    marksman

    # network tools

    # Dig - DNS lookup utility
    # https://www.isc.org/bind/
    dig

    # Nmap - Network exploration tool and security scanner
    # https://nmap.org/
    nmap

    # Socat - Multipurpose relay for bidirectional data transfer
    # https://www.dest-unreach.org/socat/
    socat

    # OpenSSL - Cryptography and SSL/TLS toolkit
    # https://www.openssl.org/
    openssl

    # GitHub Copilot CLI - AI pair programmer in your terminal
    # https://githubnext.com/projects/copilot-cli
    github-copilot-cli

    csview
  ];

  # Direnv - Load directory-specific environment variables automatically
  # Automatically loads .envrc files when entering directories
  # Supports dotenv (.env) files for environment variable management
  # https://direnv.net/
  # Managed by Keystone
  # programs.direnv = {
  #   enable = true;
  #   enableZshIntegration = true;
  #   config = {
  #     global = {
  #       load_dotenv = true;
  #     };
  #   };
  # };

  # Additional zsh aliases (not in keystone terminal)
  programs.zsh.shellAliases = {
    # Separate Claude config/session history for work use.
    claude-work = "CLAUDE_CONFIG_DIR=~/.claude-work claude";
    "docker comppose" = "docker-compose";
    dc = "docker-compose";
    k = "kubectl";
    # Session management
    ztab = "zellij action rename-tab";
  };

  programs.git.settings.alias = {
    s = "switch";
    f = "fetch";
    p = "pull";
    rff = "reset --force";
  };
}
