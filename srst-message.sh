#!/bin/bash

# You may run this once a minute as a cron job and let it notify your phones' screen if you are on SRST

# check if there are registered sccp extensions and change the status message to all of them:
function f (){
/usr/sbin/asterisk -rx 'sccp show devices' | grep OK | grep -o 'SEP............' | wc -l
}
result=$(f) 
if (($result > 1)) ; then
        echo "PROBLEM - CCM down!"
        /usr/sbin/asterisk -rx 'sccp system message "*Asterisk Fallback*"'
fi
