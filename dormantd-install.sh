#!/bin/bash
#
# dormantd service installer (c) 2023 MiCHaEL (michael.npsp@gmail.com)
#
# Monitorize data transmited over a network interface and suspend the 
# computer if the current rx+ts bytes is less than a configured MINIMUM
# This code was released under GPL3 licencse: 
#   https://www.gnu.org/licenses/gpl-3.0.html
#
# usage:
#   dormantd-install.sh      -- install dormantd package
#   dormant-install.sh  path -- install in the specified path, for debug purposes
#
# installed files:
#   /etc/dormantd.conf  -- dormant config file
#   /usr/bin/dormantd   -- dormantd daemon
#   /etc/systemd/system/dormantd.service -- systemd service config file
#

DESTDIR=$1

[ "$(id -u)" -eq 0 ] && root=1

[[ -d /run/systemd/system ]] || { echo "Error: systemd is not running, installation aborted."; exit 1; }

[[ -v root ]] || [[ -n $DESTDIR ]] || { echo "You must be root to install this program."; exit 1; }

#######################################################################################
# helper functions and variables
#######################################################################################


# set destination file variable
function set_destfile()
{
    local destpath=$DESTDIR/$1
    mkdir -p $destpath
    destfile=$destpath/$2
}

# change file owner to root
function set_destfile_owner()
{
    [ -v root ] && chown root:root $destfile
    [ -n "$1" ] && chmod +x $destfile
}

#######################################################################################


echo "Installing dormantd service."

#######################################################################################
# /etc/dormantd.conf
#######################################################################################

set_destfile etc dormantd.conf

cat <<"END_OF_FILE" > $destfile
# /etc/dormantd.conf

# Network interface to monitorize
INTERFACE='enp1s0'

# Interval in seconds between tests
INTERVAL=300

# Minimum bytes transmited+received in the specific interval to not suspend the system.
MINIMUM=$((128*1024))
END_OF_FILE

set_destfile_owner

#######################################################################################
# /etc/systemd/system/dormantd.service
######################################################################################

set_destfile etc/systemd/system dormantd.service

cat <<"END_OF_FILE" > $destfile
[Unit]
Description=Suspend server if no network traffic
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/dormantd
PIDFile=/tmp/dormantd.pid

[Install]
WantedBy=default.target
END_OF_FILE

set_destfile_owner

#######################################################################################
# /usr/bin/dormantd
#######################################################################################

set_destfile usr/bin dormantd

cat <<"END_OF_FILE" > $destfile
#!/bin/bash

# uninstall code

if [ "$1" == "uninstall" ]; then
    [ "$(id -u)" -eq 0 ] || { echo "You must be root to uninstall this program."; exit 1; }
    read -r -p "Are you sure you want to uninstall dormantd ? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "Uninstalling dormantd:"
        systemctl stop dormantd
        systemctl disable dormantd
        rm -v /etc/dormantd.conf
        rm -v /etc/systemd/system/dormantd.service
        rm -v /usr/bin/dormantd
        echo "Done."
    fi
    exit 0
fi

# Bash script to monitorize bytes transmited over a network interface and
# suspend the computer if the current rx+ts bytes is less than a MINIMUM

. /etc/dormantd.conf

echo "Interface: $INTERFACE, Interval: $INTERVAL seconds, Minimum Traffic: $MINIMUM bytes."

tx_file="/sys/class/net/$INTERFACE/statistics/tx_bytes"
rx_file="/sys/class/net/$INTERFACE/statistics/rx_bytes"

bytes=$(( $(<$tx_file)+$(<$rx_file) ))
while true
do
    sleep $INTERVAL
    pytes=$bytes
    bytes=$(( $(<$tx_file)+$(<$rx_file) ))
    diffb=$(($bytes-$pytes))
    if [[ $diffb -lt $MINIMUM ]]; then #no enough network traffic
        if [ $(ss | grep -i ssh | wc -l) = 0 ]; then #no ssh connections
            echo "Suspending system due to no network traffic !!!"
            systemctl suspend
        fi
    fi
    echo "Network traffic in last $INTERVAL seconds: $diffb bytes ( $((diffb/INTERVAL)) bytes/sec )."
done
END_OF_FILE

set_destfile_owner x

#######################################################################################

if [ -v root ]; then
    systemctl daemon-reload
    systemctl enable dormantd
    systemctl restart dormantd
    echo "/etc/dormantd.conf -> configuration file."
    echo "systemctl restart dormantd -> reload configuration."
    echo "journalctl -u dormantd -f -> display dormantd log."
    echo "dormantd uninstall -> uninstall this package."
fi

echo "Done."
