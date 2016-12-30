#!/bin/bash

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
# 
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# ----------------------------------------------------------------------
#
#   setnet.sh -- view and configure network interfaces
#
# ----------------------------------------------------------------------
#
# (c) KatolaZ (katolaz@freaknet.org) -- 2016/12/26
#
#


##
## Initialisation
## 

VERSION=0.1

DIALOGRC=~/.dialogrc


TOPSTR="setnet-0.1 [user: `id -run`]"

DIALOG="dialog --backtitle \"${TOPSTR}\" "



TMPFILE=`(tempfile) 2>/dev/null` || tempfile=/tmp/setnet_$$
WPA_PIDFILE=`(tempfile) 2>/dev/null` || tempfile=/tmp/setnet_wpapid_$$

WINDOW_WIDTH=75
WINDOW_HEIGHT=20

INFO_WIDTH=40
INFO_HEIGHT=10

FORM_WIDTH=60
FORM_HEIGHT=12

NET_FAMILIES="inet inet6"

##
## Load setnetrc 
##

function load_setnetrc(){

	WPA_FILE=""
	LOGFILE=""
	## If we were given a parameter, is the rc file to load...
	##	
	if [ $# -ge 1 ]; then
		. $1
		return
	fi
	
	##
	## Otherwise, let's look in the standard locations, namely:
	##

	##
	## 1) /etc/setnetrc
	##

	if [ -f /etc/setnetrc ]; then
		. /etc/setnetrc
	fi

	##
	## 2) ~/.setnetrc
	##

	if [ -f ~/.setnetrc ]; then
		. ~/.setnetrc
	fi


	if [ -z ${WPA_FILE} ]; then
		echo "Could not find WPA_FILE defined anywhere. Exiting"
		exit 1
	fi

	if [ -z ${LOGFILE} ]; then
		echo "Could not find LOGFILE defined anywhere. Exiting"
		exit 1
	fi
}


function cleanup(){
	rm -f ${TMPFILE}
	rm -f ${WPA_PIDFILE}
}


###################
#                 #
#     LOGGING     #
#                 #
###################

##
## log() takes two arguments, namely the label and the message
##
## if the label is "_self", print the name of the function which
## called log()
##
function log(){

	local LABEL=$1
	local MSG=$2

	if [ ${LABEL} == "_self" ]; then
		LABEL=${FUNCNAME[1]}
	fi
	echo -e "${LABEL}:" "${MSG}" >> "${LOGFILE}"
	
}

##########################################

function edit_file(){

	local FILEIN=$1
	log "edit_file" "editing file ${FILEIN}"
	eval "${DIALOG} --title 'Editing file: ${FILEIN}' \
			--editbox ${FILEIN} ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 2> ${TMPFILE}"

	if [ $? -eq 0 ]; then
		log "edit_file" "Copying ${TMPFILE} into ${FILEIN}"
		if cp ${TMPFILE} ${FILEIN}
		then
			eval "${DIALOG}   --clear --msgbox 'File ${FILEIN} saved successfully' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}"
		else
			eval "${DIALOG}   --clear --msgbox 'Error saving file ${FILEIN}' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}"
		fi
	else
		log "edit_file" "Editing of ${FILEIN} aborted..."xs
		eval "${DIALOG}   --clear --msgbox 'File ${FILEIN} not saved' \
			   ${INFO_HEIGHT} ${INFO_WIDTH}"
	fi
}




##
## Read all the configured addresses for a given inet family
##
function get_addr_family(){
	
	local DEVNAME=$1
	local DEVFAMILY=$2

	NUMADDR=`ip -f ${DEVFAMILY} addr show ${DEVNAME} | grep ${DEVFAMILY} | wc -l`
	ADDR_STR=""
	for i in `seq ${NUMADDR}`; do 
		ADDR=`ip -f ${DEVFAMILY} addr show ${DEVNAME} | grep ${DEVFAMILY} | \
			tail -n +$i | head -1 | sed -r -e "s:^\ +::g" | cut -d " " -f 2,4,6 |\
			sed -r -e "s:\ : -- :g"`
		ADDR_STR="${ADDR_STR}\n${DEVFAMILY}: ${ADDR}\n"
	done
}

##
## Show the current configuration of a given device
##

function show_device_conf(){

	local DEVNAME=$1
	if [ ${DEVNAME} == "" ]; then
		return -1
	fi

	DEVMAC=`ip link show ${DEVNAME} | tail -n +2 | sed -r 's/^\ +//g' | cut -d " " -f 2`
	DEVCONF="MAC: ${DEVMAC}\n"

	log "_self" "NET_FAMILIES: \"${NET_FAMILIES}\""
	
	for f in ${NET_FAMILIES}; do
		get_addr_family ${DEVNAME} ${f}
		log "_self" "family: ${f} ADDR_STR: \"${ADDR_STR}\""
		
		if [ -z "${ADDR_STR}" ]; then 
			DEVCONF="${DEVCONF}${f}: Unconfigured\n"
		else
			DEVCONF="${DEVCONF}${ADDR_STR}"
		fi
		log "_self" "DEVCONF: ${DEVCONF}"
	done

	DEVCONF="${DEVCONF}\n== name servers ==\n`cat /etc/resolv.conf | grep '^nameserver'`"
	
	eval "${DIALOG}   --clear --title 'Current configuration of device: ${DEVNAME}' \
		--msgbox '\n\n${DEVCONF}' ${WINDOW_HEIGHT} ${WINDOW_WIDTH} "
	return 0

}



function config_ethernet_static(){

	local DEV_IP="192.168.1.2"
	local DEV_NET="192.168.1.0"
	local DEV_NETMASK="255.255.255.0"
	local DEV_GW="192.168.1.1"
	local DEV_DNS1="208.67.222.222"
	local DEV_DNS2="208.67.220.220"

	local DEVNAME=$1

	exec 3>&1	
	eval "${DIALOG}  --clear --form 'Set network for device: ${DEVNAME}'" \
	${FORM_HEIGHT} ${FORM_WIDTH} 0 \
	"IP"            1 1 "${DEV_IP}"    1 16 16 16 \
	"Network"       2 1 "${DEV_NET}"    2 16 16 16 \
	"Netmask"       3 1 "${DEV_NETMASK}"  3 16 16 16 \
	"Gateway"       4 1 "${DEV_GW}"    4 16 16 16 \
	"Primary DNS"   5 1 "${DEV_DNS1}" 5 16 16 16 \
	"Secondary DNS" 6 1 "${DEV_DNS2}" 6 16 16 16 2> ${TMPFILE}

	if [ $? -eq 1 ]; then 
		eval "${DIALOG}  --infobox 'Configuration of ${DEVNAME} aborted' \
		${INFO_HEIGHT} ${INFO_WIDTH}"
		return
	fi

	read -d "*" DEV_IP DEV_NET DEV_NETMASK DEV_GW DEV_DNS1  DEV_DNS2 < ${TMPFILE}
	eval "${DIALOG}  --msgbox 'Proposed configuration of ${DEVNAME}:\n ${DEV_IP}\n${DEV_NET}\n${DEV_NETMASK}\n${DEV_GW}\n${DEV_DNS1}\n${DEV_DNS2}'\
		${WINDOW_HEIGHT} ${WINDOW_WIDTH}"
	
	## Configure IP
	
	ip link set ${DEVNAME} down
	ip link set ${DEVNAME} up
	ip address flush dev ${DEVNAME}
	ip address add ${DEV_IP}/${DEV_NETMASK} dev ${DEVNAME}
	
	## Configure GW
	ip route flush dev ${DEVNAME}
	ip route add ${DEV_NET}/${DEV_NETMASK} dev ${DEVNAME}
	ip route add default via ${DEV_GW}
	
	## Configure DNS
	mv /etc/resolv.conf /etc/resolv.conf.bak
	if [ -n ${DEV_DNS1} ]; then
		echo "nameserver ${DEV_DNS1}" >> /etc/resolv.conf
	fi
	if [ -n ${DEV_DNS2} ]; then
		echo "nameserver ${DEV_DNS2}" >> /etc/resolv.conf
	fi
	show_device_conf ${DEVNAME}
}

function config_ethernet_dhcp(){

	local DEVNAME=$1

	eval "${DIALOG}  --infobox 'Running \"dhclient ${DEVNAME}\"' ${INFO_HEIGHT} ${INFO_WIDTH}"
	dhclient -r ${DEVNAME}
	dhclient ${DEVNAME}
	show_device_conf ${DEVNAME}
}


function config_ethernet(){

	local DEVNAME=$1
	
	while [ 1 -eq 1 ]; do
		eval "${DIALOG}  --clear --cancel-label 'Up' \
		--menu 'Configuring ${DEVNAME}' ${INFO_HEIGHT} ${INFO_WIDTH} 4 \
		'DHCP' ''\
		'Static' '' 2>${TMPFILE}"
		if [ $? -eq 1 ]; then
			return
		fi
		ACTION=`<${TMPFILE}`
		case ${ACTION} in
			"Static")
				config_ethernet_static ${DEVNAME}
				;;
			"DHCP")
				config_ethernet_dhcp ${DEVNAME}
				;;
		esac
	done

}

function wifi_essid_from_mac(){

	local DEVNAME=$1
	local W_MAC=$2
	
	W_ESSID=`wpa_cli -i ${DEVNAME} scan_results | grep -E "^${W_MAC}" | \
       sed -r -e 's/\t/\|/g' | cut -d "|" -f 5`

	log "${FUNCNAME[0]}" "Recovered ESSID: ${W_ESSID}"
}

function wifi_flags_from_mac(){
	local DEVNAME=$1
	local W_MAC=$2

	W_FLAGS=`wpa_cli -i ${DEVNAME} scan_results | grep -E "^${W_MAC}" | \
       sed -r -e 's/\t/\|/g' | cut -d "|" -f 4`
	log "wifi_essid_from_mac" "Recovered W_FLAGS: ${W_FLAGS}"

}


function wifi_network_list(){

	local DEVNAME=$1
	wpa_cli -i ${DEVNAME} list_networks | tail -n +2 | sed -r -e 's/\t/\|/g' > ${TMPFILE}

	NETLIST=""
	LAST_IFS=$IFS
	IFS="|"
	while read NETNUM NETESSID NETBSSID NETFLAGS; do
		IS_DIS=`echo ${NETFLAGS} | sed -r -e 's/\[//g;s/\]//g' | grep -i disabled | wc -l`
		if [ ${IS_DIS} -eq 1 ]; then
		   STATUS="(DIS)"
		else
		   STATUS="(ENAB)"
		fi
		IS_CUR=`echo ${NETFLAGS} | sed -r -e 's/\[//g;s/\]//g' | grep -i current | wc -l`
		if [ ${IS_CUR} -eq 1 ]; then
			STATUS="${STATUS}(CUR)"
		fi

		
		NETLIST="${NETLIST} ${NETNUM} \"${NETESSID}-${STATUS}\""
	done < ${TMPFILE}
	IFS=${LAST_IFS}

	log "_self" "NETLIST: ${NETLIST}"
}


##
## Manage the authentication for a given wifi ESSID
##
function wifi_authenticate(){
	
	local DEVNAME=$1
	local W_MAC=$2


	log "${FUNCNAME[0]}" "configuring ${DEVNAME} on ${W_MAC}"
	## This will set the variable W_ESSID appropriately
	wifi_essid_from_mac ${DEVNAME} ${W_MAC}
	
	## This will set the variable W_FLAGS appropriately
	wifi_flags_from_mac ${DEVNAME} ${W_MAC}

	
	log "${FUNCNAME[0]}" "configuring essid: ${W_ESSID} on device: ${DEVNAME}"
	log "${FUNCNAME[0]}" "W_FLAGS: ${W_FLAGS}"

	
	NET_EXISTS=`wpa_cli -i ${DEVNAME} list_networks | tail -n +2 | sed -r -e 's/\t/\|/g' \
      | cut -d "|" -f 2 | grep "${W_ESSID}$" | wc -l`
	if [ ${NET_EXISTS} -ne 0 ]; then
		NET_NUM=`wpa_cli -i ${DEVNAME} list_networks | tail -n +2 | sed -r -e 's/\t/\|/g' \
      | cut -d "|" -f 1,2 | grep "${W_ESSID}$" | cut -d "|" -f 1`
		wpa_cli -i ${DEVNAME} remove_network ${NET_NUM} > ${TMPFILE}
		STATUS=`<${TMPFILE}`
		if [ ${STATUS} != "OK" ]; then
			eval "${DIALOG}  --msgbox 'Error while removing existing network:\n$essid: {W_ESSID}'"
			${INFO_HEIGHT} ${INFO_WIDTH}
			return
		fi
	fi

	HAS_WPA=`echo "${W_FLAGS}" | grep -E "WPA.*-PSK" | wc -l`

	log "${FUNCNAME[0]}" "HAS_WPA: \"${HAS_WPA}\"" 
	
	### This section will configure WPA-PSK or WPA2-PSK
	if [ ${HAS_WPA} != "0" ]; then
		PSK=""
		PSK_LENGTH=${#PSK}
		while [ ${PSK_LENGTH} -le 7 ]; do
			eval "${DIALOG}  --insecure --inputbox 'Please insert WPA PSK\n(8 characters)' \
				   ${INFO_HEIGHT} ${INFO_WIDTH} 2> ${TMPFILE}"
			if [ $? -eq 1 ]; then
				eval "${DIALOG}  --clear --msgbox 'Network configuration aborted!!!' \
					   ${INFO_HEIGHT} ${INFO_WIDTH}"
				return 1
			fi
			PSK=`<${TMPFILE}`
			PSK_LENGTH=${#PSK}
		done
			
		
		NET_NUM=`wpa_cli -i ${DEVNAME} add_network | tail -1`

		log "${FUNCNAME[0]}" `wpa_cli -i ${DEVNAME} set_network ${NET_NUM} ssid "\"${W_ESSID}\""`
		log "${FUNCNAME[0]}" `wpa_cli -i ${DEVNAME} set_network ${NET_NUM} psk \"${PSK}\"`
		## remove the password from tmpfile
		echo "" > ${TMPFILE}
		eval "${DIALOG}  --clear --defaultno --yesno \
			   'Network \"${W_ESSID}\" added\nSave configuration file?' \
			   ${INFO_HEIGHT} ${INFO_WIDTH} 2> ${TMPFILE}"
		if [ $? -eq 0 ]; then
			## Save the config file
			wifi_save_file ${DEVNAME}
		fi
		
		eval "${DIALOG}  --msgbox 'Network added successfully' ${INFO_HEIGHT} ${INFO_WIDTH}"
		return 0
	fi
	
	HAS_ESS=`echo "${W_FLAGS}" | grep -E "ESS" | wc -l`

	log "_self" "HAS_ESS: \"${HAS_ESS}\""
	
	if [ ${HAS_ESS} != "0" ]; then
		NET_NUM=`wpa_cli -i ${DEVNAME} add_network | tail -1`

		log "_self" "NET_NUM: ${NET_NUM}"
		log "_self" `wpa_cli -i ${DEVNAME} set_network ${NET_NUM} ssid "\"${W_ESSID}\""`
		log "_self" `wpa_cli -i ${DEVNAME} set_network ${NET_NUM} key_mgmt NONE`
		eval "${DIALOG}  --clear --defaultno --yesno \
			   'Network \"${W_ESSID}\" added\nSave configuration file?' \
			   ${INFO_HEIGHT} ${INFO_WIDTH} 2> ${TMPFILE}"
		if [ $? -eq 0 ]; then
			## Save the config file
			wifi_save_file ${DEVNAME}
		fi
		
		return 0
	else
		eval " ${DIALOG}  --msgbox 'Error occurred!!!!' ${INFO_HEIGHT} ${INFO_WIDTH}"
		return 0
	fi
	
	## No available authentication methods....

	eval "${DIALOG}  --msgbox 'No supported authentication method for ${W_ESSID}'"
	return 1
}




##
## Configure a new connection from a list of available wi-fi networks
##

function wifi_add(){

	local DEVNAME=$1
	
	wpa_cli -i ${DEVNAME} scan
	eval "${DIALOG}  --timeout 4 --msgbox 'Scanning for networks...' \
		   ${INFO_HEIGHT} ${INFO_WIDTH}"
	wpa_cli -i ${DEVNAME} scan_results | grep -E "^[0-9a-f][0-9a-f]:" | \
		sed -r -e 's/\t/|/g' |\
		sort -t "|" -r -n -k 3 > ${TMPFILE}

	wifinets=()
	LAST_IFS=$IFS
	IFS="|"
	while read W_MAC W_FREQ W_STRNGT W_FLAGS W_ESSID; do

		log "_self" "W_ESSID: \"${W_ESSID}\""
		wifinets+=(${W_MAC} "${W_ESSID} -- ${W_FLAGS}")
	done < ${TMPFILE}
	IFS=${LAST_IFS}
	

	log "$_self" "Wifi nets: \n${wifinets}\n==="
	dialog  --menu 'Select a network' ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 10 \
		   "${wifinets[@]}" 2> ${TMPFILE}
	if [ $? -eq 1 ]; then
		return
	fi

	W_MAC=$(cat ${TMPFILE})
	

	wifi_authenticate ${DEVNAME} ${W_MAC}
	if [ $? -ne 0 ]; then
		eval "${DIALOG}  --msgbox 'Error while configuring ${DEVNAME}' "
	fi
	return $?
}


function wifi_save_file(){

	local DEVNAME=$1
	
	wpa_cli -i ${DEVNAME} save_config | tail -1 > ${TMPFILE}
	SAVE_STATUS=`<${TMPFILE}`
	if [ ${SAVE_STATUS} == "OK" ]; then
		eval "${DIALOG}  --msgbox 'Current configuration dumped to file ${WPA_FILE}' \
			   ${INFO_HEIGHT} ${INFO_WIDTH}"
	else
		eval "${DIALOG}  --msgbox 'Error while saving configuration to file ${WPA_FILE}' \
			   ${INFO_HEIGHT} ${INFO_WIDTH}"
	fi
}

function wifi_remove(){

	local DEVNAME=$1

	wifi_network_list ${DEVNAME}

	eval "${DIALOG} --menu 'Select network to remove' \
           ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 10 ${NETLIST} \
		   2> ${TMPFILE}"
	
	if [ $? -eq 0 ]; then
		## a network has been selected
		NETNUM=`<${TMPFILE}`
		WPA_STATUS=`wpa_cli -i ${DEVNAME} remove_network ${NETNUM} | tail -1 `
		if [ ${WPA_STATUS} == "OK" ]; then
			eval "${DIALOG}  --clear --defaultno --yesno \
				   'Network ${NETNUM} removed\nSave configuration file?' \
				   ${INFO_HEIGHT} ${INFO_WIDTH} 2> ${TMPFILE}"
			if [ $? -eq 0 ]; then
				## Save the config file
				wifi_save_file ${DEVNAME}
			fi
			
			return
		else
			eval "${DIALOG}  --clear --msgbox 'Network ${NETNUM} NOT removed' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}"
			return
		fi
	else
		eval "${DIALOG}  --clear --msgbox 'No network removed!!!' \
			   ${INFO_HEIGHT} ${INFO_WIDTH}"
		return
	fi
	
}


function wifi_restart_wpa(){

	local DEVNAME=$1
	local WPA_FILE=$2
	
	WPA_PID=`ps ax | grep wpa_supplicant | grep " -i ${DEVNAME}" | 
sed -r -e 's/^\ +//g' | cut -d " " -f 1`

	log "${FUNCNAME[0]}" "WPA_PID: ${WPA_PID}"
	kill -n 9 ${WPA_PID}
	
	if [ $? -ne 0 ]; then
	   eval "${DIALOG}  --clear --msgbox 'Error killing wpa_supplicant' \
			  ${INFO_HEIGHT} ${INFO_WIDTH}"
	fi

	wpa_supplicant -B -i ${DEVNAME} -c ${WPA_FILE} -P${WPA_PIDFILE}
	WPA_PID=`ps ax | grep wpa_supplicant | grep " -i ${DEVNAME}" | cut -d " " -f 1 `
	WPA_PID_SAVED=`<${WPA_PIDFILE}`
	if [ [ -n ${WPA_PID} ] || [ ${WPA_PID} != ${WPA_PID_SAVED} ] ]; then
		eval "${DIALOG}  --clear --msgbox 'Error restarting wpa_supplicant' \
			   ${INFO_HEIGHT} ${INFO_WIDTH}"
	else
		eval "${DIALOG}  --clear --msgbox 'wpa_supplicant restarted successfully' \
			   ${INFO_HEIGHT} ${INFO_WIDTH}"
	fi

}



##
## wifi_enable: show the list of configured networks, and enable the
## one the used has clicked on
##

function wifi_enable(){

	local DEVNAME=$1

	wifi_network_list ${DEVNAME}

	eval "${DIALOG} --menu 'Select configured network' \
		   ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 10 ${NETLIST} \
		   2> ${TMPFILE}"
	
	if [ $? -eq 0 ]; then
		## a network has been selected
		NETNUM=`<${TMPFILE}`
		WPA_STATUS=`wpa_cli -i ${DEVNAME} enable ${NETNUM} | tail -1 `
		if [ ${WPA_STATUS} == "OK" ]; then
			eval "${DIALOG}  --clear --msgbox 'Network ${NETNUM} enabled' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}"
			config_ethernet ${DEVNAME}
			return
		else
			eval "${DIALOG}  --clear --msgbox 'Network ${NETNUM} NOT enabled' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}"
			return
		fi
	else
		eval "${DIALOG}  --clear --msgbox 'No network enabled!!!' \
			   ${INFO_HEIGHT} ${INFO_WIDTH}"
		return
	fi
}


function wifi_disable(){

	local DEVNAME=$1
	wifi_network_list ${DEVNAME}
	eval "${DIALOG}  --menu 'Select configured network' \
          ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 10 ${NETLIST} \
		   2> ${TMPFILE}"
	
	if [ $? -eq 0 ]; then
		## a network has been selected
		NETNUM=`<${TMPFILE}`
		WPA_STATUS=`wpa_cli -i ${DEVNAME} disable ${NETNUM} | tail -1 `
		if [ ${WPA_STATUS} == "OK" ]; then
			eval "${DIALOG}  --clear --msgbox 'Network ${NETNUM} disabled' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}"
			return
		else
			eval "${DIALOG}  --clear --msgbox 'Network ${NETNUM} NOT disabled' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}"
			return
		fi
	else
		eval "${DIALOG}  --clear --msgbox 'No network disabled!!!' \
			   ${INFO_HEIGHT} ${INFO_WIDTH}"
		return
	fi
}



function wifi_load_file(){
	
	local DEVNAME=$1
	
	eval "${DIALOG}  --fselect ${WPA_FILE} ${WINDOW_HEIGHT} ${WINDOW_WIDTH} \
			   2>${TMPFILE}|"
	
	if [ $? -eq 0 ]; then
		SEL_FILE=`<${TMPFILE}`
		while [ -d ${SEL_FILE} ]; do
			eval "${DIALOG}  --fselect ${SEL_FILE} ${WINDOW_HEIGHT} ${WINDOW_WIDTH} \
					   2>${TMPFILE}"
			if [ $? -eq 0 ]; then
				SEL_FILE=`<${TMPFILE}`
			else
				eval "${DIALOG}  --clear --infobox 'WPA_FILE was not modified' \
						   ${INFO_HEIGHT} ${INFO_WIDTH}"
				return
			fi
		done
		
		if [ -f ${SEL_FILE} ]; then
			WPA_FILE=${SEL_FILE}
			eval "${DIALOG}  --clear --defaultno --yesno \
					   'WPA_FILE changed to ${WPA_FILE}\nRestart wpa_supplicant?' \
					   ${INFO_HEIGHT} ${INFO_WIDTH}"
			if [ $? -eq 0 ]; then
				wifi_restart_wpa ${DEVNAME} ${WPA_FILE}
			fi
		else
			eval "${DIALOG}  --clear --infobox 'Invalid file name!\n WPA_FILE *not* changed' \
					  ${WINDOW_HEIGHT} ${WINDOW_WIDTH}"
			return 
		fi
	else
		eval "${DIALOG}  --clear --infobox 'WPA_FILE was not modified' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}"
	fi
	
}


 
function config_wifi(){

	local DEVNAME=$1
	
	while [ 1 -eq 1 ]; do
		eval "${DIALOG}  --clear --cancel-label 'Up' \
			   --menu 'Configuring ${DEVNAME}\n(Current file: ${WPA_FILE})' \
			   ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 12 \
			   'Restart' 'Restart wpa_supplicant' \
			   'Enable' 'Enable a configured network' \
			   'Disable' 'Disable a configured network' \
			   'Add' 'Configure a new network' \
			   'Remove' 'Delete an existing network' \
			   'Show' 'Show current configuration file' \
			   'Edit' 'Edit current configuration file' \
			   'Save' 'Save configuration to file'\
			   'Load' 'Load configuration from file'\
			   'New' 'Create new configuration file'\
		2>${TMPFILE}"
		if [ $? -eq 1 ]; then
			return
		fi
		ACTION=`<${TMPFILE}`
		case ${ACTION} in
			"Restart")
				## Restart wpa_supplicant
				wifi_restart_wpa ${DEVNAME} ${WPA_FILE}
				;;
			"Enable")
				wifi_enable ${DEVNAME}
				;;
			"Disable")
				wifi_disable ${DEVNAME}
				;;
			"Add")
				wifi_add ${DEVNAME}
				;;
			"Remove")
				wifi_remove ${DEVNAME}
				;;
			"Show")
				eval "${DIALOG}  --title 'Current file: ${WPA_FILE}' \
					   --textbox ${WPA_FILE} ${WINDOW_HEIGHT} ${WINDOW_WIDTH}"
				;;
			"Edit")
				edit_file ${WPA_FILE}
				;;
			"Save")
				wifi_save_file ${DEVNAME}
				;;
			"Load")
				wifi_load_file ${DEVNAME}
				;;
			"New")
				eval "${DIALOG}  --msgbox 'Sorry!Not yet implemented!' \
						  ${INFO_HEIGHT} ${INFO_WIDTH} 2>${TMPFILE}"
				;;
		esac
	done

}



##
## (Re)-Configure a network device
##

function configure_device(){

	local DEVNAME=$1
	
	case ${DEVNAME} in
		eth*)
			config_ethernet ${DEVNAME}
			;;
		wlan*)
			config_wifi ${DEVNAME}
			;;
		*)
			eval "${DIALOG}  --clear --title 'ERROR' --msgbox \
			'${DEVNAME}: Unsupported device type' \
			${WINDOW_HEIGHT} ${WINDOW_WIDTH}"
			;;
	esac


}


function set_device_up(){

	local DEVNAME=$1
	
	ip link set ${DEVNAME} up 

}

function set_device_down(){

	local DEVNAME=$1
	
	ip link set ${DEVNAME} down

}

function show_device_menu(){
	
	local DEVNAME=$1
	while [ 1 -eq 1 ]; do 	
		eval "${DIALOG}  --clear --cancel-label 'Up' --menu 'Device: ${DEVNAME}' \
			   ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 8 \
			   'View' 'View current configuration' \
			   'Conf' 'Configure device' \
		       'Start' 'Bring interface up' \
			   'Stop' 'Put interface down' \
			   'Restart' 'Restart interface' 2> ${TMPFILE}"
		
		if [ $? -eq 1 ]; then
			return
		fi
		
		DEV_ACTION=`<${TMPFILE}`
		case ${DEV_ACTION} in
			"View")
				show_device_conf ${DEVNAME}
				;;
			"Conf")
				configure_device ${DEVNAME}
				;;
			"Start")
				set_device_up ${DEVNAME}
				;;
			"Stop") 
				set_device_down ${DEVNAME}
				;;
			"Restart")
				set_device_down ${DEVNAME}
				set_device_up ${DEVNAME}
				;;	
			*)
				;;
	
		esac
	done 	
}

##
## Show all the available network devices
##

function show_devs() {

	DEVFILE=/proc/net/dev
  	DEVICES=`ip link show | awk 'NR % 2 == 1' | cut -d ":" -f 2`

	DEVICE_TAGS=""

	for i in `echo $DEVICES`; do
		if [ $i != "lo" ]; then
			DEVICE_TAGS="${DEVICE_TAGS} $i $i" 
		fi
	done

 	eval "${DIALOG}  --clear --cancel-label 'Up' \
			   --menu 'Select Interface to configure' ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 4 \
			   ${DEVICE_TAGS} 2> ${TMPFILE}"
	return $?
}


function dev_config_menu(){

	while [ 1 -eq 1 ]; do 
		show_devs 
		if [ $? -eq 1 ]; then
			return
		fi
		DEVNAME=`<${TMPFILE}`
		show_device_menu ${DEVNAME}			
	done
}

function show_info(){

	cat <<EOF > ${TMPFILE}

== setnet.sh 0.1 ==

setnet.sh is a simple state-less tool to manage and configure network
interfaces. It is a shell wrapper around the functionalities of "ip",
"dhclient", "wpa_cli", and can be used to configure network
connections via Ethernet/Wi-Fi interfaces.

Both Static and DHCP-based IP configuration is supported. 

At the moment, only WPA-PSK and open (no key) Wi-Fi connections are
available. 

EOF
	eval "${DIALOG}  --clear --cr-wrap --textbox ${TMPFILE} ${WINDOW_HEIGHT} ${WINDOW_WIDTH}"
	return
}

function show_copyright(){

	cat <<EOF > ${TMPFILE}

== setnet.sh 0.1 ==

(c) KatolaZ (katolaz@freaknet.org) -- 2016

EOF
	eval "${DIALOG}  --clear --cr-wrap --textbox ${TMPFILE} ${WINDOW_HEIGHT} ${WINDOW_WIDTH}"
	return
}


function show_license(){

	cat <<EOF > ${TMPFILE}

== setnet.sh 0.1 ==

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

----------------------------------------------------------------------

 (c) KatolaZ <katolaz@freaknet.org> -- 2016

----------------------------------------------------------------------

EOF
	eval "${DIALOG}  --clear --cr-wrap --textbox ${TMPFILE} ${WINDOW_HEIGHT} ${WINDOW_WIDTH}"
	return
}



function about_menu(){

	while [ 1 -eq 1 ]; do 
		eval "${DIALOG}  --cancel-label 'Up' --menu 'setnet ${VERSION} -- About' \
			   ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 6 \
			   'Info' 'General information' \
			   'Copyright' 'Copyright information' \
			   'License' 'How to distribute this program' \
			   2> ${TMPFILE}"
		if [ $? -eq 1 ];then
			return;
		fi
		
		ACTION=`<${TMPFILE}`
		case ${ACTION} in
			"Info")
				show_info
				;;
			"Copyright")
				show_copyright
				;;
			"License")
				show_license
				;;
		esac
	done
}


function show_toplevel(){
	
	eval "${DIALOG} --clear --cancel-label 'Quit' --menu 'Main Menu' \
		   ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 6 \
		   'Setup' 'Setup interfaces' \
		   'About' 'Info & Copyright' 2> ${TMPFILE}"
	return $?
}

function show_help(){

	local SCRIPTNAME=$1
	echo "Usage: ${SCRIPTNAME} [OPTION]"
	echo "Options:"
	echo -e "\t -c cfg_file\tLoad configuration from cfg_file."
	echo -e "\t -v\t\tPrint version number and exit. "
	echo -e "\t -h\t\tShow this help."
	
}

function show_version(){

	local SCRIPTNAME=$1
	echo "${SCRIPTNAME} -- version ${VERSION}"
	echo "Copyright (C) Vincenzo \"KatolaZ\" Nicosia (katolaz@freaknet.org) -- 2016"
	echo "This is free software. You can use and redistribute it under the "
	echo "terms of the GNU General Public Licence version 3 or (at your option)"
	echo "any later version."
	echo 
	echo "YOU USE THIS SOFTWARE AT YOUR OWN RISK."
	echo "There is ABSOLUTELY NO WARRANTY; not even for MERCHANTABILITY or"
	echo "FITNESS FOR A PARTICULAR PURPOSE."
}

function show_disclaimer(){

	cat <<EOF > ${TMPFILE}

                == setnet.sh 0.1 ==

      (c) KatolaZ (katolaz@freaknet.org) -- 2016

    -+- This is the alpha release of setnet.sh -+-
   
                 THIS IS FREE SOFTWARE
        YOU CAN USE AND DISTRIBUTE IT UNDER THE 
        TERMS OF THE GNU GENERAL PUBLIC LICENSE
      
          USE THIS SOFTWARE  AT YOUR OWN RISK

     There is ABSOLUTELY NO WARRANTY; not even for 
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

        See "About" for more information about 
                 copyright and license
EOF

	eval "${DIALOG}  --clear --cr-wrap --textbox ${TMPFILE} 23 60"
	return
}


function main(){

	truncate -s 0 ${LOGFILE}
	trap cleanup 0 $SIG_NONE $SIG_HUP $SIG_INT $SIG_TRAP $SIG_TERM

	show_disclaimer
	
	log "setnet" "Starting afresh on `date`"
	SETNETRC=`realpath ${SETNETRC}`
	log "main" "Using config file \"${SETNETRC}\""
	WPA_FILE=`realpath ${WPA_FILE}`
	log "main" "Using WPA config file \"${WPA_FILE}\""
	LOFGILE=`realpath ${LOGFILE}`
	log "main" "Using log file \"${LOGFILE}\""
	
	while [ 1 -eq 1 ]; do 
		show_toplevel
		if [ $? -eq 1 ]; then
			cleanup
			exit 1
		fi
		ACTION=`<${TMPFILE}`
		case ${ACTION} in
			"Setup")
				dev_config_menu
				;;
			"About")
				about_menu
				;;
		esac
	done

}


##
## Get the options
## 

SETNETRC=""

while getopts ":c:hv" opt; do
	
	case $opt in
		c)
			echo "Got option -c ${OPTARG}"
			SETNETRC=`realpath ${OPTARG}`
			echo "SETNETRC: ${SETNETRC}"
			;;
		h)
			show_help `basename $0`
			exit 1
			;;
		v)
			show_version `basename $0`
			exit 1
			;;
		\?)
			echo "Invalid option: -${OPTARG}"
			exit 1
			;;
		:)
			echo "Option -${OPTARG} requires an argument"
			exit 1
			;;
	esac
done



load_setnetrc ${SETNETRC}

main 


