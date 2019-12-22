#!/bin/bash
#
# Author: Redoracle
# Pool: Stakelovelace.io
# TG: @redoracle


#Configuration Parameters

# Frequency:
FREQ=90         # Normal Operation Refresh Frequency in seconds
FORK_FREQ=120   # Forck Check Mode Refresh Frequency in seconds between checks. after 13 failed attepts to check the block hash, the script will try to do recovery steps if any.

CLI="$(which jcli)";

[ -z "${CLI}" ] && [ -f jcli ] && CLI="./jcli"

[ -z ${JORMUNGANDR_RESTAPI_URL} ] && echo -e "[ERROR] - you must set the shell variable \$JORMUNGANDR_RESTAPI_URL, \\ncheck your node config for the rest: listen_address to identify the URL, \\neg: export JORMUNGANDR_RESTAPI_URL=http://127.0.0.1:3101/api" && exit 1

#Functions
PRINT_SCREEN()
{
                clear;
                echo "$DATE   $HOSTN  Epoch:$lastBlockDateSlot - All OK! - "
                LEADERS=$($CLI rest v0 leaders logs get)
                SLOTS=$(echo $LEADERS | grep scheduled_at_time | wc -l)
                NEXT_SLOTS=$(echo $LEADERS| grep -A 1 scheduled_at_time  | grep $DAY'T'$ORA | wc -l);
                NEXT_SLOTS_LIST=$(echo $LEADERS | grep -A 1 scheduled_at_time  | grep $DAY'T'$ORA | awk '{print $2}'| cut -d "T" -f 2|cut -d "+" -f 1| sort);
                BLOCKS_MADE=$(echo $LEADERS | grep Block | wc |  awk '{print $1}');
                watch_node=$(netstat -anl  | grep tcp | grep EST |  awk '{print $ 5}' | cut -d ':' -f 1 | sort | uniq | wc -l);
                BLOCKS_REJECTED=$(echo $LEADERS | grep Rejected | wc -l );
                REASON_REJECTED=$(echo $LEADERS| grep -A1 Rejected );
                echo "-> Uptime:$uptime                 - BlockHeight: --> $lastBlockHeight <--";
                echo "-> LastBlockTx:$lastBlockTx       - txRecvCnt:$txRecvCnt ";
                echo "->                       - blockRecvCnt:$blockRecvCnt";
                echo "-> Established:$nodesEstablished  - Uniq:$watch_node";
                echo "-> Quarantined:$Quarantined       - NotPublic:$Quarantined_non_public";
                echo " ";
                echo -e "-> Last Hash:\\n$LAST_HASH";
                echo "-> Made:$BLOCKS_MADE - Rejected:$BLOCKS_REJECTED - Slots:$SLOTS - Planned(b/h):$NEXT_SLOTS";
                echo "$NEXT_SLOTS_LIST";
                echo -e ":\\n$REASON_REJECTED";
}

INIT_JSTATS()
{
        DATE=$(date);
        ORA=$(date +"%H");
        HOSTN=$(hostname);
        DAY=$(date +"%d");
        TMPF="/tmp/stats.json";
        QUERY=$($CLI rest v0 node stats get --output-format json > $TMPF)
        lastBlockDateSlot=$( cat $TMPF | jq -r .lastBlockDate | cut -d "." -f 1)
        blockRecvCnt=$(cat $TMPF | jq -r .blockRecvCnt)
        lastBlockHeight=$(cat $TMPF | jq -r .lastBlockHeight)
        uptime=$(cat $TMPF | jq -r .uptime)
        lastBlockTx=$(cat $TMPF | jq -r .lastBlockTx)
        txRecvCnt=$(cat $TMPF | jq -r .txRecvCnt);
        nodesEstablished=$(cat $TMPF | jq '. | length')
        Quarantined=$(curl -s http://127.0.0.1:3101/api/v0/network/p2p/quarantined 2>/dev/null  | jq '.' | grep addr | sort | uniq | wc -l)
        Quarantined_non_public=$(curl -s http://127.0.0.1:3101/api/v0/network/p2p/non_public 2>/dev/null  | jq '.' | grep addr | sort | uniq | wc -l)
        LAST_HASH=$($CLI rest v0 node stats get | grep lastBlockHash | cut -d ":" -f 2| cut -d " " -f 2);
}

RECOVERY_RESTART()
{
                                                echo "-> We're ... Restarting!";
                                                #Your recovery steps
                                                #
                                                TRY=47;
}

PAGER()
{
    echo Pager;
    #Gotify example API
    #E=$(curl -s -X POST "http://172.13.0.4/message?token=XXXXX" -F "title=$HOSTN Potential Fork" -F "message=TRY:$TRY -> HASH: $LAST_HASH" -F "priority=$TRY");
}


while :
do
        INIT_JSTATS
        curl -s 'https://explorer.incentivized-testnet.iohkdev.io/explorer/graphql' -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:71.0) Gecko/20100101 Firefox/71.0' -H 'Accept: */*' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H "Referer: https://shelleyexplorer.cardano.org/en/block/$LAST_HASH/" -H 'Content-Type: application/json' -H 'Origin: https://shelleyexplorer.cardano.org' -H 'DNT: 1' -H 'Connection: keep-alive' -H 'TE: Trailers' --data "{\"query\":\"\n    query {\n      block (id: \\\"$LAST_HASH\\\") {\n        id\n      }\n    }\n  \"}" | grep "\"block\":{\"id\":\"$LAST_HASH\"" &>> /tmp/check.log;
        if [ $? -gt 0 ];
        then
                       echo "--> Evaluating Recovery Restart <--";
                       TRY=0;
                        until [  $TRY -gt 13 ]; do
                         LAST_HASH=$($CLI rest v0 node stats get | grep lastBlockHash | cut -d ":" -f 2| cut -d " " -f 2);
        curl -s 'https://explorer.incentivized-testnet.iohkdev.io/explorer/graphql' -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:71.0) Gecko/20100101 Firefox/71.0' -H 'Accept: */*' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H "Referer: https://shelleyexplorer.cardano.org/en/block/$LAST_HASH/" -H 'Content-Type: application/json' -H 'Origin: https://shelleyexplorer.cardano.org' -H 'DNT: 1' -H 'Connection: keep-alive' -H 'TE: Trailers' --data "{\"query\":\"\n    query {\n      block (id: \\\"$LAST_HASH\\\") {\n        id\n      }\n    }\n  \"}" | grep "\"block\":{\"id\":\"$LAST_HASH\"" &>> /tmp/check.log;
                                if [ $? -gt 0 ];
                                then
                                        let TRY+=1;
                                        INIT_JSTATS;
                                        PRINT_SCREEN;
                                        echo "Attempt number: $TRY";
                                        echo "$DATE - Attention $LAST_HASH - NOT IN EXPLORER";
                                        if [ "$TRY" -eq "13" ];then
                                            RECOVERY_RESTART;
                                        fi
                                        #YOUR pager
                                        PAGER;
                                        sleep $FORK_FREQ;
                                else
                                        echo "-> Restart Aborted";
                                        TRY=71;
                                fi
                        done
        else
                clear;
                INIT_JSTATS;
                PRINT_SCREEN;
                sleep $FREQ;
        fi;
done
