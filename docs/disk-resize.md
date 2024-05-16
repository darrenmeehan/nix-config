# How to resize VM Disks

I'm currently working around an issue where the VM disks are not declaritively set.

The workaround is to standup the VM, and then resize it manually through the CLI.

```shell
[drn@rocinante:~]$ nix-shell -p parted
```

```shell
[nix-shell:~]$ sudo parted /dev/vda
GNU Parted 3.6
Using /dev/vda
Welcome to GNU Parted! Type 'help' to view a list of commands.
(parted) print                                                            
Model: Virtio Block Device (virtblk)
Disk /dev/vda: 112GB
Sector size (logical/physical): 512B/512B
Partition Table: msdos
Disk Flags: 

Number  Start   End     Size    Type     File system  Flags
 1      1049kB  4375MB  4374MB  primary  ext4

(parted) resizepart 1 100%
Warning: Partition /dev/vda1 is being used. Are you sure you want to continue?
Yes/No? Yes                                                               
(parted) quit                                                             
Information: You may need to update /etc/fstab.

                                                                          
[nix-shell:~]$ cat /rtc/fstab
cat: /rtc/fstab: No such file or directory

[nix-shell:~]$ cat /etc/fstab
# This is a generated file.  Do not edit!
#
# To make changes, edit the fileSystems and swapDevices NixOS options
# in your /etc/nixos/configuration.nix file.
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>

# Filesystems.
/dev/disk/by-label/nixos / ext4 x-systemd.growfs,x-initrd.mount 0 1



```

<<< Welcome to NixOS 24.05pre625253.3281bec7174f (x86_64) - ttyS0 >>>

Run 'nixos-help' for the NixOS manual.

rocinante login: drn
Password: 

[drn@rocinante:~]$ sudo fdisk --l
[sudo] password for drn: 
fdisk: option '--l' is ambiguous; possibilities: '--list' '--list-details' '--lock'
Try 'fdisk --help' for more information.

[drn@rocinante:~]$ sudo fdisk -l
Disk /dev/vda: 104.07 GiB, 111748841472 bytes, 218259456 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0x43f81001

Device     Boot Start       End   Sectors   Size Id Type
/dev/vda1        2048 218259455 218257408 104.1G 83 Linux

[drn@rocinante:~]$ 

```



```shell

[drn@rocinante:~]$ history
    1  ls
    2  vim
    3  exit
    4  exit
    5  lsbdisk
    6  ls
    7  fdisk
    8  fdisk /dev/vda
    9  sudo fdisk /dev/vda
   10  dmesg | grep vda
   11  fdisk -l /dev/vda | grep ^/dev
   12  sudo fdisk -l /dev/vda | grep ^/dev
   13  parted /dev/vda
   14  nix-shell -p parted
   15  history
```



[nix-shell:~]$ history
    1  ls
    2  vim
    3  exit
    4  exit
    5  parted
    6  sudo parted
    7  sudo parted /dev/vda
    8  cat /rtc/fstab
    9  cat /etc/fstab
   10  history
