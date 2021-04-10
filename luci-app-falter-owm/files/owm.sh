#!/bin/sh

. /lib/functions.sh
. /usr/share/libubox/jshn.sh

#Divide by 65536.0 and round to 2 dec to get 1.00
int2float() {
	local val=$1
	reell="$((val/65536))"
	ratio="$((val*100/65536))"
	rest="$((reell*100))"
	ratio="$((ratio-rest))"
	printf "%d.%02d" $reell $ratio
}
#json_load "$(echo '/netjsoninfo filter graph ipv6_0' | nc ::1 2009)"

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
#Divide by 65536.0 and round to 2 dec to get 1.00
set -- $loads
load1=$(int2float $1)
load5=$(int2float $2)
load15=$(int2float $3)

uci_load system
longitude="$(uci_get system @system[-1] longitude "13.4")"
latitude="$(uci_get system @system[-1] latitude "52.5")"
uci_load freifunk
mail="$(uci_get freifunk contact mail)"
nick="$(uci_get freifunk contact nick)"
ssid="$(uci_get freifunk community ssid)"
mesh_network="$(uci_get freifunk community mesh_network)"
uci_owm_apis="$(uci_get freifunk community owm_api)"
name="$(uci_get freifunk community name)"
homepage="$(uci_get freifunk community homepage)"
com_longitude="$(uci_get freifunk community longitude)"
com_latitude="$(uci_get freifunk community latitude)"
json_init
json_add_object freifunk
json_add_object contact
json_add_string mail "$mail"
json_add_string nickname "$nickname"
json_close_object
json_add_object community
json_add_string ssid "$ssid"
json_add_string mesh_network "$mesh_network"
json_add_array owm_api
for uci_owm_api in "$uci_owm_apis";do
	json_add_string "" "$uci_owm_api"
done
json_close_array
json_add_string name "$name"
json_add_string homepage "$homepage"
json_add_string longitude "$com_longitude"
json_add_string latitude "$com_latitude"
json_close_object
json_close_object
json_add_string type "node"
json_add_string script "owm.sh"
json_add_string api_rev "1.0"
json_add_object system
#FIME
json_add_array sysinfo
json_add_string "" "system is deprecated"
json_add_string "" "$model"
json_close_array
#FIME
json_add_array uptime
json_add_int "" $uptime
json_close_array
json_add_array loadavg
#BUG
#json_add_double "" $load1
#json_add_double "" $load5
#json_add_double "" $load15
json_add_string "" $load1
json_add_string "" $load5
json_add_string "" $load15
json_close_array
json_close_object
#TODO
json_add_object olsr
json_close_object
#TODO
json_add_object links
json_close_object
json_add_string longitude "$longitude"
json_add_string hostname "$hostname"
json_add_string hardware "$system"
json_add_string latitude "$latitude"
json_add_int updateInterval 3600
json_add_object firmware
json_add_string name "$distribution $version"
json_add_string revision "$revision"
json_close_object
json_close_object
json_dump
