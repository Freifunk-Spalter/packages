#!/bin/sh
. /lib/functions.sh

# We do assume, that both radios (if there is more than one) share the same
# SSID. Handling different SSIDS is too complicated.

# leave the SSID as is, if there is still some connection to the net.
[ "$GLOBAL" = "ONLINE" ] && exit

# check, if we really went offline (i.e. WAN went down, but internet
# via mesh still available)
ERROR=0
ping -c1 8.8.8.8 || ERROR=$(($ERROR + 1))
ping -c1 1.1.1.1 || ERROR=$(($ERROR + 1))
ping -c1 9.9.9.9 || ERROR=$(($ERROR + 1))

[ $ERROR -lt 3 ] && exit


# get the names of every interface named *dhcp* and fetch its normal ssid. Thus we get
# 2.4 and/or 5 GHz both
IFACES=$(uci show wireless | grep -e "dhcp.*\.ssid" | cut -d'=' -f1 )
ONLINE_SSIDS=""
for IFACE in $IFACES; do
    SSID=$(uci_get "$IFACE")
    ONLINE_SSIDS="$SSID $ONLINE_SSIDS"
done

NODENAME=$(uci_get system @system[-1] hostname | cut -b -24 ) # cut nodename to not exceed 32 bytes
OFFLINE_SSID="offline_""$NODENAME"
LOGMSG="Didn't reach the internet. Change SSID to offline..."

# loop over hostapd configs and try to switch any matching ID.
for HOSTAPD in $(ls /var/run/hostapd-phy*); do
    for ONLINE_SSID in $ONLINE_SSIDS; do
        logger -s -t "ssid-changer" -p 5 "$LOGMSG"
        sed -i "s~^ssid=$ONLINE_SSID~ssid=$OFFLINE_SSID~" $HOSTAPD
    done
done

# send hup to hostapd to reload ssid
killall -HUP hostapd
