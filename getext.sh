#!/bin/bash

### Configuration ###
scriptpath=/usr/local/ccmscripts
EXPECT=/usr/bin/expect
#Set lines you don't want to include in SRST
exclusions=("447" "448")
cucm=ccm.domain.com
username=administrator
password=pass
#####################

rm -rf $scriptpath/extensions.log

#get extensions list from Cisco Call Manager via expect script
$EXPECT << EOF
set timeout 10
spawn /usr/bin/ssh -oStrictHostKeyChecking=no $username@$cucm
expect "password*" { send "$password\r" }
log_file $scriptpath/extensions.log;# Logging it into the file 'extensions.log'
expect "admin*" { send "run sql select numplan.DnOrPattern as extension, DeviceNumPlanMap.E164Mask as mask, numplan.alertingname as alerting_name, devicenumplanmap.display from numplan, devicenumplanmap, device where DeviceNumPlanMap.fknumplan = numplan.pkid and DeviceNumPlanMap.fkdevice = device.pkid and numplan.tkPatternUsage = 2 order by numplan.DnOrPattern\r" }
expect sleep 5
expect "admin:" { send "quit\r" }
interact
EOF


#First Backup, then create sccp_extensions.conf included in sccp.conf
cp -r  /etc/asterisk/sccp_extensions.conf /etc/asterisk/sccp_extensions.conf.backup
rm -rf  /etc/asterisk/sccp_extensions.conf
pat=$(echo ${exclusions[@]}|tr " " "|")
#check exclusions
while read -r line ; do
        if ! [[ "$(echo "${line}" | awk '{print $1}' )" =~ ($pat) ]]; then
        extX="$(echo "${line}" | awk '{print $1}' )"
        cid_numX="$(echo "${line}" | awk '{print $1}' )"
        #cid_numX="$(echo "${line}" | awk '{print $2}' )"
        cid_nameX="$(echo "${line}" | awk '{print $3}' )"
        else
                printf "\nexcluding extension...\n"
                echo ${line}
        fi
        cat <<EOT >> /etc/asterisk/sccp_extensions.conf

[${extX}]
id = 1${extX}
type = line
pin = 1234
label = ${extX}
description = ${extX}-srst
cid_name = ${cid_nameX}
cid_num = ${cid_numX}
accountcode=
callgroup=1,3-4
pickupgroup=1,3-5
;amaflags =
context = srst
incominglimit = 2
transfer = on
vmnum = 600
meetme = on
meetmeopts = qxd
meetmenum = 700
trnsfvm = 1000
secondary_dialtone_digits = 9
secondary_dialtone_tone = 0x22
musicclass=default
language=en
echocancel = on
silencesuppression = off
setvar=testvar2=my value
dnd = reject
parkinglot = myparkspace
EOT

done <<<"$(cat $scriptpath/extensions.log | grep '^[0-9]'  | uniq | awk '!seen[$1]++' | sort )"
