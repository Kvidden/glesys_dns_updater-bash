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
#
### variabler ###
glesapi="https://api.glesys.com/domain";
user="API-USER";
key="API-KEY";
# satte denna så att vid AWK sakerna kan jag ha mellanrum innan de skickas in i funktionen för for loopen
IFS=$'\n';
if [ -z $(which curl) ]; then
        echo -e "Curl finns inte installerat, detta verktyg behövs för att allt här\nvar snäll och installera curl och starta om";
        exit 1;
fi;
### hjälp funktioner ###
print_domain_list () {
        set_user;
        echo -e "\t\tDessa domäner finns tillgängliga:\n";
        display_loop $domain_list;
};
# här används INTE "" kring variablen då jag vill ha allt på en rad så första awk kan hämta recordid endast då allt är på en rad
# om "" används så blir varje sak på olika rader och andra awk hämtar alla delarna vilket inte behövs...
# skulle kunna ta "" och använda grep för att ta raden och sedan samma awk...
get_host_info () {
        set_host;
        hostinfo=$(curl -s -X POST --basic -u $user:$key -d "domainname=$domain" $glesapi/listrecords/ | grep $host\<\/host -A3 -B2);
        recordid=$(echo $hostinfo | awk '{print $1}'  | awk -F '[<>]' '{print $3}');
        typ=$(echo $hostinfo | awk '{print $4}'  | awk -F '[<>]' '{print $3}');
        data=$(echo $hostinfo | awk '{print $5}'  | awk -F '[<>]' '{print $3}');
};
# använder "" kring variablen för att datan i variablens delar hamnar på varsin rad, varpå varje rads $2 och $3 hämtas..
print_host_info () {
        get_host_info;
        display_loop $(echo "$hostinfo" |  awk -F '[<>]' '{print $2": "$3}');
};
get_host_list () {
        set_domain;
        host_list=$(curl -s -X POST --basic -u $user:$key -d "domainname=$domain" $glesapi/listrecords/ | grep -B 1 "A" | awk -F '[<>]' '{print $3}'  | sed '/CNAME/d' | sed '/A/d');
};
print_host_list () {
        get_host_list;
        echo -e "\t\tDessa hosts är aktiva under $domain\n";
        display_loop $host_list;
};
# loopen används egentligen bara för att få varje ny rad att köra 2 tabbar in, vilket det inte gör annars
display_loop () {
        for each in $@; do
                echo -e "\t\t$each";
        done;
};
status_check () {
        if [[ $host_check = *200* ]]; then
                echo -e "\t\tHosten $host.$domain blev $1";
        elif [[ $host_check = *40* ]] ; then
                echo -e "\t\tHosten $host.$domain blev inte $1";
                echo -e "\t\tFelmeddelandet är: $(echo "$host_check" | grep "text" | awk -F '[<>]' '{print $3}')";
        else
                echo -e "\t\tNågot gick väldigt fel.";
                echo -e "\t\tFelmeddelandet är: $(echo "$host_check" | grep "text" | awk -F '[<>]' '{print $3}')";
                exit 1;
        fi;
};
### host funktioner ###
update_host_data () {
        echo -e;
        echo -e "\t\tVad vill du uppdatera på $host.$domain?";
        echo -e;
        echo -e "\t\t1. Hostnamnet?\t2. Typ av post?";
        if [ $typ = "A" ]; then
                echo -e "\t\t3. IP adress?\t4. Allt?";
        elif [ $typ = "CNAME" ]; then
                echo -e "\t\t3. CNAME adress\t4. Allt?";
        else
                echo -e "\t\t3. Data typ stöds ej\t4. Allt?";
        fi;
        echo -e;
        echo -en "\t\tVälj vad som önskas göras: ";
        read -n 1 val;
        while [ 1 ]; do
                case $val in
                        1 )
                                set_host_data host;
                                break ;;
                        2 )
                                set_host_data typ data;
                                break ;;
                        3 )
                                if [ $typ = "A" ]; then
                                        echo -en "\n\t\t1. Ange IP manuellt?\t2. Ta nuvarande externt IP? "
                                        read ip;
                                        while [ 1 ] ; do
                                                case $ip in
                                                        1 )
                                                                set_host_data data;
                                                                break ;;
                                                        2 )
                                                                externalip=$(curl -s ifconfig.me)
                                                                if [ $data = $externalip ]; then
                                                                        echo -e "\t\tExternt IP samma som på Glesys, ingen åtgärd sker";
                                                                else
                                                                        echo -e "\t\tUppdaterar med IP: $externalip";
                                                                        data=$externalip;
                                                                fi;
                                                                set_host_data;
                                                                break ;;
                                                        * ) ;;
                                                esac;
                                                echo -en "\n\t\tFelaktigt svar, svara med 1 eller 2: ";
                                                read ip;
                                        done;
                                elif [ $typ = "CNAME" ]; then
                                        set_host_data data;
                                fi;
                                break ;;
                        4 )
                                set_host_data host typ data;
                                break ;;
                        * ) ;;
                esac;
                echo -en "\n\t\tFelaktigt svar, svara med 1,2,3 eller 4: ";
                read $val;
        done;
};
host_changes () {
        if [ -z $host ]; then
                svar=JA;
        else
                echo -en "\t\tVill du $1 hosten $host.$domain? [JA/NEJ] ";
                read svar;
        fi;
        svar=${svar^^};
        while [ 1 ]; do
                case $svar in
                        JA )
                                case $1 in
                                        uppdatera )
                                                get_host_info;
                                                update_host_data;
                                                echo -e "\n\t\tUppdaterar $host.$domain enligt önskemål.";
                                                host_check=$(curl -s -X POST --basic -u $user:$key -d "domainname=$domain" -d "host=$host" -d "type=$typ" -d "data=$data" -d "recordid=$recordid" $glesapi/updaterecord/) ;
                                                status_check uppdaterad ;;
                                        "ta bort" )
                                                get_host_info;
                                                host_check=$(curl -s -X POST --basic -u $user:$key -d "recordid=$recordid" $glesapi/deleterecord/);
                                                status_check borttagen ;;
                                        "lägg till" )
                                                set_domain;
                                                set_host_data host typ data;
                                                echo -e "\n\t\tLägger till $host.$domain som en $typ post.";
                                                host_check=$(curl -s -X POST --basic -u $user:$key -d "domainname=$domain" -d "host=$host" -d "type=$typ" -d "data=$data" $glesapi/addrecord/) ;
                                                status_check tillagd ;;
                                esac;
                                break ;;
                        NEJ )
                                echo -e "\t\t▒~Vnskas annan host eller domän så ställ in i huvudmenyn och kör igen";
                                break ;;
                        * ) ;;
                esac;
                echo -en "\n\t\tFelaktigt svar, svara med Ja eller Nej: ";
                read $svar;
        done;
};
set_host_data () {
        for each in $@; do
                case $each in
                        host )
                                echo -en "\n\t\tAnge hostnamnet du vill använda för $domain: ";
                                read host ;;
                        typ )
                                echo -en "\n\t\tAnge vilken typ $host.$domain skall vara, A eller CNAME?: ";
                                read typ;
                                typ=${typ^^} ;;
                        data )
                                if [ $typ = "A" ]; then
                                        echo -en "\n\t\tAnge IP för $host.$domain: ";
                                        read data;
                                elif [ $typ = "CNAME" ]; then
                                        echo -en "\n\t\tAnge adressen som $host.$domain skall peka emot: ";
                                        read data;
                                        data="$data.";
                                else
                                        echo -e "\n\t\tVarken A eller CNAME angavs som typ av post.";
                                fi ;;
                esac;
        done;
};
###  kontroll funktioner ###
set_host () {
        set_domain;
        while [ -z $host ] || [ ! -z $1 ]; do
                echo -e "\t\tHost saknas eller har valts att ändras.";
                echo -en "\t\tAnge host för domän $domain: ";
                read host;
                get_host_list;
                for each in $host_list; do
                        if [[ $host = *$each* ]]; then
                                echo -e "\n\t\tHost satt till $host.$domain";
                                break 2;
                        fi;
                done;
                echo -e "\n\t\tHosten fanns inte på $domain.";
                echo -e "\t\tVälja bland dessa:";
                display_loop $host_list;
                host="";
        done;
};
set_domain () {
        set_user;
        while [ -z $domain ] || [ ! -z $1 ]; do
                echo -e "\t\tDomän saknas eller har valts att ändras.";
                echo -en "\t\tAnge domän: ";
                read domain;
                for each in $domain_list; do
                        if [[ $domain = $each ]]; then
                                echo -e "\n\t\tDomän satt till $domain";
                                break 2;
                        fi;
                done;
                echo -e "\n\t\tDomänen fanns inte för $user.";
                echo -e "\t\tVälja bland dessa:";
                display_loop $domain_list;
                domain="";
        done;
};
set_user () {
        while [ -z $user ] || [ ! -z $1 ]; do
                echo -e "\t\tUser saknas eller har valts att ändras.";
                echo -en "\t\tAnge Glesys user: ";
                read user;
                echo -en "\t\tAnge Glesys userkey: ";
                read key;
                check_login=$(curl -s -X POST --basic -u $user:$key $glesapi/list/);
                if [[ $check_login = *200* ]]; then
                        echo -e "\n\t\tUser och key var godkända";
                        break;
                elif [[ $check_login = *401* ]]; then
                        echo -e "\n\t\tFelaktiga uppgifter angivna, var snäll gör om.";
                        user="";
                fi;
        done;
        domain_list=$(curl -s -X POST --basic -u $user:$key $glesapi/list/ | grep "domainname" | awk -F '[<>]' '{print $3}');
};
meny () {
        clear;
        echo;
        echo -e ;
        echo -e "\t\t\tGlesys DNSupdater\n\n";
        echo -e ;
        echo -e ;
        echo -e "\t\t1: Ändra user\tNuvarande User: $user";
        echo -e "\t\t2: Ändra domän\tNuvarande Domän: $domain";
        echo -e "\t\t3: Ändra host\tNuvarande Host: $host";
        if [ -z $user ];then
                echo -e "\t\t4: Lista av domäner för: ingen user satt";
        else
                echo -e "\t\t4: Lista av domäner för: $user";
        fi;
        if [ -z $domain ];then
                echo -e "\t\t5: Lista av hosts under: ingen domän bestämd";
        else
                echo -e "\t\t5: Lista av hosts under: $domain";
        fi;
        if [ -z $host ];then
                echo -e "\t\t6: Info om: ingen host bestämd";
        else
                echo -e "\t\t6: Info om: $host.$domain";
        fi;
        if [ -z $host ];then
                echo -e "\t\t7: Uppdatera host: ingen host bestämd";
        else
                echo -e "\t\t7: Uppdatera host: $host.$domain";
        fi;
        if [ -z $domain ];then
                echo -e "\t\t8: Lägg till ny host för: ingen domän bestämd";
        else
                echo -e "\t\t8: Lägg till ny host för: $domain";
        fi;
        if [ -z $host ];then
                echo -e "\t\t9: Ta bort host: ingen host bestämd";
        else
                echo -e "\t\t9: Ta bort host: $host.$domain";
        fi;
        echo -e "\t\t\t0: Avsluta";
        echo -e ;
        echo -e ;
        echo -en "\t\tVälj vad som önskas göras: ";
        read -n 1 menyval;
};
while [ 1 ]; do
        setdata="NO";
        meny;
        case $menyval in
                0 )
                        echo -e "\n";
                        echo -e "\t\tStänger ner";
                        sleep 1;
                        break ;;
                1 )
                        echo -e "\n";
                        set_user change ;;
                2)
                        echo -e "\n";
                        set_domain change ;;
                3 )
                        echo -e "\n";
                        set_host change ;;
                4 )
                        echo -e "\n";
                        print_domain_list ;;
                5 )
                        echo -e "\n";
                        print_host_list ;;
                6 )
                        echo -e "\n";
                        print_host_info ;;
                7 )
                        echo -e "\n";
                        host_changes uppdatera ;;
                8 )
                        echo -e "\n";
                        host=""
                        host_changes "lägg till" ;;
                9 )
                        echo -e "\n";
                        host_changes "ta bort" ;;
                * )
                        echo -e "\n";
                        echo -e "\t\tFelaktigt val!" ;;
        esac;
        echo -en "\n\n\t\tTryck på valfri knapp för att gå vidare";
        read -n 1 line;
done;
#clear;
exit 0;
