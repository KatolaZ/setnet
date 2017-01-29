#
# Regular cron jobs for the setnet package
#
0 4	* * *	root	[ -x /usr/bin/setnet_maintenance ] && /usr/bin/setnet_maintenance
