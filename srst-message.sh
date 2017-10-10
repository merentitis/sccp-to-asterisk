#!/bin/bash

#check if there are registered sccp extensions and change the status message to all of them:
function f (){
/usr/sbin/asterisk -rx 'sccp show devices' | grep OK | grep -o 'SEP............' | wc -l
}
result=$(f) 
if (($result > 1)) ; then
        echo "PROBLEM - CCM down!"
        /usr/sbin/asterisk -rx 'sccp system message "*Asterisk Fallback*"'
fi
