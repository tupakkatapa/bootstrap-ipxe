# Bootstrap-iPXE

A simple script for building and updating the iPXE firmware on a TFTP server. This script automates the process of building undionly.kpxe, embedding a chainloader script, and uploading it to the TFTP server.

When building undionly.kpxe using this script, the following features are enabled: HTTPS, NFS, dynamic keyboard mapping, ping, display of network interface information, reboot, and power off capabilities.

To use this script, you will need to configure your DHCP server to hand out undionly.kpxe as the boot file.

## Usage

1. Install necessary dependencies.
```console
# Debian/Ubuntu:
$ apt-get install -y git atftp gcc make liblzma-dev

# Fedora:
$ dnf install -y git tftp gcc make xz-devel

# Arch Linux:
$ pacman -S git atftp gcc make xz
```

2. Clone repo and run the script:
```console
$ git clone https://github.com/tupakkatapa/bootstrap-ipxe.git && cd bootstrap-ipxe 

$ chmod +x bootstrap-ipxe.sh

$ ./bootstrap-ipxe.sh
===================================
   Bootstrap-iPXE
===================================
1. Build undionly.kpxe
2. Create and embed iPXE script
3. Upload to TFTP server
4. Clean all files
q. Quit

Enter your choice:
```

## Links

https://ipxe.org/howto/chainloading
