#!/bin/sh

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
# Copyleft (C) Vincenzo "KatolaZ" Nicosia (katolaz@freaknet.org) --
# (2016, 2017)
#
#


##
## Initialisation
## 

VERSION=0.3.2


TOPSTR="setnet-${VERSION} [user: $(id -run)]"
DIALOG="dialog --backtitle \"${TOPSTR}\" --clear "


###############################
##                           ##
## Internal config variables ##
##                           ##
###############################

##
## Required dependencies. If any of those commands is missing,
## the script will exit
##

HARD_DEPS="ip dhclient dialog iw sed grep cat awk which"

##
## Suggested dependencies. The script will issue a warning if any of
## those commands is missing
##

SOFT_DEPS="wpa_cli wpa_supplicant"

##
## Optional dependencies. The script will check if those dependencies
## exist, and if they do, will set a variable HAS_OPTS which contains
## the names of the commands actually found
##

OPT_DEPS="host ping traceroute netstat pastebinit"

#################################

#####################################
##                                 ##
## HEIGHT/WIDTH of various dialogs ##
##                                 ##
#####################################

##
## Regular windows
##

WINDOW_WIDTH=75
WINDOW_HEIGHT=20

##
## Infoboxes
##
INFO_WIDTH=40
INFO_HEIGHT=10


##
## Forms
##
FORM_WIDTH=60
FORM_HEIGHT=12

##
## Large windows
##

LARGE_WIDTH=80
LARGE_HEIGHT=20


#################################

################################
##                            ##
## Supported network families ##
##                            ##
################################

NET_FAMILIES="inet inet6"

#################################

##
## Load the configuration file "setnetrc"
##

##function 
load_setnetrc(){

	WPA_FILE=""
	LOGFILE=""
	## If we were given a parameter, that is the rc file to load...
	##	
	if [ $# -ge 1 ]; then
		  . "$1"
		return
	fi
	
	##
	## Otherwise, let's look in the standard locations, namely:
	##

	##
	## 1) /etc/setnetrc
	##

	if [ -f /etc/setnetrc ]; then
     SETNETRC=/etc/setnetrc
	fi

	##
	## 2) ~/.setnetrc
	##

	if [ -f ~/.setnetrc ]; then
     SETNETRC=~/.setnetrc
	fi

	if [ -n "${SETNETRC}" ] &&
	   [ -f "${SETNETRC}" ]; then 
		. ${SETNETRC}
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


##
## handler called upon exit/signal (NONE HUP INT TRAP TERM QUIT)
##

##function 
cleanup(){
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
##
##function 
log(){
    
    ##local
    LABEL=$1
    ##local
    MSG=$2
    
	  echo  "${LABEL}:" "${MSG}" >> "${LOGFILE}"
	  
}

##
## Check whether the shell which called the script is supported, or
## exit. Currently, we support the follwing shells:
##
## - bash
## - busybox
## - dash
## - ksh
## - mksh
## - posh
## - sh
## - yash
##

##function
check_shell(){

    ##
    ## FIXME!!! THIS TEST DOES NOT WORK yet...
    ##

	SCRIPT_CMD=$(ps $$ | tail -1 | sed -r -e 's/\ +/\ /g;s/^\ +//g' | cut -d " " -f 5)
	CUR_SH=$(basename ${SCRIPT_CMD})

    case ${CUR_SH} in
        ash|bash|busybox|dash|ksh|mksh|posh|sh|yash|zsh)
            log "check_shell" "The current shell (${CUR_SH}) is supported"
            return
            ;;
        *)
            log "check_shell" "The current shell (${CUR_SH}) is not supported"
            echo "The current shell (${CUR_SH}) is not supported. Exiting..."
            exit 1
            ;;
    esac
}


##
## Check dependencies
##
## - check if the current shell is supported through check_shell, and
##   set the variable CUR_SH accordingly
##
## - each command in HARD_DEPS MUST exist, or the script exits
##
## - each command in SOFT_DEPS SHOULD exist, or the script will log a
##   warning
##
## - each command in OPT_DEPS MIGHT exist, and if it does its name is
##   included in the variable "HAS_OPTS"
##

##function
check_deps(){

	check_shell

	## Workaround for zsh 
	if [ "${CUR_SH}" = "zsh" ]; then
		setopt shwordsplit
	fi
    
    for h in $(echo ${HARD_DEPS}); do
        _W=$(which ${h})
        if [ -z "${_W}" ]; then
            echo "Error: required command \"${h}\" not found. Exiting..."
            exit 1
        fi
        log "check_deps" "NOTICE: required command '${h}'...found"
    done
    
    for s in $(echo ${SOFT_DEPS}); do
        _S=$(which ${s})
        if [ -z "${_S}" ]; then
            log "check_deps" "WARNING: suggested command '${s}' not found! Some functions might not work properly"
        fi
    done

    HAS_OPTS=""
    for o in $(echo  ${OPT_DEPS}); do
        _O=$(which ${o})
        if [ -n "${_O}" ]; then
            HAS_OPTS=" ${HAS_OPTS} ${o} "
            log "check_deps" "NOTICE: optional command '${o}'...found"
        else
            log "check_deps" "NOTICE: optional command '${o}' not found!"
        fi
    done

    log "check_deps" "HAS_OPTS: \"${HAS_OPTS}\""
    
}


##
## Set debug mode -- dialog is instructed to dump a trace to the file
## TRACE_FILE provided by the user
##

##function
set_debug(){

	TRACE_FILE=$1
	DEBUG_MODE="DEBUG"
	DIALOG="${DIALOG} --trace ${TRACE_FILE}"

}


##
## Generic function for unimplemented features. It just pops up a
## message-box and returns
##

##function
unimplemented(){

    LABEL=$1
    
		eval "${DIALOG}  --msgbox 'Sorry! '$LABEL' not implemented, yet!' \
						  ${INFO_HEIGHT} ${INFO_WIDTH}" 2>${TMPFILE}
}


##function
check_sudo(){

	LABEL="$1"

	if [ "${USING_SUDO}" = "1" ]; then
		eval "${DIALOG} --msgbox '${LABEL}' ${INFO_HEIGHT} ${INFO_WIDTH} " 2>${TMPFILE}
		return 1
	else
		return 0
	fi

}

##
## Check the output of a command provided as argument against an
## expected output. Return 1 if the check fails, otherwise return 0
##
##function
chk_out(){
	
	EXP_OUT=$1
	shift
	log "chk_out" "check output of: $(echo $@)"
	ACT_OUT=$($@)
	[ "${ACT_OUT}" = "${EXP_OUT}" ] || \
		log "chk_out" "Error: got '${ACT_OUT}' when expecting '${EXP_OUT}'" && \
			return 1
	return 0
	
}


##
## Check the exit value of a command provided as argument against an
## expected output -- return 1 if the check fails, otherwise return 0
##
##function
chk_exit(){
	
	EXP_EXIT=$1
	shift
	log "chk_exit" "check exit value of: $(echo $@)"
	$@
	ACT_EXIT=$?
	[ "${ACT_EXIT}" = "${EXP_EXIT}" ] || \
		log "chk_exit" "Error: got '${ACT_EXIT}' when expecting '${EXP_EXIT}'" && \
			return 1
	return 0
}



##########################################

##function 
edit_file(){

    ##local 
    FILEIN=$1
	  log "edit_file" "editing file ${FILEIN}"
	  eval "${DIALOG} --title 'Editing file: ${FILEIN}' \
			--editbox ${FILEIN} ${WINDOW_HEIGHT} ${WINDOW_WIDTH}" 2> ${TMPFILE}
    
	  if [ $? -eq 0 ]; then
		    log "edit_file" "Copying ${TMPFILE} into ${FILEIN}"
		    if cp "${TMPFILE}" "${FILEIN}"
		    then
			      eval "${DIALOG}    --msgbox 'File ${FILEIN} saved successfully' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}"
		    else
			      eval "${DIALOG}    --msgbox 'Error saving file ${FILEIN}' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}"
		    fi
	  else
		    log "edit_file" "Editing of ${FILEIN} aborted..."
		    eval "${DIALOG}    --msgbox 'File ${FILEIN} not saved' \
			   ${INFO_HEIGHT} ${INFO_WIDTH}"
	  fi
}




##
## Read all the configured addresses for a given inet family
##
##function 
get_addr_family(){
	
##local 
    DEVNAME=$1
    ##local 
    DEVFAMILY=$2
    
    NUMADDR=$(ip -f "${DEVFAMILY}" addr show "${DEVNAME}" | grep -c "${DEVFAMILY}")
	  ADDR_STR=""
	  for i in $(seq ${NUMADDR}); do 
		    ADDR=$(ip -f "${DEVFAMILY}" addr show "${DEVNAME}" | grep "${DEVFAMILY}" | \
			                tail -n +$i | head -1 | sed -r -e "s:^\ +::g" | cut -d " " -f 2,4,6 |\
			                sed -r -e "s:\ : -- :g")
		    ADDR_STR="${ADDR_STR}\n${DEVFAMILY}: ${ADDR}\n"
	  done
}

##
## Show the current configuration of a given device
##

##function 
show_device_conf(){

##local 
DEVNAME=$1
	if [ -z "${DEVNAME}" ]; then
		return -1
	fi

	DEVMAC=$(ip link show "${DEVNAME}" | tail -n +2 | sed -r 's/^\ +//g' | cut -d " " -f 2)
	DEV_STATUS=$(ip -o link | cut -d " " -f 2,9 | grep -E "^${DEVNAME}: " | cut -d " " -f 2)
	
	DEVCONF="MAC: ${DEVMAC}\nLINK STATUS: ${DEV_STATUS}\n"

	log "show_device_conf" "NET_FAMILIES: \"${NET_FAMILIES}\""
	
	for f in ${NET_FAMILIES}; do
		  get_addr_family ${DEVNAME} ${f}
		  log "show_device_conf" "family: ${f} ADDR_STR: \"${ADDR_STR}\""
		
		if [ -z "${ADDR_STR}" ]; then 
			DEVCONF="${DEVCONF}${f}: Unconfigured\n"
		else
			DEVCONF="${DEVCONF}${ADDR_STR}"
		fi
		log "show_device_conf" "DEVCONF: ${DEVCONF}"
	done

	DEVCONF="${DEVCONF}\n== name servers ==\n$(grep '^nameserver' /etc/resolv.conf)"
	
	eval "${DIALOG}    --title 'Current configuration of device: ${DEVNAME}' \
		--msgbox '\n\n${DEVCONF}' ${WINDOW_HEIGHT} ${WINDOW_WIDTH} "
	return 0

}



##function 
config_ip_static(){

	##local 
	DEV_IP="192.168.1.2"
	##local 
	DEV_NET="192.168.1.0"
	##local 
	DEV_NETMASK="255.255.255.0"
	##local 
	DEV_GW="192.168.1.1"
	##local 
	DEV_DNS1="208.67.222.222"
	##local 
	DEV_DNS2="208.67.220.220"
	
	##local 
	DEVNAME=$1
	
	
	eval "${DIALOG}   --form 'Set network for device: ${DEVNAME}' \
	${FORM_HEIGHT} ${FORM_WIDTH} 6 \
	'IP'            1 1 '${DEV_IP}'    1 16 16 16 \
	'Network'       2 1 '${DEV_NET}'    2 16 16 16 \
	'Netmask'       3 1 '${DEV_NETMASK}'  3 16 16 16 \
	'Gateway'       4 1 '${DEV_GW}'    4 16 16 16 \
	'Primary DNS'   5 1 '${DEV_DNS1}' 5 16 16 16 \
	'Secondary DNS' 6 1 '${DEV_DNS2}' 6 16 16 16 " \
		 2> ${TMPFILE}

	if [ $? -eq 1 ]; then 
		eval "${DIALOG}  --infobox 'Configuration of ${DEVNAME} aborted' \
		${INFO_HEIGHT} ${INFO_WIDTH}"
		return
	fi

	cat ${TMPFILE} | tr '\n' ' ' >${TMPFILE}_2
	
	read DEV_IP DEV_NET DEV_NETMASK DEV_GW DEV_DNS1 DEV_DNS2 <${TMPFILE}_2
	eval "${DIALOG}  --msgbox 'Proposed configuration of ${DEVNAME}:\n \
IP: ${DEV_IP}\nNetwork: ${DEV_NET}\nNetmask: ${DEV_NETMASK}\nGateway: \
${DEV_GW}\nDNS1: ${DEV_DNS1}\nDNS2: ${DEV_DNS2}'\
		${WINDOW_HEIGHT} ${WINDOW_WIDTH}"

	rm -f ${TMPFILE}_2
	## Configure IP
	
	chk_exit 0 ip link set "${DEVNAME}" down
	chk_exit 0 ip link set "${DEVNAME}" up
	chk_exit 0 ip address flush dev "${DEVNAME}"
	chk_exit 0 ip address add "${DEV_IP}/${DEV_NETMASK}" dev "${DEVNAME}"
	
	## Configure GW
	#if [ -n "${DEV_GW}" ]; then 
	chk_exit 0 ip route flush dev "${DEVNAME}"
	chk_exit 0 ip route add "${DEV_NET}/${DEV_NETMASK}" dev "${DEVNAME}"
	chk_exit 0 ip route add default via "${DEV_GW}"
	#fi
	## Configure DNS
	#if [ -n "${DEV_DNS1}" ] ||
	#	   [ -n "${DEV_DNS1}" ]; then
		mv /etc/resolv.conf /etc/resolv.conf.bak
		if [ -n "${DEV_DNS1}" ]; then
			echo "nameserver ${DEV_DNS1}" >> /etc/resolv.conf
		fi
		if [ -n "${DEV_DNS2}" ]; then
			echo "nameserver ${DEV_DNS2}" >> /etc/resolv.conf
		fi
		show_device_conf "${DEVNAME}"
	#fi
}

##function 
config_ip_dhcp(){

##local 
	DEVNAME=$1

	##eval "${DIALOG}  --msgbox 'Running \"dhclient ${DEVNAME}\"' ${INFO_HEIGHT} ${INFO_WIDTH}"
	dhclient -r ${DEVNAME}  2>/dev/null
	dhclient -v ${DEVNAME} 2>&1 |
		eval "${DIALOG}  --title 'Running dhclient ${DEVNAME}' \
                 --programbox  ${WINDOW_HEIGHT} ${WINDOW_WIDTH}" 2>${TMPFILE}
    if [ $! -ne 0 ];then
		log "config_ip_dhcp" "dhclient aborted"
	fi
	show_device_conf ${DEVNAME}
}


##function 
configure_ip_address(){

##local 
    DEVNAME=$1
	  
	eval "${DIALOG}   --cancel-label 'Up' \
		--menu 'Configuring ${DEVNAME}' ${INFO_HEIGHT} ${INFO_WIDTH} 4 \
		'DHCP' ''\
		'Static' ''" 2>${TMPFILE}
	if [ $? -eq 1 ]; then
		return
	fi
	ACTION=$(cat ${TMPFILE})
	case ${ACTION} in
		"Static")
			config_ip_static ${DEVNAME}
			;;
		"DHCP")
			config_ip_dhcp ${DEVNAME}
			;;
	esac
}

##function 
wifi_essid_from_mac(){

    ##local 
    DEVNAME=$1
    ##local 
    W_MAC=$2
	  
    W_ESSID=$(wpa_cli -i "${DEVNAME}" scan_results | grep -E "^${W_MAC}" | \
       sed -r -e 's/\t/\|/g' | cut -d "|" -f 5)

	log "wifi_essid_from_mac" "Recovered ESSID: ${W_ESSID}"
}

##function 
wifi_flags_from_mac(){
##local 
    DEVNAME=$1
##local 
    W_MAC=$2

    W_FLAGS=$(wpa_cli -i "${DEVNAME}" scan_results | grep -E "^${W_MAC}" | \
       sed -r -e 's/\t/\|/g' | cut -d "|" -f 4)
	  log "wifi_essid_from_mac" "Recovered W_FLAGS: ${W_FLAGS}"
    
}


##function 
wifi_network_list(){

##local 
    DEVNAME=$1
	  wpa_cli -i ${DEVNAME} list_networks | tail -n +2 | sed -r -e 's/\t/\|/g' > ${TMPFILE}
    
	  NETLIST=""
	  LAST_IFS=$IFS
	  IFS="|"
	  while read NETNUM NETESSID NETBSSID NETFLAGS; do
		    IS_DIS=$(echo ${NETFLAGS} | sed -r -e 's/\[//g;s/\]//g' | grep -c -i disabled )
		    if [ ${IS_DIS} -eq 1 ]; then
		        STATUS="(DIS)"
		    else
		        STATUS="(ENAB)"
		    fi
		    IS_CUR=$(echo ${NETFLAGS} | sed -r -e 's/\[//g;s/\]//g' | grep -c -i current )
		    if [ ${IS_CUR} -eq 1 ]; then
			      STATUS="${STATUS}(CUR)"
		    fi
        
		    
		    NETLIST="${NETLIST} ${NETNUM} \"${NETESSID}-${STATUS}\""
	  done < ${TMPFILE}
	  IFS=${LAST_IFS}
    
	  log "wifi_network_list" "NETLIST: ${NETLIST}"
}

##function
wpa_authenticate_EAP_TLS(){

	##unimplemented "wpa_authenticate_EAP_TLS"
	##return 1

	
	DEVNAME=$1
	W_ESSID=$2

	## We first add the new network
	NET_NUM=$(wpa_cli -i ${DEVNAME} add_network | tail -1)
    
	log "wifi_authenticate_EAP_PEAP" "NET_NUM: ${NET_NUM}"
	chk_out "OK" wpa_cli -i ${DEVNAME} set_network ${NET_NUM} ssid "\"${W_ESSID}\""

	
	## we get the needed information, namely:
	##
	## - identity
	## - server certificate (ca_cert)
	## - client certificate
	## - 
	## 

	eval "${DIALOG} --form 'PEAP parameters:' \
		 ${FORM_HEIGHT} ${FORM_WIDTH} 3 \
	'identity'      1 1 ''    1 20 30 80 \
    'server certificate' 2 1 '' 2 20 30 200 \
    'client certificate' 3 1 '' 3 20 30 200 \
    'private key'        4 1 '' 4 20 30 200 \
    'private key password' 5 1 '' 5 30 30 80 \
	" 2>${TMPFILE}

	if [ $? != "0" ]; then
		log "wifi_authenticate_EAP_TLS" "Aborting EAP/TLS authentication"
		wpa_cli -i ${DEVNAME} remove_network ${NET_NUM}
		return 1
	fi

	##
	## Now, this is not super-clean, but seems necessary to maintain
	## POSIX shell compatibility
	##
	cat ${TMPFILE} | tr '\n' ' ' >${TMPFILE}_2
	read EAP_IDENTITY EAP_SERV_CERT  EAP_CLIENT_CERT EAP_PRIV_KEY EAP_PRIV_KEY_PWD <${TMPFILE}_2
	rm -f ${TMPFILE}_2
	## Remove everything from the temp file
	echo "" > ${TMPFILE}


	chk_out "OK" wpa_cli -i ${DEVNAME} set_network ${NET_NUM} key_mgmt WPA-EAP

	## Set eap to PEAP
	chk_out "OK" wpa_cli -i ${DEVNAME} set_network ${NET_NUM} eap TLS
	## Set identity
	chk_out "OK" wpa_cli -i ${DEVNAME} set_network ${NET_NUM} identity "\"${EAP_IDENTITY}\""

	chk_out "OK" wpa_cli -i ${DEVNAME} set_network ${NET_NUM} ca_cert "\"${EAP_SERV_CERT}\""
	chk_out "OK" wpa_cli -i ${DEVNAME} set_network ${NET_NUM} client_cert "\"${EAP_CLIENT_CERT}\""
	chk_out "OK" wpa_cli -i ${DEVNAME} set_network ${NET_NUM} private_key "\"${EAP_PRIV_KEY}\""
	chk_out "OK" wpa_cli -i ${DEVNAME} set_network ${NET_NUM} private_key_passwd "\"${EAP_PRIV_KEY_PWD}\""

	eval "${DIALOG}   --defaultno --yesno \
			   'Network \"${W_ESSID}\" configured\nSave configuration file?' \
			   ${INFO_HEIGHT} ${INFO_WIDTH} " 2> ${TMPFILE}
	if [ $? -eq 0 ]; then
		## Save the config file
		wifi_save_file ${DEVNAME}
	fi
	
	## We can now enable the network
	chk_out "OK" wpa_cli -i ${DEVNAME} enable_network ${NET_NUM}
	
	return 0
	
}


##function
wpa_authenticate_EAP_PEAP(){

	##unimplemented "wpa_authenticate_EAP_PEAP"

	DEVNAME=$1
	W_ESSID=$2

	## We first add the new network
	NET_NUM=$(wpa_cli -i ${DEVNAME} add_network | tail -1)
    
	log "wifi_authenticate_EAP_PEAP" "NET_NUM: ${NET_NUM}"
	chk_out "OK" wpa_cli -i ${DEVNAME} set_network ${NET_NUM} ssid "\"${W_ESSID}\""

	
	## we get the needed information, namely:
	##
	## - identity
	## - password
	## - server certificate (ca_cert)
	## 

	eval "${DIALOG} --form 'PEAP parameters:' \
		 ${FORM_HEIGHT} ${FORM_WIDTH} 3 \
	'identity'      1 1 ''    1 20 30 80 \
	'password'      2 1 ''    2 20 30 80 \
    'server certificate' 3 1 '' 3 20 30 80 \
	" 2>${TMPFILE}

	if [ $? != "0" ]; then
		log "wifi_authenticate_EAP_PEAP" "Aborting EAP/PEAP authentication"
		wpa_cli -i ${DEVNAME} remove_network ${NET_NUM}
		return 1
	fi

	##
	## Now, this is not super-clean, but seems necessary to maintain
	## POSIX shell compatibility
	##
	cat ${TMPFILE} | tr '\n' ' ' >${TMPFILE}_2
	read EAP_IDENTITY EAP_PASSWORD EAP_CERT <${TMPFILE}_2
	rm -f ${TMPFILE}_2
	## Remove identity and password from the temp file
	echo "" > ${TMPFILE}
	
	log "wpa_authenticate_EAP_PEAP" "EAP_IDENTITY: ${EAP_IDENTITY}"
	log "wpa_authenticate_EAP_PEAP" "EAP_PASSWORD: ${EAP_PASSWORD}"
	log "wpa_authenticate_EAP_PEAP" "EAP_CERT: ${EAP_CERT}"
	
	chk_out "OK" wpa_cli -i ${DEVNAME} set_network ${NET_NUM} key_mgmt WPA-EAP

	## Set eap to PEAP
	chk_out "OK" wpa_cli -i ${DEVNAME} set_network ${NET_NUM} eap PEAP
	## Set identity and password
	chk_out "OK" wpa_cli -i ${DEVNAME} set_network ${NET_NUM} identity "\"${EAP_IDENTITY}\""
	chk_out "OK" wpa_cli -i ${DEVNAME} set_network ${NET_NUM} password "\"${EAP_PASSWORD}\""
	if [ -n "${EAP_CERT}" ]; then 
		chk_out "OK" wpa_cli -i ${DEVNAME} set_network ${NET_NUM} ca_cert "\"${EAP_CERT}\""
	fi
	
	eval "${DIALOG}   --defaultno --yesno \
			   'Network \"${W_ESSID}\" configured\nSave configuration file?' \
			   ${INFO_HEIGHT} ${INFO_WIDTH} " 2> ${TMPFILE}
	if [ $? -eq 0 ]; then
		## Save the config file
		wifi_save_file ${DEVNAME}
	fi

	
	## We can now enable the network
	chk_out "OK" wpa_cli -i ${DEVNAME} enable_network ${NET_NUM}
	
	return 0
	
}


##
## Open access point -- no WPA
##
##function
wifi_authenticate_NONE(){

	DEVNAME="$1"
	W_ESSID="$2"

	NET_NUM=$(wpa_cli -i ${DEVNAME} add_network | tail -1)
    
	log "wifi_authenticate" "NET_NUM: ${NET_NUM}"
	chk_out "OK" wpa_cli -i ${DEVNAME} set_network ${NET_NUM} ssid "\"${W_ESSID}\""
	chk_out "OK" wpa_cli -i ${DEVNAME} set_network ${NET_NUM} key_mgmt NONE
	eval "${DIALOG}   --defaultno --yesno \
			   'Network \"${W_ESSID}\" added\nSave configuration file?' \
			   ${INFO_HEIGHT} ${INFO_WIDTH} " 2> ${TMPFILE}
	if [ $? -eq 0 ]; then
		## Save the config file
		wifi_save_file ${DEVNAME}
	fi

	## We can now enable the network
	chk_out "OK" wpa_cli -i ${DEVNAME} enable_network ${NET_NUM}

	return 0
	
}


##function
wpa_authenticate_PSK(){

	DEVNAME=$1
	W_ESSID="$2"
	
	PSK=""
	PSK_LENGTH=${#PSK}
	while [ ${PSK_LENGTH} -le 7 ]; do
		eval "${DIALOG}  --insecure --inputbox 'Please insert WPA PSK\n(min 8 characters)' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}"  2> ${TMPFILE}
		if [ $? -eq 1 ]; then
			eval "${DIALOG}   --msgbox 'Network configuration aborted!!!' \
					   ${INFO_HEIGHT} ${INFO_WIDTH}"
			return 1
		fi
		PSK=$(cat ${TMPFILE})
		PSK_LENGTH=${#PSK}
	done
	
	
	NET_NUM=$(wpa_cli -i ${DEVNAME} add_network | tail -1)

	log "wifi_authenticate_PSK" "NET_NUM: ${NET_NUM}"
	log "wifi_authenticate_PSK" "W_ESSID: ${W_ESSID}"
	log "wifi_authenticate_PSK" "PSK: ${PSK}"

	
	chk_out "OK" wpa_cli -i ${DEVNAME} set_network ${NET_NUM} ssid "\"${W_ESSID}\""
	chk_out "OK" wpa_cli -i ${DEVNAME} set_network ${NET_NUM} psk "\"${PSK}\""
	## remove the password from tmpfile
	echo "" > ${TMPFILE}
	eval "${DIALOG}   --defaultno --yesno \
			   'Network \"${W_ESSID}\" added\nSave configuration file?' \
			   ${INFO_HEIGHT} ${INFO_WIDTH} " 2> ${TMPFILE}
	if [ $? -eq 0 ]; then
		## Save the config file
		wifi_save_file ${DEVNAME}
	fi

	## We can now enable the network
	chk_out "OK" wpa_cli -i ${DEVNAME} enable_network ${NET_NUM}
	
	eval "${DIALOG}  --msgbox 'Network added successfully' ${INFO_HEIGHT} ${INFO_WIDTH}"
	return 0
	

}

##
## Manage WPA authentication. Choose among the available
## authentication systems currently supported:
##
## - PSK
## - EAP/PEAP
## - EAP/TLS
##

##function
wifi_authenticate_WPA(){

	DEVNAME=$1
	W_ESSID=$2

	##
	## Construct the menu with all the available authentication modes
	##
	MODES=$(echo $W_FLAGS | sed -r -e 's/\]\[/\n/g;s/\[//g;s/\]//g' | grep -E "^WPA")
	log "wifi_authenticate_WPA" "MODES: ${MODES}"
	MENU_ITEMS=""
	CNT=0
	for m in ${MODES}; do
		WPA_TYPE=$(echo ${m} | cut -d "-" -f 1)
		HAS_PSK=$(echo ${m} | cut -d "-" -f 2 | grep "PSK")
		if [ "${HAS_PSK}" != "" ]; then
			MENU_ITEMS="${MENU_ITEMS} '${WPA_TYPE}+PSK' 'Pre-shared key' "
		fi

		HAS_EAP=$(echo ${m} | cut -d "-" -f 2 | grep "EAP")
		if [ "${HAS_EAP}" != "" ]; then
			MENU_ITEMS="${MENU_ITEMS} '${WPA_TYPE}+EAP/PEAP' 'EAP/PEAP' "
			MENU_ITEMS="${MENU_ITEMS} '${WPA_TYPE}+EAP/TLS' 'EAP/TLS' "
		fi
	done

	log "wifi_authenticate_WPA" "MENU_ITEMS: ${MENU_ITEMS}"

	
	eval "${DIALOG}  --menu 'Select authentication' ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 10 \
		   ${MENU_ITEMS} " 2> ${TMPFILE}

	if [ $? != "0" ]; then
		## conf aborted
		log "wifi_authenticate_WPA" "configuration aborted"
		return 1;
	fi
		 
	
	SEL_MODE=$(cat ${TMPFILE})
	log "wifi_authenticate_WPA" "SEL_MODE: ${SEL_MODE}" 
	case ${SEL_MODE} in
		"WPA+EAP/PEAP"|"WPA2+EAP/PEAP")
		    wpa_authenticate_EAP_PEAP ${DEVNAME} ${W_ESSID}
		;;
		"WPA+EAP/TLS"|"WPA2+EAP/TLS")
			wpa_authenticate_EAP_TLS ${DEVNAME} ${W_ESSID}
		;;
		"WPA+PSK"|"WPA2+PSK")
			wpa_authenticate_PSK ${DEVNAME} ${W_ESSID}
			;;
		*)
			log "wifi_authenticate_WPA" "Error. SEL_MODE '${SEL_MODE}' unsupported"
		
	esac
	
	
}



##
## Manage the authentication for a given wifi ESSID
##
## We use wpa_cli to check the type of authentication supported by the
## network, and then we call the corresponding function 
##

##function 
wifi_authenticate(){
	
##local 
    DEVNAME=$1
	##local 
    W_MAC=$2
	
	
    log "wifi_authenticate" "configuring ${DEVNAME} on ${W_MAC}"
	## This will set the variable W_ESSID appropriately
	wifi_essid_from_mac ${DEVNAME} ${W_MAC}
	
	## This will set the variable W_FLAGS appropriately
	wifi_flags_from_mac ${DEVNAME} ${W_MAC}
    
	
	log "wifi_authenticate" "configuring essid: ${W_ESSID} on device: ${DEVNAME}"
	log "wifi_authenticate" "W_FLAGS: ${W_FLAGS}"


	## If the network exists already, we first remove it...
	
	NET_EXISTS=$(wpa_cli -i ${DEVNAME} list_networks | tail -n +2 | sed -r -e 's/\t/\|/g' \
                        | cut -d "|" -f 2 | grep -c "${W_ESSID}$" )
	if [ ${NET_EXISTS} != 0 ]; then
		NET_NUM=$(wpa_cli -i ${DEVNAME} list_networks | tail -n +2 | sed -r -e 's/\t/\|/g' \
                         | cut -d "|" -f 1,2 | grep "${W_ESSID}$" | cut -d "|" -f 1)
		STATUS=$(wpa_cli -i ${DEVNAME} remove_network ${NET_NUM})
		if [ "${STATUS}" != "OK" ]; then
			eval "${DIALOG}  --msgbox 'Error while removing existing \
 network:\n$essid: {W_ESSID}'" ${INFO_HEIGHT} ${INFO_WIDTH}
			return
		fi
	fi

	## Check whether WPA is available
	
	HAS_WPA=$(echo "${W_FLAGS}" | grep -E -c "WPA" )
    
	log "wifi_authenticate" "HAS_WPA: \"${HAS_WPA}\"" 
	
	### This will configure WPA
	if [ "${HAS_WPA}" != "0" ]; then
		wifi_authenticate_WPA ${DEVNAME} ${W_ESSID}
		if [ $? = "0" ]; then
			log "wifi_authenticate" "WPA configured"
			return 0
		fi
	fi

	log "wifi_authenticate" "WPA authentication failed, aborted, or not supported"

	### ...otherwise, try to configure an open connection (key_mgmt=NONE)
	
	log "wifi_authenticate" "Trying open (no WPA) configuration..."
	
	wifi_authenticate_NONE ${DEVNAME} ${W_ESSID}
	if [ $? = "0" ]; then
		log "wifi_authenticate" "Open connection configured"
		return 0
	fi

	log "wifi_authenticate" "Open connection not supported"
	
	## No available authentication methods....
    
	eval "${DIALOG}  --msgbox 'No supported authentication method for ${W_ESSID}'"
	return 1
}




##
## Configure a new connection from a list of available wi-fi networks
##

##function 
wifi_add(){

##local 
DEVNAME=$1
	
	wpa_cli -i ${DEVNAME} scan
	eval "${DIALOG}  --timeout 4 --msgbox 'Scanning for networks...' \
		   ${INFO_HEIGHT} ${INFO_WIDTH}"
	wpa_cli -i ${DEVNAME} scan_results | grep -E "^[0-9a-f][0-9a-f]:" | \
		sed -r -e 's/\t/|/g' |\
		sort -t "|" -r -n -k 3 > ${TMPFILE}

	wifinets=""
	LAST_IFS=$IFS
	IFS="|"
	while read W_MAC W_FREQ W_STRNGT W_FLAGS W_ESSID; do

		log "wifi_add" "W_ESSID: \"${W_ESSID}\""
		wifinets="${wifinets} ${W_MAC} \"${W_ESSID} -- ${W_FLAGS}\""
	done < ${TMPFILE}
	IFS=${LAST_IFS}
	

	log "wifi_add" "Wifi nets: \n${wifinets}\n==="
	eval "dialog  --menu 'Select a network' ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 10 \
		   ${wifinets} " 2> ${TMPFILE}
	if [ $? -eq 1 ]; then
		return
	fi

	W_MAC=$(cat ${TMPFILE})
	

	wifi_authenticate ${DEVNAME} ${W_MAC}
	if [ $? != "0" ]; then
		eval "${DIALOG}  --msgbox 'Error while configuring ${DEVNAME}' "
	fi
	return $?
}


##function 
wifi_save_file(){

##local 
DEVNAME=$1
	
	SAVE_STATUS=$(wpa_cli -i ${DEVNAME} save_config | tail -1 )
	if [ "${SAVE_STATUS}" = "OK" ]; then
		eval "${DIALOG}  --msgbox 'Current configuration dumped to file ${WPA_FILE}' \
			   ${INFO_HEIGHT} ${INFO_WIDTH}"
	else
		eval "${DIALOG}  --msgbox 'Error while saving configuration to file ${WPA_FILE}' \
			   ${INFO_HEIGHT} ${INFO_WIDTH}"
	fi
}

##function 
wifi_remove(){

##local 
    DEVNAME=$1
    
	  wifi_network_list ${DEVNAME}
    
	  eval "${DIALOG} --menu 'Select network to remove' \
           ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 10 ${NETLIST}" \
		   2> ${TMPFILE}
	  
	  if [ $? -eq 0 ]; then
		    ## a network has been selected
		    NETNUM=$(cat ${TMPFILE})
		    WPA_STATUS=$(wpa_cli -i ${DEVNAME} remove_network ${NETNUM} | tail -1 )
		    if [ "${WPA_STATUS}" = "OK" ]; then
			      eval "${DIALOG}   --defaultno --yesno \
				   'Network ${NETNUM} removed\nSave configuration file?' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}" 2> ${TMPFILE}
			      if [ $? -eq 0 ]; then
				        ## Save the config file
				        wifi_save_file ${DEVNAME}
			      fi
			      
			      return
		    else
			      eval "${DIALOG}   --msgbox 'Network ${NETNUM} NOT removed' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}"
			      return
		    fi
	  else
		    eval "${DIALOG}   --msgbox 'No network removed!!!' \
			   ${INFO_HEIGHT} ${INFO_WIDTH}"
		    return
	  fi
	  
}


##function 
wifi_restart_wpa(){

##local 
    DEVNAME=$1
##local 
    WPA_FILE=$2
	
    WPA_PID=$(ps ax | grep wpa_supplicant | grep " -i ${DEVNAME} " | 
sed -r -e 's/^\ +//g' | cut -d " " -f 1)
    
	if [ -n "${WPA_PID}" ]; then 
		log "wifi_restart_wpa" "WPA_PID: ${WPA_PID}"
		kill -9 ${WPA_PID}
	else
		log "wifi_restart_wpa" "no wpa_supplicant is running!!!"
    fi
	wpa_supplicant -B -i ${DEVNAME} -c ${WPA_FILE} -P${WPA_PIDFILE} 2>&1 >/dev/null
	WPA_PID=$(ps ax | grep wpa_supplicant | grep " -i ${DEVNAME}" | \
                     sed -r -e 's/^\ +//g' | cut -d " " -f 1 )
	WPA_PID_SAVED=$(cat ${WPA_PIDFILE})
    log "wifi_restart_wpa" "WPA_PID: ${WPA_PID} WPA_PID_SAVED: ${WPA_PID_SAVED}"
	  if [ -n "${WPA_PID}" ] &&  [ "${WPA_PID}" != "${WPA_PID_SAVED}" ]; then
		    eval "${DIALOG}   --msgbox 'Error restarting wpa_supplicant' \
			   ${INFO_HEIGHT} ${INFO_WIDTH}"
	   else
		    eval "${DIALOG}   --msgbox 'wpa_supplicant restarted successfully' \
			   ${INFO_HEIGHT} ${INFO_WIDTH}"
	  fi
    
}



##
## wifi_enable: show the list of configured networks, and enable the
## one the used has clicked on
##

##function 
wifi_enable(){

##local 
    DEVNAME=$1
    
	  wifi_network_list ${DEVNAME}
    
	  eval "${DIALOG} --menu 'Select configured network' \
		   ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 10 ${NETLIST}" \
		   2> ${TMPFILE}
	  
	  if [ $? -eq 0 ]; then
		    ## a network has been selected
		    NETNUM=$(cat ${TMPFILE})
		    WPA_STATUS=$(wpa_cli -i ${DEVNAME} enable ${NETNUM} | tail -1 )
		    if [ "${WPA_STATUS}" = "OK" ]; then
			      eval "${DIALOG}   --msgbox 'Network ${NETNUM} enabled' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}"
			      #config_ethernet ${DEVNAME}
			      return
		    else
			      eval "${DIALOG}   --msgbox 'Network ${NETNUM} NOT enabled' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}"
			      return
		    fi
	  else
		    eval "${DIALOG}   --msgbox 'No network enabled!!!' \
			   ${INFO_HEIGHT} ${INFO_WIDTH}"
		    return
	  fi
}


##function 
wifi_disable(){

##local 
    DEVNAME=$1
	  wifi_network_list ${DEVNAME}
	  eval "${DIALOG}  --menu 'Select configured network' \
          ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 10 ${NETLIST}" \
		   2> ${TMPFILE}
	  
	  if [ $? -eq 0 ]; then
		    ## a network has been selected
		    NETNUM=$(cat ${TMPFILE})
		    WPA_STATUS=$(wpa_cli -i ${DEVNAME} disable ${NETNUM} | tail -1 )
		    if [ "${WPA_STATUS}" = "OK" ]; then
			      eval "${DIALOG}   --msgbox 'Network ${NETNUM} disabled' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}"
			      return
		    else
			      eval "${DIALOG}   --msgbox 'Network ${NETNUM} NOT disabled' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}"
			      return
		    fi
	  else
		    eval "${DIALOG}   --msgbox 'No network disabled!!!' \
			   ${INFO_HEIGHT} ${INFO_WIDTH}"
		    return
	  fi
}



 
##function 
config_wifi(){

##local 
    DEVNAME=$1
	  
    while true; do
		CUR_NET=$(wpa_cli -i ${DEVNAME} status | grep "^ssid" | cut -d "=" -f 2)
		eval "${DIALOG}   --cancel-label 'Up' \
			   --menu 'Configuring ${DEVNAME}\nCurrent network: ${CUR_NET}\n(Current file: ${WPA_FILE})' \
			   ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 12 \
			   'Restart' 'Restart wpa_supplicant' \
			   'Enable' 'Enable a configured network' \
			   'Disable' 'Disable a configured network' \
			   'Add' 'Configure a new network' \
			   'Remove' 'Delete an existing network' \
			   'Show' 'Show current configuration file' \
			   'Edit' 'Edit current configuration file' \
			   'Save' 'Save configuration to file' "\
             2>${TMPFILE}
        
		    if [ $? = "1" ]; then
			      return
		    fi
		    ACTION=$(cat ${TMPFILE})
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
		    esac
	  done
    
}



##
## (Re)-Configure 
##

##function 
configure_wifi(){

##local 
    DEVNAME=$1

	## Automatically Check if the network device is a wifi -- this
	## should be robust...
	! iw ${DEVNAME} info 2>&1 >/dev/null
	IS_WIFI=$?
	log "configure_device" "Device ${DEVNAME} -- IS_WIFI: ${IS_WIFI} (automatic)"
	if [ "${IS_WIFI}" = "0" ] && \
		   [ -n "${WIFI_DEVICES}" ]; then 
		## WIFI_DEVICES is set, hence we check whether the current
		## device is in the list 
		IS_WIFI=$(echo " ${WIFI_DEVICES} " | grep -E -c "(\ ${DEVNAME}\ )")
		log "configure_device" "Device ${DEVNAME} -- IS_WIFI: ${IS_WIFI} (config file)"
	fi
	
	
	case ${IS_WIFI} in
		1)
			config_wifi ${DEVNAME}
			;;
		*)
			## Show a message here
			eval "${DIALOG} --msgbox '${DEVNAME} is not a WiFi device... ' \
            ${INFO_HEIGHT} ${INFO_WIDTH}" 
			;;
	esac
	
}


##function 
set_device_up(){

	##local 
	DEVNAME=$1

	chk_exit 0 ip link set ${DEVNAME} up 
	
}

##function 
set_device_down(){
	
	##local 
	DEVNAME=$1
	chk_exit 0 ip link set ${DEVNAME} down

}

##function 
show_device_menu(){
	
##local 
    DEVNAME=$1
    
    while true; do 	
        DEV_STATUS=$(ip -o link | cut -d " " -f 2,9 | grep -E "^${DEVNAME}: " | cut -d " " -f 2)
        log "show_device_menu" "DEVNAME: ${DEVNAME} DEV_STATUS: ${DEV_STATUS}"
		    eval "${DIALOG}   --cancel-label 'Up' --menu\
             'Device: ${DEVNAME}\nStatus: ${DEV_STATUS}' \
			       ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 8 \
			       'View' 'View current configuration' \
			       'Conf' 'Configure IP Address' \
                   'WiFi' 'Manage WiFi networking' \
                   'Start' 'Bring interface up' \
			       'Stop' 'Put interface down' \
			       'Restart' 'Restart interface'" 2> ${TMPFILE}
		    
		    if [ $? -eq 1 ]; then
			      return
		    fi
		    
		    DEV_ACTION=$(cat ${TMPFILE})
		    case ${DEV_ACTION} in
			      "View")
				        show_device_conf ${DEVNAME}
				        ;;
			      "Conf")
				        configure_ip_address ${DEVNAME}
				        ;;
			      "WiFi")
				        configure_wifi ${DEVNAME}
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

##function 
show_devs() {

  	DEVICES=$(ip link show | awk 'NR % 2 == 1' | cut -d ":" -f 2)
    
	  DEVICE_TAGS=""
    
	  for i in  $DEVICES; do
		    if [ "$i" != "lo" ]; then
			      DEVICE_TAGS="${DEVICE_TAGS} $i $i" 
		    fi
	  done
    
 	  eval "${DIALOG}   --cancel-label 'Up' \
			   --menu 'Select Interface to configure' ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 4 \
			   ${DEVICE_TAGS}" 2> ${TMPFILE}
	  return $?
}


##function 
dev_config_menu(){
    
	  while  true; do 
		    show_devs 
		    if [ $? -eq 1 ]; then
			      return
		    fi
		    DEVNAME=$(cat ${TMPFILE})
		    show_device_menu ${DEVNAME}			
	  done
}

##function 
show_info(){

	cat <<EOF > ${TMPFILE}

                      -+- setnet.sh ${VERSION} -+-

setnet.sh is a simple state-less tool to manage and configure network
interfaces. It is a shell wrapper around the functionalities of
standard command-line tools, including "ip", "dhclient", "wpa_cli",
etc., and can be used to configure network connections via
Ethernet/Wi-Fi interfaces.

Both Static and DHCP-based IP configuration are supported. 

At the moment, only WPA-PSK and open (no key) Wi-Fi connections are
available. 

For more information, please visit the webpage of the project:

    http://kalos.mine.nu/setnet/

Please report bugs at:

    https://git.devuan.org/KatolaZ/setnet

EOF
	eval "${DIALOG}   --cr-wrap --textbox ${TMPFILE} ${WINDOW_HEIGHT} ${WINDOW_WIDTH}"
	return
}

##function 
show_copyright(){

	cat <<EOF > ${TMPFILE}

                          -+- setnet.sh ${VERSION} -+-

--------------------------------------------------------------------

  Copyleft (C) Vincenzo "KatolaZ" Nicosia <katolaz@freaknet.org> 
               2016, 2017

--------------------------------------------------------------------


EOF
	eval "${DIALOG}   --cr-wrap --textbox ${TMPFILE} ${WINDOW_HEIGHT} ${WINDOW_WIDTH}"
	return
}


##function 
show_license(){

	cat <<EOF > ${TMPFILE}

                       -+- setnet.sh ${VERSION} -+-

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

--------------------------------------------------------------------

   Copyleft (C) Vincenzo "KatolaZ" Nicosia <katolaz@freaknet.org> 
                2016, 2017

--------------------------------------------------------------------

EOF
	eval "${DIALOG}   --cr-wrap --textbox ${TMPFILE} ${WINDOW_HEIGHT} ${WINDOW_WIDTH}"
	return
}



##function 
about_menu(){

	  while  true; do 
		    eval "${DIALOG}  --cancel-label 'Up' --menu 'setnet ${VERSION} -- About' \
			   ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 6 \
			   'Info' 'General information' \
			   'Copyleft' 'Copyleft information' \
			   'License' 'How to distribute this program' " \
			   2> ${TMPFILE}
		    if [ $? -eq 1 ];then
			      return;
		    fi
		    
		    ACTION=$(cat ${TMPFILE})
		    case ${ACTION} in
			      "Info")
				        show_info
				        ;;
			      "Copyleft")
				        show_copyright
				        ;;
			      "License")
				        show_license
				        ;;
		    esac
	  done
}

##function
notfound(){

    CMDNAME=$1

    
    eval "${DIALOG}  --msgbox 'Sorry! Commmand ${CMDNAME} not found!'" \
         ${INFO_HEIGHT} ${INFO_WIDTH}
    
}


##function
netdiag_DNS(){

    DUMPFILE=$1
    
    if [ -n "${DUMPFILE}" ]; then
        ## Dump to file
        printf "\n=====\n== DNS Configuration (/etc/resolv.conf)\n=====\n\n" >> ${DUMPFILE}
        cat /etc/resolv.conf >> ${DUMPFILE}
        echo "==================================" >> ${DUMPFILE}
        return 0
    fi

    ## Dump to dialog
    NAMESERVERS=$(grep '^nameserver' /etc/resolv.conf)
    MSG_STR="Configured name servers in /etc/resolv.conf ==\n\n${NAMESERVERS}"

    eval "${DIALOG}  --title 'DNS servers' --msgbox '${MSG_STR}' "\
         ${WINDOW_HEIGHT} ${WINDOW_WIDTH}
    
}

##function
netdiag_resolver(){

    DUMPFILE=$1
    
    if [ -n "${DUMPFILE}" ]; then
        ## Dump to file
        printf "\n=====\n== Resolver Configuration (/etc/nsswitch.conf)\n=====\n\n" >> ${DUMPFILE}
        grep -v '^#' /etc/nsswitch.conf >> ${DUMPFILE}
        echo "==================================" >> ${DUMPFILE}
        return 0
    fi

    ## Dump to dialog
    RESOLVER=$(grep -v '^#' /etc/nsswitch.conf)

    eval "${DIALOG}  --title 'Resolver configuration (/etc/nsswitch.conf)' \
          --msgbox '${RESOLVER}' "\
         ${WINDOW_HEIGHT} ${WINDOW_WIDTH}
    
}


##function
netdiag_routes(){

    DUMPFILE=$1

    HAS_NETSTAT=$(echo "${HAS_OPTS}" | grep -c "\ netstat\ ")
    if [ ${HAS_NETSTAT} -ne 1 ]; then
        notfound "netstat"
        return
    fi

    if [ -n "${DUMPFILE}" ]; then
        ## Dump to file
        printf "\n=====\n== Routing table\n=====\n\n" >> ${DUMPFILE}
        netstat -rn >> ${DUMPFILE}
        echo "==================================" >> ${DUMPFILE}
        return 0
    fi
    ## Dump to dialog
    ROUTES=$(netstat -rn > ${TMPFILE} )
    
    eval "${DIALOG}  --no-collapse --title 'Routing table (netstat -rn) [arrows to scroll]'" \
         "--tab-correct --tab-len 4 --textbox ${TMPFILE} "\
         ${LARGE_HEIGHT} ${LARGE_WIDTH}
}

##function
netdiag_ARP(){

    DUMPFILE=$1
    log "netdiag_ARP" "DUMPFILE: '${DUMPFILE}'"
    if [ -n "${DUMPFILE}" ]; then
        ## Dump to file
        printf "\n=====\n== ARP table\n=====\n\n" >> "${DUMPFILE}"
        cat /proc/net/arp >> "${DUMPFILE}"
        echo "==================================" >> ${DUMPFILE}
        return 0
    fi

    # Dump to dialog
    ARP=$(cat /proc/net/arp >${TMPFILE})

    eval "${DIALOG}  --no-collapse --title 'ARP table (/proc/net/arp) [arrows to scroll]'" \
         "--tab-correct --tab-len 4 --textbox ${TMPFILE} "\
         ${LARGE_HEIGHT} ${LARGE_WIDTH}
}

##function
netdiag_connections(){

    DUMPFILE=$1

   
    HAS_NETSTAT=$(echo "${HAS_OPTS}" | grep -c "\ netstat\ ")
    if [ ${HAS_NETSTAT} -ne 1 ]; then
        notfound "netstat"
        return
    fi

    if [ -n "${DUMPFILE}" ]; then
        ## Dump to file
        printf "\n=====\n== Active Network Connections\n=====\n\n" >> ${DUMPFILE}
        netstat -tnp | sed -r -e 's/$/\n/g' >> ${DUMPFILE}
        echo "==================================" >> ${DUMPFILE}
        return 0
    fi

    ## Dump to dialog
    SERV=$(netstat -tnp | sed -r -e 's/$/\n/g' > ${TMPFILE})
    
    eval "${DIALOG}  --no-collapse "\
         " --title 'Active network connections (netstat -tnp) [arrows to scroll]'" \
         "--tab-correct --tab-len 4 --textbox ${TMPFILE} "\
         ${LARGE_HEIGHT} ${LARGE_WIDTH}
}


##function
netdiag_services(){

    DUMPFILE=$1

    HAS_NETSTAT=$(echo "${HAS_OPTS}" | grep -c "\ netstat\ ")
    if [ ${HAS_NETSTAT} -ne 1 ]; then
        notfound "netstat"
        return
    fi

    if [ -n "${DUMPFILE}" ]; then
        ## Dump to file
        printf "\n=====\n== Active network services\n=====\n\n" >> ${DUMPFILE}
        netstat -ltnp | sed -r -e 's/$/\n/g' >> ${DUMPFILE}
        echo "==================================" >> ${DUMPFILE}
        return 0
    fi
    

    SERV=$(netstat -ltnp | sed -r -e 's/$/\n/g' > ${TMPFILE})
    
    eval "${DIALOG}  --no-collapse "\
         " --title 'Active network services (netstat -ltnp) [arrows to scroll]'" \
         "--tab-correct --tab-len 4 --textbox ${TMPFILE} "\
         ${LARGE_HEIGHT} ${LARGE_WIDTH}
}


##function
netdiag_ping(){
    
    HAS_PING=$(echo "${HAS_OPTS}" | grep -E -c "\ ping\ ")
    if [ ${HAS_PING} -ne 1 ]; then
        notfound "ping"
        return
    fi
    eval "${DIALOG} --insecure --inputbox 'Host or IP to ping:' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}"  2> ${TMPFILE}

    if [ $? -ne 0 ]; then
       	eval "${DIALOG}   --msgbox 'Ping Aborted' \
					   ${INFO_HEIGHT} ${INFO_WIDTH}"
        return
    else
        PINGIP=$(cat ${TMPFILE})
        ping -c 5 ${PINGIP} 2>&1  |\
			eval "${DIALOG}  --title 'Ping ${PINGIP}' \
                 --programbox  ${LARGE_HEIGHT} ${LARGE_WIDTH}" 2>${TMPFILE}
        if [ $! -ne 0 ];then
		 	log "netdiag_ping" "ping aborted"
		fi
    fi

}

##function
netdiag_traceroute(){
    
    HAS_TRACERT=$(echo "${HAS_OPTS}" | grep -c "\ traceroute\ ")
    if [ ${HAS_TRACERT} -ne 1 ]; then
        notfound "traceroute"
        return
    fi
    eval "${DIALOG} --insecure --inputbox 'Host or IP to trace:' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}"  2> ${TMPFILE}

    if [ $? -ne 0 ]; then
       	eval "${DIALOG}   --msgbox 'Traceroute Aborted' \
					   ${INFO_HEIGHT} ${INFO_WIDTH}"
        return
    else
        TRACEIP=$(cat ${TMPFILE})
        traceroute ${TRACEIP} 2>&1 | \
			eval "${DIALOG}  --title 'Traceroute ${TRACEIP}' \
                 --programbox  ${LARGE_HEIGHT} ${LARGE_WIDTH}" 2>${TMPFILE}
        if [ $! -ne 0 ];then
		 	log "netdiag_traceroute" "traceroute aborted"
		fi
    fi
}


##function
netdiag_lookup(){

    HAS_HOST=$(echo "${HAS_OPTS}" | grep -c "\ host\ ")
    if [ ${HAS_HOST} -ne 1 ]; then
        notfound "host"
        return
    fi

    eval "${DIALOG} --insecure --inputbox 'Hostname or IP to lookup:' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}"  2> ${TMPFILE}
    
    if [ $? -ne 0 ]; then
       	eval "${DIALOG}   --msgbox 'DNS lookup aborted' \
					   ${INFO_HEIGHT} ${INFO_WIDTH}"
        return
    else
        QUERYIP=$(cat ${TMPFILE})
        host ${QUERYIP} 2>&1 |\
			eval "${DIALOG}  --title 'host ${QUERYIP}' \
                 --programbox  ${LARGE_HEIGHT} ${LARGE_WIDTH}" 2>${TMPFILE}
        if [ $! -ne 0 ];then
		 	log "netdiag_ping" "host lookup aborted"
		fi

    fi
}

##function
netdiag_devices(){

    DUMPFILE=$1

    if [ -n "${DUMPFILE}" ]; then
        printf "\n=====\n== Network Devices\n=====\n\n" >> ${DUMPFILE}
        ip addr >> ${DUMPFILE}
        echo "==================================" >> ${DUMPFILE}
        return 0
    fi
}



##
## Main menu for network diagnostics
##

##function
netdiag_menu(){
    
	  while  true; do 
		    eval "${DIALOG}  --cancel-label 'Up' --menu 'Network diagnostics' \
			   ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 10 \
			   'ARP' 'Show ARP table'  \
         'Connections' 'List active network connections' \
			   'DNS' 'List DNS servers' \
         'Lookup' 'DNS Lookup' \
         'Ping' 'Ping a host'  \
         'Resolver' 'Show resolver configuration' \
			   'Routes' 'Show routing table' \
         'Services' 'List active network daemons'  \
         'Traceroute' 'Show the route to a host' " \
			       2> ${TMPFILE}
		    if [ $? -eq 1 ];then
			      return;
		    fi
		    
		    ACTION=$(cat ${TMPFILE})
		    case ${ACTION} in
			      "ARP")
				        netdiag_ARP
				        ;;
			      "Connections")
				        netdiag_connections
				        ;;
			      "DNS")
				        netdiag_DNS
				        ;;
            "Ping")
				        netdiag_ping
				        ;;
            "Lookup")
                netdiag_lookup
                ;;
			      "Resolver")
				        netdiag_resolver
                ;;
			      "Routes")
				        netdiag_routes
                ;;
			      "Services")
				        netdiag_services
				        ;;
			      "Traceroute")
				        netdiag_traceroute
				        ;;
		    esac
	  done
    
    
}

##function
dump_file(){
    
    CONF=$1

    log "dump_file" "CONF: ${CONF}"
    
    DUMPFILE="/tmp/network_dump.txt"
    
	  eval "${DIALOG}  --fselect ${DUMPFILE} ${WINDOW_HEIGHT} ${WINDOW_WIDTH}" \
			   2>${TMPFILE}
	  
	  if [ $? -eq 0 ]; then
		    SEL_FILE=$(cat ${TMPFILE})
		    while [ -d "${SEL_FILE}" ]; do
			      eval "${DIALOG}  --fselect ${SEL_FILE} ${WINDOW_HEIGHT} ${WINDOW_WIDTH}" \
					   2>${TMPFILE}
			      if [ $? -eq 0 ]; then
				        SEL_FILE=$(cat ${TMPFILE})
			      else
				        eval "${DIALOG}   --msgbox 'Dump aborted' \
						   ${INFO_HEIGHT} ${INFO_WIDTH}"
				        return
			      fi
		    done
		    
        ## The dump starts here....
			  DUMPFILE=${SEL_FILE}
			  truncate -s 0 ${DUMPFILE}
        echo "===== setnet ${VERSION}" >> ${DUMPFILE}
        echo "===== Date: $(date)" >> ${DUMPFILE}
        echo "===== Network configuration dump: ${CONF} " >> ${DUMPFILE}
        for c in ${CONF}; do
            eval "netdiag_${c} \"${DUMPFILE}\""
        done
	  else
		    eval "${DIALOG}   --msgbox 'Dump aborted' \
				   ${INFO_HEIGHT} ${INFO_WIDTH}"
        return
	  fi
		eval "${DIALOG}   --msgbox 'Status dumped to ${DUMPFILE}' \
						   ${INFO_HEIGHT} ${INFO_WIDTH}"
}


##function
dump_pastebin(){
    
    unimplemented "pastebin"
}

##function 
dump_menu(){

    eval "${DIALOG}  --checklist 'Select conf to dump' \
             ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 10 \
             'ARP' 'ARP table' on \
             'devices' 'Device configuration' on \
             'DNS' 'DNS configuration' on \
             'resolver' 'System resolver configuration' on \
             'routes' 'Routing table' on \
             'connections' 'Active network connections' on \
             'services' 'Active network services' on " 2> ${TMPFILE}
    if [ $? -ne 0 ]; then
        return
    fi
    
    DUMP_CONF=$(cat ${TMPFILE})
    
    eval "${DIALOG}  --cancel-label 'Up' \
           --menu 'Dump configuration to:' \
           ${INFO_HEIGHT} ${INFO_WIDTH} 6 \
           'File' 'Dump to file' \
           'Pastebin' 'Dump to pastebin'" \
         2> ${TMPFILE}
    if [ $? -eq 1 ];then
			  return;
		fi
		
		ACTION=$(cat ${TMPFILE})
		case ${ACTION} in
			  "File")
            dump_file "${DUMP_CONF}"
				    ;;
			  "Pastebin")
            dump_pastebin "${DUMP_CONF}"
				    ;;
		esac
}


##function 
show_toplevel(){

    log "show_toplevel" "TMPFILE: ${TMPFILE}"
	  eval "${DIALOG}  --cancel-label 'Quit' --menu 'Main Menu' \
		   ${WINDOW_HEIGHT} ${WINDOW_WIDTH} 6 \
		   'Setup' 'Setup interfaces' \
       'Info' 'Network diagnostics' \
       'Dump' 'Dump current network status' \
       'Log' 'View setnet log' \
		   'About' 'License & Copyleft'" 2> ${TMPFILE}
    
	  return $?
}

##function 
show_help(){

##local 
SCRIPTNAME=$1
	echo "Usage: ${SCRIPTNAME} [OPTION]"
	echo "Options:"
	printf  "\t -c cfg_file\tLoad configuration from cfg_file.\n"
	printf  "\t -v\t\tPrint version number and exit.\n"
	printf  "\t -h\t\tShow this help.\n"
	
}

##function 
show_version(){

##local 
SCRIPTNAME=$1
	echo "${SCRIPTNAME} -- version ${VERSION}"
	echo "Copyleft (C) Vincenzo \"KatolaZ\" Nicosia (katolaz@freaknet.org) -- 2016, 2017"
	echo "This is free software. You can use and redistribute it under the "
	echo "terms of the GNU General Public Licence version 3 or (at your option)"
	echo "any later version."
	echo 
	echo "YOU USE THIS SOFTWARE AT YOUR OWN RISK."
	echo "There is ABSOLUTELY NO WARRANTY; not even for MERCHANTABILITY or"
	echo "FITNESS FOR A PARTICULAR PURPOSE."
}

##function 
show_disclaimer(){

	cat <<EOF > ${TMPFILE}

                -+- setnet.sh ${VERSION} -+-

      Copyleft (C) KatolaZ (katolaz@freaknet.org) 
                    2016, 2017

      -+- This is a beta release of setnet.sh -+-
   
                 THIS IS FREE SOFTWARE
        YOU CAN USE AND DISTRIBUTE IT UNDER THE 
        TERMS OF THE GNU GENERAL PUBLIC LICENSE
      
          USE THIS SOFTWARE  AT YOUR OWN RISK

     There is ABSOLUTELY NO WARRANTY; not even for 
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

        See "About" for more information about 
           your right and distribution terms
EOF

	eval "${DIALOG}   --cr-wrap --textbox ${TMPFILE} 23 60"
	return
}

##function
initialise(){


    TMPFILE=$( (tempfile) 2>/dev/null) || TMPFILE=/tmp/setnet_$$
    WPA_PIDFILE=$( (tempfile) 2>/dev/null) || WPA_PIDFILE=/tmp/setnet_wpapid_$$
    
	trap cleanup 0 HUP INT TRAP TERM QUIT

    if [ -z ${TRUNCATE_LOG} ] || \
           [ ${TRUNCATE_LOG} = "yes" ] || \
               [ ${TRUNCATE_LOG} = "YES" ]; then
	      truncate -s 0 ${LOGFILE}
    fi

	chmod 600 ${LOGFILE}
	
	log "initialise" "Starting afresh on $(date)"
	log "initialise" "Using TMPFILE: ${TMPFILE}"
	log "initialise" "Using LOGFILE: ${LOGFILE}"

	if [ -n ${DEBUG_MODE} ]; then 
		log "initialise" "Running in debug mode -- dumping dialog trace to ${TRACE_FILE}"
	fi
	
	EUID=$(id -ru)
	if [ "${EUID}" = "0" ] &&
		   [ -n "${SUDO_UID}" ] &&
		   [ "${EUID}" != "${SUDO_UID}" ]; then
		USING_SUDO="1"
	elif [ "${EUID}" = "0" ] &&
		   [ -n "${SUP_UID}" ] &&
		   [ "${EUID}" != "${SUP_UID}" ]; then
		USING_SUDO="1"
	else
		USING_SUDO="0"
	fi

	log "initialise" "EUID: ${EUID}"
	log "initialise" "SUDO_UID: ${SUDO_UID}"
	log "initialise" "SUP_UID: ${SUP_UID}"
	log "initialise" "USING_SUDO: ${USING_SUDO}"
}


##function
log_show(){
    
    eval "${DIALOG}  --cr-wrap --title 'setnet log file (${LOGFILE})'\
    --textbox ${LOGFILE} \
    ${WINDOW_HEIGHT} ${WINDOW_WIDTH}" 
    
}

##function 
main(){


	show_disclaimer
	
	SETNETRC=$(realpath ${SETNETRC})
	log "main" "Using config file \"${SETNETRC}\""
	WPA_FILE=$(realpath ${WPA_FILE})
	log "main" "Using WPA config file \"${WPA_FILE}\""
	LOFGILE=$(realpath ${LOGFILE})
	log "main" "Using log file \"${LOGFILE}\""
	
	while  true; do 
		  show_toplevel

		  if [ $? -eq 1 ]; then
			    cleanup
			    exit 1
		  fi
      log "main" "${TMPFILE}"
		  ACTION=$(cat ${TMPFILE})
      log "main" "ACTION: ${ACTION}"
		  case ${ACTION} in
			    "Setup")
				      dev_config_menu
				      ;;
          "Info")
              netdiag_menu
              ;;
          "Dump")
              dump_menu
              ;;
          "Log")
              log_show
              ;;
			    "About")
				      about_menu
				      ;;
		  esac
	done
  
}


##
## The script starts here
##


##
## Get command-line arguments
## 

SETNETRC=""

while getopts ":c:d:hv" opt; do
	  
	  case $opt in
		    c)
			    #echo "Got option -c ${OPTARG}"
			    SETNETRC=$(realpath ${OPTARG})
			    #echo "SETNETRC: ${SETNETRC}"
			    ;;
		    h)
			    show_help $(basename $0)
			    exit 1
			    ;;
		    v)
			    show_version $(basename $0)
			    exit 1
			    ;;
			d)
				TRACE_FILE=$(realpath ${OPTARG})
				set_debug ${TRACE_FILE}
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


##
## Load the configuration file
##

load_setnetrc ${SETNETRC}

##
## Init stuff
##

initialise 


##
## Check dependencies. If we are missing someting essential, then exit.
##

check_deps

##
## This is the main loop
##

main 

