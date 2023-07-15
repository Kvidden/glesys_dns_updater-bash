#!/usr/bin/bash
#
#Copyright (c) 2023, Mikael Kvist
#All rights reserved.
#
#This source code is licensed under the BSD-style license found in the
#LICENSE file in the root directory of this source tree.
#
# Mikael Kvist
# 19/4/21
# DNS uppdaterar glesys
### variabler ###
ipnu=$(curl -s ifconfig.me);
user="API-USER";
key="API-KEY";
domain="Domän som skall uppdateras";
host="host som skall uppdateras";
glesapi="https://api.glesys.com/domain";
echo $(date);
### hämtar domändata ###
dnsdata=$(curl -s -X POST --basic -u $user:$key --data-urlencode "domainname=$domain" $glesapi/listrecords/);
### variabler efter domändata ###
hostinfo=$(echo "$dnsdata" | grep $host\<\/host -A3 -B2 | awk -F '[<>]' '{print $3}')
recordid=$(echo $hostinfo | awk '{print $1}')
ipdns=$(echo $hostinfo | awk '{print $5}')

echo "Jämför IP på datorn $ipnu med IP på DNS $ipdns";
### jämför IP ###
if [ $ipnu = $ipdns ]; then
echo "Samma IP avslutar.";
exit;
else
echo "Nytt IP, uppdaterar IP";
### uppdaterar host ip ###
curl -X POST --basic -u $user:$key -d "recordid=$recordid" -d "host=$host" -d "data=$ipnu" -d "type=A" -d "ttl=3600" $glesapi/updaterecord/;
echo "IP uppdaterat, stänger av";
fi;
exit;
