#!/bin/sh

. /lib/functions.sh
. /usr/share/libubox/jshn.sh



######################
#                    #
#  Collect OWM-Data  #
#                    #
######################


#Divide by 65536.0 and round to 2 dec to get 1.00
#int2float() {
#	local val=$1
#	reell="$((val/65536))"
#	ratio="$((val*100/65536))"
#	rest="$((reell*100))"
#	ratio="$((ratio-rest))"
#	printf "%d.%02d" $reell $ratio
#}

olsr2_links() {
	json_select $2
	json_get_var localIP link_bindto
	json_get_var remoteIP neighbor_originator
	remotehost="$(nslookup $remoteIP | grep name | sed -e 's/.*name = \(.*\)/\1/' -e 's/\..*//')"".olsr"
	#TODO
	json_get_var linkQuality domain_metric_out_raw
	#json_get_var linkQuality domain_metric_in_raw
	json_get_var ifName "if"
	json_select ..
	olsr2links="$olsr2links$localIP $remoteIP $remotehost $linkQuality $ifName;"
}

olsr4_links() {
	json_select $2
	json_get_var localIP localIP
	json_get_var remoteIP remoteIP
	remotehost="$(nslookup $remoteIP | grep name | sed -e 's/.*name = \(.*\)/\1/')"
	json_get_var linkQuality linkQuality
	json_get_var olsrInterface olsrInterface
	json_get_var ifName ifName
	json_select ..
	olsr4links="$olsr4links$localIP $remoteIP $remotehost $linkQuality $ifName;"
}

olsr6_links() {
	json_select $2
	json_get_var localIP localIP
	json_get_var remoteIP remoteIP
	remotehost="$(nslookup $remoteIP | grep name | sed -e 's/.*name = \(.*\)/\1/')"
	json_get_var linkQuality linkQuality
	json_get_var olsrInterface olsrInterface
	json_get_var ifName ifName
	json_select ..
	olsr6links="$olsr6links$localIP $remoteIP $remotehost $linkQuality $ifName;"
}

json_load "$(echo /nhdpinfo json link | nc ::1 2009 2>/dev/null)" 2>/dev/null
olsr2links=""
if json_is_a link array;then
	json_for_each_item olsr2_links link
fi
json_cleanup
json_load "$( echo /links | nc 127.0.0.1 9090 2>/dev/null)" 2>/dev/null
#json_get_var timeSinceStartup timeSinceStartup
olsr4links=""
if json_is_a links array;then
	json_for_each_item olsr4_links links
fi
json_cleanup
json_load "$( echo /links | nc ::1 9090 2>/dev/null)" 2>/dev/null
#json_get_var timeSinceStartup timeSinceStartup
olsr6links=""
if json_is_a links array;then
	json_for_each_item olsr6_links links
fi
json_cleanup


# collect board info
json_load "$(ubus call system board)"
json_get_var model model
json_get_var hostname hostname
json_get_var system system
json_select release
json_get_var revision revision
json_get_var distribution distribution
json_get_var version version
json_select ..
json_load "$(ubus call system info)"
json_get_var uptime uptime
json_get_values loads load

# if file freifunk_release is available, override version and revision
if [ -f /etc/freifunk_release ]; then
	source /etc/freifunk_release
	distribution="$FREIFUNK_DISTRIB_ID"
	version="$FREIFUNK_RELEASE"
	revision="$FREIFUNK_REVISION"
fi


#Divide by 65536.0 and round to 2 dec to get 1.00
#set -- $loads
#load1=$(int2float $1)
#load5=$(int2float $2)
#load15=$(int2float $3)

# Get Sysload
sysload=$(uptime | sed -e 's/average: /;/g' | cut -d';' -f2 | tr ',' ' ')
load1=$(echo "$sysload" | cut -d' ' -f1)
load5=$(echo "$sysload" | cut -d' ' -f3)
load15=$(echo "$sysload" | cut -d' ' -f5)

# nodes location
uci_load system
longitude="$(uci_get system @system[-1] longitude "13.4")"
latitude="$(uci_get system @system[-1] latitude "52.5")"

# contact information
uci_load freifunk
name="$(uci_get freifunk contact name)"
nick="$(uci_get freifunk contact nickname)"
mail="$(uci_get freifunk contact mail)"
phone="$(uci_get freifunk contact phone)"
homepage="$(uci_get freifunk contact homepage)" # whitespace-separated, with single quotes, if string contains whitspace
note="$(uci_get freifunk contact note)"

# community info
ssid="$(uci_get freifunk community ssid)"
mesh_network="$(uci_get freifunk community mesh_network)"
uci_owm_apis="$(uci_get freifunk community owm_api)"
com_name="$(uci_get freifunk community name)"
com_homepage="$(uci_get freifunk community homepage)"
com_longitude="$(uci_get freifunk community longitude)"
com_latitude="$(uci_get freifunk community latitude)"
com_ssid_scheme=$(uci_get freifunk community ssid_scheme)
com_splash_network=$(uci_get freifunk community splash_network)
com_splash_prefix=$(uci_get freifunk community splash_prefix)



###########################
#                         #
#  Construct JSON-string  #
#                         #
###########################

json_init
json_add_object freifunk

	json_add_object contact
		if [ -n "$name" ]; then json_add_string name "$name"; fi
		if [ -n "$mail" ]; then json_add_string mail "$mail"; fi
		if [ -n "$nick" ]; then json_add_string nickname "$nick"; fi
		if [ -n "$phone" ]; then json_add_string phone "$phone"; fi
		if [ -n "$homepage" ]; then json_add_string homepage "$homepage"; fi #ToDo: list of homepages
		if [ -n "$note" ]; then json_add_string note "$note"; fi
	json_close_object

	json_add_object community
		json_add_string ssid "$ssid"
		json_add_string mesh_network "$mesh_network"
			json_add_array owm_api
			for uci_owm_api in "$uci_owm_apis";do
				json_add_string "" "$uci_owm_api"
			done
			json_close_array
		json_add_string name "$com_name"
		json_add_string homepage "$com_homepage"
		json_add_string longitude "$com_longitude"
		json_add_string latitude "$com_latitude"
		json_add_string ssid_scheme "$com_ssid_scheme"
		json_add_string splash_network "$com_splash_network"
		json_add_string splash_prefix "$com_splash_prefix"
	json_close_object
json_close_object

# script infos
json_add_string type "node"
json_add_string script "owm.sh"
json_add_string api_rev "1.0"

json_add_object system
	#FIXME
	json_add_array sysinfo
		json_add_string "" "system is deprecated"
		json_add_string "" "$model"
	json_close_array
	#FIXME
	json_add_array uptime
		json_add_int "" $uptime
	json_close_array
	json_add_object loadavg
		#BUG in double-function: mostly it add unwnated digits at the end. :(
		#json_add_double "1m" $load1
		#json_add_double "5m" $load5
		#json_add_double "15m" $load15
		json_add_string "1m" $load1
		json_add_string "5m" $load5
		json_add_string "15m" $load15
	json_close_object
json_close_object

# OLSR-Info
#TODO
json_add_object olsr
json_close_object

json_add_array links
	IFSORIG="$IFS"
	IFS=';'
	for i in ${olsr2links} ; do
		IFS="$IFSORIG"
		set -- $i
		json_add_object
		json_add_string sourceAddr6 "$1"
		json_add_string destAddr6 "$2"
		json_add_string id "$3"
		#json_add_string quality "$4"
		json_add_double quality "$4"
		json_close_object
		IFS=';'
	done
	for i in ${olsr4links} ; do
		IFS="$IFSORIG"
		set -- $i
		json_add_object
		json_add_string sourceAddr4 "$1"
		json_add_string destAddr4 "$2"
		json_add_string id "$3"
		#json_add_string quality "$4"
		json_add_double quality "$4"
		json_close_object
		IFS=';'
	done
	for i in ${olsr6links} ; do
		IFS="$IFSORIG"
		set -- $i
		json_add_object
		json_add_string sourceAddr6 "$1"
		json_add_string destAddr6 "$2"
		json_add_string id "$3"
		#json_add_string quality "$4"
		json_add_double quality "$4"
		json_close_object
		IFS=';'
	done
	IFS="$IFSORIG"
json_close_array

# General node info
# Bug in add_double function. Mostly it adds unwanted digits.
json_add_string latitude "$latitude"
json_add_string longitude "$longitude"
json_add_string hostname "$hostname"
json_add_string hardware "$system"
json_add_int updateInterval 3600

json_add_object firmware
	json_add_string name "$distribution $version"
	json_add_string revision "$revision"
json_close_object

json_close_object

json_dump

