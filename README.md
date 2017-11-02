# sccp-to-asterisk

prerequisites:

-Cisco Call Manager 6.x (Atl least this is the version I have)

-Asterisk with chan-sccp installed: https://github.com/chan-sccp/chan-sccp/

-expect

-TFTP server - In case you need ONLY SRST, TFTP is not needed 

-You have to be familiar with asterisk contexts, I used a new context called "srst"

These scripts are used in order to migrate Cisco IP Phones registered with Cisco Call Manager to work with asterisk while your Cisco Call Manager is down.

The configuration migrated from cucm includes the creation of the device configuration files (*.cnf.xml) and the creation of the 2 configuration files needed for chan-sccp: sccp_extensions.conf, sccp_hardware.conf .

You should have these included in your sccp.conf file:

#include sccp_hardware.conf

#include sccp_extensions.conf

It is assumed that you already have setup chan-sccp module and tested the sccp enviroment in Asterisk with a Cisco phone.

The files may need some tweaking according to your needs.

Asterisk ip should be configured as SRST in Call Manager.

After each change you have to restart the sccp module. I use a cron job once a day:

50 0 * * * /usr/local/ccmscripts/getphones.sh && /usr/local/ccmscripts/getext.sh && sleep 20 && /usr/sbin/asterisk -rx 'sccp reload' >/dev/null 2>&1
