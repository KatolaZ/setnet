# setnet.sh #

This is a simple shell script to configure and manage network
interfaces. At the moment, it is only able to bring up ethernet and
wi-fi networks (WPA-Personal and WPA-Enterprise), using either static
or dhcp-based IP configuration.

For more information, please visit the webpage:

[http://katolaz.net/setnet](http://katolaz.net/setnet)

**The GitHub repository is not updated frequently** 

The main remote for this repository is at:

[https://git.katolaz.net/setnet](https://git.katolaz.net/setnet)

## Dependencies ##

setnet.sh depends on the following packages:

- a standard posix shell
  (tested with bash, busybox, dash, ksh, mksh, posh, yash, zsh)
- dialog
- wpa_supplicant
- dhclient
- iproute2
- iw



