#!/bin/bash

# Author: Redoracle
# Pool: Stakelovelace.io
# TG: @redoracle
#
# To keep logs of this WatchDog tool please use it as described below.
# Usage: ./jstatus.sh | tee /tmp/jstatus.log
#
# - PoolTool sendtips.sh functions integrated if ENV vars are declared. 
# - Fork/Sanity Check by cross referencing the last block hash in explorer and the Pooltool tip
# 
#
# How the fork/stuck check works:
# The script will retrieve  the last block hash elaborated by the node (jcli) and query the ITN IOHK eplorer to very the block hash  
# In addition the node BlockHihgt is updated on PoolTool.io and simultaneosly using the return value and second reference before 
# starting evaluating the Recovery Restart function.
#
# When exported the MY_POOL_ID variable, your pool's stats (rewards and stake) will show up on the screen 
#
# Do not forget to customize the RECOVERY_RESTART() function in order to implement your own recovery procedure.
#
# Init
shopt -s expand_aliases
alias CLI="$(which jcli) rest v0"

[ -f CLI ] && [ -f jcli ] && CLI="./jcli"
[ -z ${JORMUNGANDR_RESTAPI_URL} ] && echo -e "[ERROR] - you must set the shell variable \$JORMUNGANDR_RESTAPI_URL, \\ncheck your node config for the rest: listen_address to identify the URL, \\neg: export JORMUNGANDR_RESTAPI_URL=http://127.0.0.1:3101/api" && exit 1

#Configuration Parameters
GENESISHASH="8e4d2a343f3dcf9330ad9035b3e8d168e6728904262f2c434a4f8f934ec7b676"
# Frequency:
FREQ=90              # Normal Operation Refresh Frequency in seconds
FORK_FREQ=120        # Forck Check Mode Refresh Frequency in seconds between checks. after 13 failed attepts to check the block hash, the script will try to do recovery steps if any.
RECOVERY_CYCLES=13      # How many times will test the Explorer Website with consecutive errors

LEADERS=/tmp/leaders_logs.log   # PATH of the temporary leaders logs from jcli for collecting stats

#PoolTool Configuration
THIS_GENESIS="8e4d2a343f3dcf93"   # We only actually look at the first 7 characters
#export MY_POOL_ID="YOUR-POOL-ID"
#export MY_USER_ID="YOUR-POOLTOOL-ID"  # on pooltool website get this from your account profile page
[ -z ${MY_POOL_ID} ] && echo -e "[WARN] - PoolTool parameters not set \\neg: export MY_POOL_ID=xxxxxxxxxxx \neg: export MY_USER_ID=xxxx-xxxxx-xx" && PoolToolHeight="00000";


# Clolors
BOLD="\e[1;37m"; GREEN="\e[1;32m"; POOLT="\e[1;44m"; RED="\e[1;31m"; ORANGE="\e[33;5m"; NC="\e[0m"; CYAN="\e[0;36m"; LGRAY1="\e[1;37m"; LGRAY="\e[2;37m"; BHEIGHT="\e[1;32m";
REW="\e[1;93m";

clear;
echo -e "\\t\\t$BOLD- jstatus WatchDog -$NC";
echo -e "\\t\\t$LGRAY1    v1.1   2019 $NC\\n\\n";
echo -e "\\t\\t$LGRAY1     Loading...  $NC\\n\\n";

# Functions
POOLTOOL()
{
if [[ $PoolToolHeight == "00000" ]]; 
then
    BHEIGHT="\e[1;31m";
else
    #PTlastBlockHeight=$(CLI node stats get --output-format json | jq -r .lastBlockHeight)
    PoolToolURL="https://tamoq3vkbl.execute-api.us-west-2.amazonaws.com/prod/sharemytip?poolid=$MY_POOL_ID&userid=$MY_USER_ID&genesispref=$THIS_GENESIS&mytip=$lastBlockHeight";
    PoolToolHeight=$(curl -s -G $PoolToolURL | grep pooltool | cut -d "\"" -f 6);
fi


if [ "$lastBlockHeight" != "$PoolToolHeight" ]; 
then
    BHEIGHT="\e[1;31m";
else
    BHEIGHT="\e[1;32m";
fi
sleep 3;
}

PRINT_SCREEN()
{
                LEADERS_QUERY=$(CLI leaders logs get > $LEADERS);
                SLOTS=$(cat $LEADERS | grep scheduled_at_time | wc -l);
                NEXT_SLOTS=$(cat $LEADERS | grep -A 1 scheduled_at_time  | grep $DAY'T'$ORA | wc -l);
                NEXT_SLOTS_LIST=$(cat $LEADERS | grep -A 1 scheduled_at_time  | grep $DAY'T'$ORA | awk '{print $2}'| cut -d "T" -f 2|cut -d "+" -f 1| sort);
                BLOCKS_MADE1=$(cat $LEADERS | grep -A 1 Block | grep block >> /tmp/$lastBlockDateSlot.leaders_logs.1 );
                BLOCKS_MADE2=$(cat /tmp/$lastBlockDateSlot.leaders_logs.1 | grep block | sort | uniq > /tmp/$lastBlockDateSlot.leaders_logs );
                BLOCKS_MADE=$(cat /tmp/$lastBlockDateSlot.leaders_logs | grep block | wc -l );
                watch_node=$(netstat -anl  | grep tcp | grep EST |  awk '{ print $5 }' | cut -d ':' -f 1 | sort | uniq | wc -l);
                BLOCKS_REJECTED=$(cat $LEADERS | grep Rejected | wc -l );
                REASON_REJECTED=$(cat $LEADERS | grep -A1 Rejected );
                clear;
                echo -e "-> $DATE \\t $STATUS";
                echo -e "-> HOST:$BOLD$HOSTN$NC   Epoch:$BOLD$lastBlockDateSlot$NC   Uptime:$BOLD$uptime$NC  ";
                echo -e " ";
                echo -e "-> RecvCnt:\\t$LGRAY$blockRecvCnt$NC \\t- BlockHeight:\\t$BHEIGHT-> $lastBlockHeight <-$NC";
                echo -e "-> BlockTx:\\t$LGRAY$lastBlockTx$NC \\t- PoolTHeight:\\t$POOLT-> $PoolToolHeight <-$NC";
                echo -e "-> txRecvCnt:\\t$LGRAY$txRecvCnt$NC \\t- Quarantined:\\t$ORANGE$Quarantined$NC"       ;
                echo -e "-> UniqIP:\\t$CYAN$watch_node$NC \\t- Established:\\t$BOLD$nodesEstablished$NC";
                echo -e "$POOLINFO";
                echo -e " ";
                echo -e "-> Last Hash:\\n$LAST_HASH";
                echo -e "-> Made:$GREEN$BLOCKS_MADE $NC- Rejected:$RED$BLOCKS_REJECTED$NC - Slots:$ORANGE$SLOTS$NC - Planned(b/h):$BOLD$NEXT_SLOTS$NC";
                echo -e "$BOLD$NEXT_SLOTS_LIST$NC";
                echo -e ":\\n$ORANGE$REASON_REJECTED$NC\\n";
}

INIT_JSTATS()
{
        DATE=$(date);
        ORA=$(date +"%H");
        HOSTN=$(hostname);
        DAY=$(date +"%d");
        TMPF="/tmp/stats.json";
        QUERY=$(CLI  node stats get --output-format json > $TMPF)
        lastBlockDateSlot=$( cat $TMPF | jq -r .lastBlockDate | cut -d "." -f 1)
        blockRecvCnt=$(cat $TMPF | jq -r .blockRecvCnt);
        lastBlockHeight=$(cat $TMPF | jq -r .lastBlockHeight);
        uptime=$(cat $TMPF | jq -r .uptime);
        lastBlockTx=$(cat $TMPF | jq -r .lastBlockTx);
        txRecvCnt=$(cat $TMPF | jq -r .txRecvCnt);
        nodesEstablished=$(cat $TMPF | jq '. | length');
        Quarantined=$(curl -s $JORMUNGANDR_RESTAPI_URL/v0/network/p2p/quarantined 2>/dev/null  | jq '.' | grep addr | sort | uniq | wc -l)
        Quarantined_non_public=$(curl -s $JORMUNGANDR_RESTAPI_URL/v0/network/p2p/non_public 2>/dev/null  | jq '.' | grep addr | sort | uniq | wc -l)
        LAST_HASH=$(cat $TMPF | jq -r .lastBlockHash );

        if [ $MY_POOL_ID ]; 
            then
            LAST_EPOCH_POOL_REWARDS=$(CLI stake-pool get $MY_POOL_ID | grep value_taxed | awk '{print $2}' | awk '{print $1/1000000}' | cut -d "." -f 1 );
            POOL_DELEGATED_STAKEQ=$(CLI stake-pool get $MY_POOL_ID | grep total_stake | awk '{print $2}' | awk '{print $1/1000000000}' | cut -d "." -f 1 );
            POOL_DELEGATED_STAKE="Stake(K):\\t$REW$POOL_DELEGATED_STAKEQ$NC"
            LASTREWARDS="LastRewards:\\t$REW$LAST_EPOCH_POOL_REWARDS$NC";
            POOLINFO="-> $POOL_DELEGATED_STAKE\\t- $LASTREWARDS"
            else
            POOLINFO="";
        fi
}


RECOVERY_RESTART()
{
    echo "-> We're ... Restarting!";
    #AUE=$(curl -s -X POST "http://172.13.0.4/message?token=xxxx" -F "title=$HOSTN Fork Restart" -F "message=Restarting!!" -F "priority=$TRY");
    #jshutdown=$(CLI shutdown get);
    #sleep 2;
    #CLEANDB=$(rm -rf /datak/jormungandr-storage);
    RECOVERY=$(echo recovery)
    #START=$(start-pool &> /tmp/$HOSTN.log &);
    TRY=47;
}

PAGER()
{
    echo Pager;
    #Gotify example API
    #AUE=$(curl -s -X POST "http://172.13.0.4/message?token=xxx" -F "title=$HOSTN Potential Fork" -F "message=TRY:$TRY -> HASH: $LAST_HASH" -F "priority=$TRY");
}

EXPLORER_CHECK()
{
curl -s 'https://explorer.incentivized-testnet.iohkdev.io/explorer/graphql' -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:71.0) Gecko/20100101 Firefox/71.0' -H 'Accept: */*' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H "Referer: https://shelleyexplorer.cardano.org/en/block/$LAST_HASH/" -H 'Content-Type: application/json' -H 'Origin: https://shelleyexplorer.cardano.org' -H 'DNT: 1' -H 'Connection: keep-alive' -H 'TE: Trailers' --data "{\"query\":\"\n    query {\n      block (id: \\\"$LAST_HASH\\\") {\n        id\n      }\n    }\n  \"}" | grep "\"block\":{\"id\":\"$LAST_HASH\"" &> /tmp/explorer.check.log;
RESU=$?;

if [ $RESU -gt 0 ]; 
then
    STATUS="$RED- HASH NOT IN EPLORER! -$NC"
else
    STATUS="$GREEN - Looking Good! - $NC"
fi
}

while :
do
        INIT_JSTATS;
        EXPLORER_CHECK;
        POOLTOOL;
        if [ $RESU -gt 0 ] && [[ $PoolToolHeight != $lastBlockHeight || $PoolToolHeight == "000000" ]];
        then
                       echo "--> Evaluating Recovery Restart ";
                       TRY=0;
                        until [  $TRY -gt $RECOVERY_CYCLES ]; do
                        LAST_HASH=$(CLI node stats get | grep lastBlockHash | cut -d ":" -f 2| cut -d " " -f 2);
                        EXPLORER_CHECK;
                        POOLTOOL;
                        if [ $RESU -gt 0 ] && [[ $PoolToolHeight != $lastBlockHeight || $PoolToolHeight == "000000" ]];                                
                                then
                                        let TRY+=1;
                                        INIT_JSTATS;
                                        POOLTOOL;
                                        PRINT_SCREEN;
                                        echo -e "Attempt number: $RED$TRY$NC/$ORANGE$RECOVERY_CYCLES$NC before recovery restart.";
                                        if [ "$TRY" -eq "$RECOVERY_CYCLES" ];then
                                            echo -e "$RED--> Attempt number $RECOVERY_CYCLES reached \\n --> Recovering...$NC";
                                            RECOVERY_RESTART;
                                        sleep 180;
                                        fi
                                        #YOUR pager
                                        PAGER;
                                        sleep $FORK_FREQ;
                                else
                                        echo -e "-->$GREEN Restart Aborted $NC";
                                        POOLTOOL;
                                        sleep 1;
                                        TRY=71;
                                fi
                        done
        else
                INIT_JSTATS;
                PRINT_SCREEN;
                sleep $FREQ;
        fi;
done
