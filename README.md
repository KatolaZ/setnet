# setnet.sh #

This is a simple shell script to configure and manage network
interfaces. At the moment, it is only able to bring up ethernet and
wi-fi networks (WPA/WPA2/ESS), using either static or dhcp-based IP
configuration.

## Dependencies ##

setnet.sh depends on the following packages:

- a standard posix shell
  (tested with bash, busybox, dash, ksh, mksh, posh, and yash)
- dialog
- wpa_supplicant
- dhclient
- iproute2



