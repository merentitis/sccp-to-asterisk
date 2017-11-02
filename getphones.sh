#!/bin/bash
### Configuration ###
scriptpath=/usr/local/ccmscripts
tftppath=/tftpboot
EXPECT=/usr/bin/expect
#Enter secondary lines here, "^" is important before each line!
seclines=("^300" "^301" "^302" "^303" "^290")
cucm=ccm.domain.com
username=administrator
password=pass
####################

#backup some files:
for f in $scriptpath/phones.* ;
do
        if [[ $f == *"backup"* ]]; then
        continue;
        fi
        cp -r $f $f.backup ;done
#delete old ones, except backups:
ls $scriptpath/phones.* | grep -v backup | xargs rm

#get SEP list from iCisco Call Manager via expect script
$EXPECT << EOF
set timeout 10
spawn /usr/bin/ssh -oStrictHostKeyChecking=no $username@$cucm
expect sleep 3
expect "password*" { send "$password\r" }
log_file  $scriptpath/phones.log;# Logging it into the file 'phones.log'
expect "admin*" { send "run sql select d.name, d.description, n.dnorpattern as DN from device as d, numplan as n, devicenumplanmap as dnpm where dnpm.fkdevice = d.pkid and dnpm.fknumplan = n.pkid and d.tkclass = 1\r" }
expect sleep 5
expect "admin:" { send "quit\r" }
interact
EOF

#fix phones file (place secondary lines at the end of the file and sort columns):
awk '{ t = $1; $1 = $3; $3 = t; print; }' $scriptpath/phones.log >  $scriptpath/phones.in
pat1=$(echo ${seclines[@]}|tr " " "|")
<  $scriptpath/phones.in tee >(grep -E "$pat1" | sort > $scriptpath/phones.last) | grep -v -E "$pat1" | sort > $scriptpath/phones.first
cat $scriptpath/phones.first $scriptpath/phones.last > $scriptpath/phones.sorted 

#First Backup, then create .cnf.xml files and insert default config
#.cnf.xml file in tftp directory are optional for SRST beacuse asterisk (fallback) ip is declared in the CUCM
for f in $tftppath/SEP*.cnf.xml ; do cp -r $f $f.backup ;done
rm -rf $tftppath/SEP*.cnf.xml
while read -r line ; do
#       touch $tftppath/$line.cnf.xml
        cat $tftppath/SEP.MAC.default >> $tftppath/$line.cnf.xml
        #echo -e $line
done <<<"$(cat $scriptpath/phones.log | grep SEP | grep -v Auto | awk '{print $1}' )"

#First Backup, then create sccp_hardware.conf included in sccp.conf
cp -r /etc/asterisk/sccp_hardware.conf /etc/asterisk/sccp_hardware.conf.backup
rm -rf /etc/asterisk/sccp_hardware.conf
while read -r line ; do
        touch /etc/asterisk/sccp_hardware.conf
        SEPX="$(echo $line | awk '{print $3}' )"
        extX="$(echo $line | awk '{print $1}' )"
        pat2=$(echo ${seclines[@]}|tr " " "|" | tr -d ^)
        if [[ "$extX" != +($pat2) ]]; then
                advextX="$(echo $extX,default )"
        else
                advextX=$extX
        fi
        cat <<EOT >> /etc/asterisk/sccp_hardware.conf

[${SEPX}]
description = SRST-${extX}
addon = 7914
devicetype = 7960
park = off
button = line, ${advextX}                              ; Tweaked to fix lines priority and default lines
;button = line, ${extX}                                 ; Assign Line 98011 to Device and use this as default line
;button = line, 300                                      ; Assign Line 98012 to Device
;button = empty                                         ; Assign an Empty Button
;button = speeddial,Helpdesk, 98112, 98112@hints        ; Add SpeedDial to Helpdesk
;button = speeddial,Phone 2 Line 1, 98021, 98021@hints  ; Add SpeedDial to Phone Number Two Line 1 (button labels allow special characters like '?^?<C2><A9>')
cfwdall = off
type = device
keepalive = 60
;tzoffset = +2
transfer = on
park = on
cfwdall = off
cfwdbusy = off
cfwdnoanswer = off
directed_pickup = on
directed_pickup_context = default
directed_pickup_modeanswer = on
deny=0.0.0.0/0.0.0.0
permit=195.251.29.0/255.255.255.0
dndFeature = on
dnd = off
directrtp=off
earlyrtp = progress
private = on
mwilamp = on
mwioncall = off
setvar=testvar=value
cfwdall = on
EOT

done <<<"$(cat $scriptpath/phones.sorted | grep SEP | grep -v Auto )"
