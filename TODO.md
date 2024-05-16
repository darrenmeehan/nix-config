[sudo] password for mac:     
Hit:1 https://updates.signal.org/desktop/apt xenial InRelease                  
Hit:2 https://repo.protonvpn.com/debian stable InRelease                       
Get:3 https://pkgs.tailscale.com/stable/ubuntu jammy InRelease                 
Ign:4 http://packages.linuxmint.com virginia InRelease                         
Hit:5 http://packages.linuxmint.com virginia Release                           
Hit:7 https://download.docker.com/linux/ubuntu jammy InRelease                 
Hit:8 https://apt.releases.hashicorp.com jammy InRelease                       
Hit:10 http://security.ubuntu.com/ubuntu jammy-security InRelease              
Hit:11 http://repository.spotify.com stable InRelease                          
Hit:12 http://archive.ubuntu.com/ubuntu jammy InRelease                        
Hit:13 http://archive.ubuntu.com/ubuntu jammy-updates InRelease
Hit:14 https://dl.google.com/linux/chrome/deb stable InRelease
Hit:15 http://archive.ubuntu.com/ubuntu jammy-backports InRelease
Get:9 https://packages.microsoft.com/repos/code stable InRelease [3,590 B]


Add support for
vscode
Chrome/Chromium?
Docker
Tailscale
Signal
Proton VPN - Doesnt seem to work in Nix? Not sure if machine or package issue at the moment..
Spotify


Move to zsh

Unhandled Promise Rejection

Error: DBVersionFromFutureError: SQL: User version is 1040 but the expected maximum version is 1000.
    at updateSchema ([REDACTED]/ts/sql/migrations/index.js:1784:11)
    at Object.initialize ([REDACTED]/ts/sql/Server.js:424:40)
    at MessagePort.<anonymous> ([REDACTED]/ts/sql/mainWorker.js:84:35)
    at [nodejs.internal.kHybridDispatch] (node:internal/event_target:807:20)
    at exports.emitMessage (node:internal/per_context/messageport:23:28)
    at Worker.<anonymous> ([REDACTED]/ts/sql/main.js:62:26)
    at Worker.emit (node:events:514:28)
    at MessagePort.<anonymous> (node:internal/worker:262:53)
    at [nodejs.internal.kHybridDispatch] (node:internal/event_target:807:20)
    at exports.emitMessage (node:internal/per_context/messageport:23:28)



Make templates unique - https://writeloop.dev/posts/prepare-vm-lxc-container-proxmox-nixos/




space reduction due to 4K zero blocks 0.207%
vm 201 - unable to parse config: additionalSpace: 512M
vm 201 - unable to parse config: bootSize: 256M
vm 201 - unable to parse config: diskSize: auto
root@pve:~# qmrestore /var/lib/vz/dump/vzdump-qem
