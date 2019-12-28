#!/bin/bash

# Author: Redoracle
# Pool: Stakelovelace.io
# TG: @redoracle
#
# To keep logs of this WatchDog tool please use it as described below.
# Usage: ./jstatus.sh | tee /tmp/jstatus.log
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
# Featuers:
#              - PoolTool sendtips.sh functions integrated if ENV vars are declared.  
#              - Fork/Sanity Check (by simultaneolsy checking PoolTool and ShellyExplorer)
#              - Node Stuck by setting max block heghit difference: "Block_diff" (default 100)
#              - IM samples for Gotify and Telegram (thanks to @Gufmar)
#
# Notes: the msg " HASH NOT IN ESPLORER" could happen in 3 different situations:
#           - 1) The HAST is not yet in Shelly Exporer, not in sync (usually after few minutes the alert reset because the scripts 
#                retries and finds it)
#           - 2) Shelly Exporer Webserver is not responding (usually after few minutes the alert reset because the scripts retries 
#                and finds it)
#           - 3) The HAST is not yet in Shelly Exporer and never will be because your node is on a fork, for making sure we do not 
#                get False Positive we also check PoolTool - Very Useful Tool -.
#
#   
#
# Disclaimers:
#               1)   -->!!    USE THIS SCRIPT AT YOUR OWN RISK. IT IS YOUR OWN RESPONSABILITY TO MONITOR YOUR NODE!    !!<--
#               2)                                  DO YOUR OWN TUNING --> 
#       Each node might need proper fine tunes of the Global variable declared under the "## Configuration Parameters" section.
#               3)   -->!!    USE THIS SCRIPT AT YOUR OWN RISK. IT IS YOUR OWN RESPONSABILITY TO MONITOR YOUR NODE!    !!<--
#
# Contributors: @Cardano_Staking_Pools_Alliance SPAI
#
## Shelly Explorer:
# https://explorer.incentivized-testnet.iohkdev.io/explorer/
#
## Configuration Parameters 
GENESISHASH="8e4d2a343f3dcf9330ad9035b3e8d168e6728904262f2c434a4f8f934ec7b676"

## PoolTool Configuration
THIS_GENESIS="8e4d2a343f3dcf93"   # We only actually look at the first 7 characters

#export MY_POOL_ID="YOUR-POOL-ID"   # Your Pool public IP
#export MY_USER_ID="YOUR-POOLTOOL-ID"  # on pooltool website get this from your account profile page

[ -z ${MY_USER_ID} ] && echo -e "[WARN] - PoolTool parameters not set \\neg: export MY_POOL_ID=xxxxxxxxxxx \neg: export MY_USER_ID=xxxx-xxxxx-xx" && PoolToolHeight="00000";

## Telegram Message API 
#
# 1) Talk with @BotFather and a create a new bot with the command "/newbot" follow the procedure and keep notes of your BotToken
# 2) Then invite @Markdown @RawDataBot and also get the "chat_id"
#    This is an individual chat-ID between the bot and this TG-user the bot is allowed to respond, when the user send a first message.
# 3) write some messages within your botchat group and then run the following command:
# 4) curl -s https://api.telegram.org/bot${TG_BotToken}/getUpdates | jq .
#    the returned JSON contains the chat-ID from the last message the bot received.
# 4b) or get directly the chat_id:
#    curl -s https://api.telegram.org/bot${TG_BotToken}/getUpdates | jq . | grep -A1 chat | grep -m 1 id | awk '{print $2}' | cut -d "," -f1
## TG Settings:
#TG_BotToken="xxxxxxxxx:xxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxx"
#TG_ChatId="xxxxxxxxx"
#TG_URL="https://api.telegram.org/bot${TG_BotToken}/sendMessage?chat_id=${TG_ChatId}&parse_mode=Markdown"

ALERT_MINIMUM=0      # minimum test loops pefore pager alert

## Cycles Time frequency in seconds:
FREQ=60                 # Normal Operation Refresh Frequency in seconds

FORK_FREQ=120           # Forck Check - Warning Mode Refresh Frequency in seconds between checks. after 13 consecutive failed attempts to check 
                        # the last block hash the script will try to do the recovery steps if any. See RECOVERY_RESTART().

RECOVERY_CYCLES=13      # How many times will the test cycle (Explorer Website check  + PoolTool check) with consecutive errors
                        # the script will try to do the recovery steps if any. See RECOVERY_RESTART()

FLATCYCLES=5            # Every Cycle FREQ lastblockheight will be checked and if it stays the same for FLATCYCLES times, 
                        # than the Monster will be Unleashed! 

## Block difference checks for stucked nodes
#
Block_diff=50  # Block_diff is a isolated check which alone will trigger 1 of 13 warning alerts befor calling the function RESTART_RECOVERY - Explorer will be out of the checks chain
Block_delay=20  # Block_delay is part of the double check algorithm with the comparison of the shellyExplorer (the combination of 1 Hash not found and Lastblock heigh < 20 blocks trigger 1 of 13 consecutives alerts before triggering the recovery)


## Log PATH
#
LOG_DIRECTORY="/tmp"
LEADERS="$LOG_DIRECTORY/leaders_logs.log"   # PATH of the temporary leaders logs from jcli for collecting stats

## Clolors palette
#
BOLD="\e[1;37m"; GREEN="\e[1;32m"; RED="\e[1;31m"; ORANGE="\e[33;5m"; NC="\e[0m"; CYAN="\e[0;36m"; LGRAY1="\e[1;37m"; LGRAY="\e[2;37m"; BHEIGHT="\e[1;32m";
REW="\e[1;93m"; POOLT="\e[1;44m";

## Main Init
#
shopt -s expand_aliases
alias CLI="$(which jcli) rest v0"

[ -f CLI ] && [ -f jcli ] && CLI="./jcli"
[ -z ${JORMUNGANDR_RESTAPI_URL} ] && echo -e "[ERROR] - you must set the shell variable \$JORMUNGANDR_RESTAPI_URL, \\ncheck your node config for the rest: listen_address to identify the URL, \\neg: export JORMUNGANDR_RESTAPI_URL=http://127.0.0.1:3101/api" && exit 1

clear;
echo -e "\\t\\t$BOLD- jstatus WatchDog -$NC";
echo -e "\\t\\t$LGRAY1   v1.1.2   2019 $NC\\n\\n";
echo -e "\\t\\t$LGRAY1    Loading...  $NC\\n\\n";


## Functions
POOLTOOL()
{
if [[ $PoolToolHeight == "00000" ]]; 
then
    BHEIGHT="\e[1;31m";
else
    PoolToolURL="https://api.pooltool.io/v0/sharemytip?poolid=$MY_POOL_ID&userid=$MY_USER_ID&genesispref=$THIS_GENESIS&mytip=$lastBlockHeight";
    PoolToolHeight=$(curl -s -G $PoolToolURL | grep pooltool | cut -d "\"" -f 6);
fi
PoolToolStats=$(curl -s -X POST https://api.pooltool.io/dev/gettips?genesispref=8e4d2a3 > $LOG_DIRECTORY/pooltool_stats.json);
PoolT_min=$(cat $LOG_DIRECTORY/pooltool_stats.json | jq .min );
PoolT_syncd=$(cat $LOG_DIRECTORY/pooltool_stats.json | jq .syncd );
PoolT_sample=$(cat $LOG_DIRECTORY/pooltool_stats.json | jq .samples );
PoolT_max=$(cat $LOG_DIRECTORY/pooltool_stats.json | jq .max );
POOLTOOLSTAS="PoolTHeight:\\t$POOLT-> M:$PoolT_max - m:$PoolT_min - ($PoolT_syncd/$PoolT_sample) <-$NC";

if [ "$lastBlockHeight" -lt $(($PoolT_max - $Block_delay)) ]; 
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
                SLOTS=$(cat $LEADERS | grep -B2 Pending | grep -A1 "scheduled_at_date:" | grep -A1 "$lastBlockDateSlot\." | grep scheduled_at_time | wc -l);
                NEXT_SLOTS=$(cat $LEADERS | grep -A 1 scheduled_at_time  | grep $DAY'T'$ORA | wc -l);
                NEXT_SLOTS_LIST=$(cat $LEADERS | grep scheduled_at_time  | grep $DAY'T'$ORA | awk '{print $2}'| cut -d "T" -f 2|cut -d "+" -f 1| sort);
                BLOCKS_MADE1=$(cat $LEADERS | grep -A1 -B3 Block | grep -A5 "scheduled_at_date:" | grep -A4 "$lastBlockDateSlot\." | grep block | cut -d ":" -f 2 >> $LOG_DIRECTORY/$lastBlockDateSlot.leaders_logs.1 );
                BLOCKS_MADE2=$(cat $LOG_DIRECTORY/$lastBlockDateSlot.leaders_logs.1 | sort | uniq  > $LOG_DIRECTORY/$lastBlockDateSlot.leaders_logs);
                BLOCKS_MADE=$(cat $LOG_DIRECTORY/$lastBlockDateSlot.leaders_logs | wc -l );
                watch_node=$(netstat -anl  | grep tcp | grep EST |  awk '{ print $5 }' | cut -d ':' -f 1 | sort | uniq | wc -l);
                BLOCKS_REJECTED1=$(cat $LEADERS | grep -B3 Rejected | grep -A1 "$lastBlockDateSlot\."| grep scheduled_at_time >> $LOG_DIRECTORY/$lastBlockDateSlot.leaders_rej_logs);
                BLOCKS_REJECTED2=$(cat $LOG_DIRECTORY/$lastBlockDateSlot.leaders_rej_logs| sort | uniq > $LOG_DIRECTORY/$lastBlockDateSlot.leaders_rej_uniq_logs);
                BLOCKS_REJECTED=$(cat $LOG_DIRECTORY/$lastBlockDateSlot.leaders_rej_uniq_logs | wc -l );
                REASON_REJECTED=$(cat $LEADERS | grep -A1 Rejected );
                clear;
                echo -e "-> $DATE \\t $STATUS";
                echo -e "-> HOST:$BOLD$HOSTN$NC   Epoch:$BOLD$lastBlockDateSlotFull$NC   Uptime:$BOLD$uptime$NC  ";
                echo -e " ";
                echo -e "-> RecvCnt:\\t$LGRAY$blockRecvCnt$NC \\t- BlockHeight:\\t$BHEIGHT-> $lastBlockHeight <-$NC";
                echo -e "-> BlockTx:\\t$LGRAY$lastBlockTx$NC \\t- $POOLTOOLSTAS";
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
        TMPF="$LOG_DIRECTORY/stats.json";
        QUERY=$(CLI  node stats get --output-format json > $TMPF);
        lastBlockDateSlot=$( cat $TMPF | jq -r .lastBlockDate | cut -d "." -f 1);
        lastBlockDateSlotFull=$( cat $TMPF | jq -r .lastBlockDate )
        blockRecvCnt=$(cat $TMPF | jq -r .blockRecvCnt);
        lastBlockHeight=$(cat $TMPF | jq -r .lastBlockHeight);
        uptime=$(cat $TMPF | jq -r .uptime);
        lastBlockTx=$(cat $TMPF | jq -r .lastBlockTx);
        txRecvCnt=$(cat $TMPF | jq -r .txRecvCnt);
        nodesEstablished=$(CLI network stats get --output-format json | jq '. | length');
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
    #AUE=$(curl -s -X POST "http://172.13.0.4/message?token=Ap59j48LrTeyvQx" -F "title=$HOSTN Fork Restart" -F "message=Restarting!!" -F "priority=$TRY");
    #jshutdown=$(CLI shutdown get);
    #sleep 2;
    #CLEANDB=$(rm -rf /datak/jormungandr-storage);
    #RECOVERY=$(echo recovery)
    #START=$(start-pool &> $LOG_DIRECTORY/$HOSTN.log &);
    TRY=47;
}

PAGER()
{
    echo Pager;
    ##Telegram
    #TGAUE=$(curl -s -X POST $TG_URL -d text="$HOSTN Potential Fork %0ATRY:$TRY %0AHASH: $LAST_HASH %0APOOLTHEIGHT: $PoolT_max %0APOOLINFO: %0ADS: $POOL_DELEGATED_STAKEQ LR: $LAST_EPOCH_POOL_REWARDS");
    ##Gotify
    #AUE=$(curl -s -X POST "http://172.13.0.4/message?token=Ap59j48LrTeyvQx" -F "title=$HOSTN Potential Fork" -F "message=TRY:$TRY -> HASH:$LAST_HASH PTH:$PoolT_max DS:$POOL_DELEGATED_STAKEQ LR:$LAST_EPOCH_POOL_REWARDS" -F "priority=$TRY");
}

PAGER_BLOCK_MADE()
{
        echo -e "\\n-> New block made";
        ##Telegram
        #TGAUE=$(curl -s -X POST $TG_URL -d text="$HOSTN Block just Made N: $BLOCKS_MADE %0APOOLTHEIGHT: $PoolT_max %0APOOLINFO: %0ADS: $POOL_DELEGATED_STAKEQ LR: $LAST_EPOCH_POOL_REWARDS");
        #AUE=$(curl -s -X POST "http://172.13.0.4/message?token=Ap59j48LrTeyvQx" -F "title=$HOSTN Block just Made" -F "message=$HOSTN Block just Made N:$BLOCKS_MADE PTH:$PoolT_max DS:$POOL_DELEGATED_STAKEQ LR:$LAST_EPOCH_POOL_REWARDS" -F "priority=5");

}

PAGER_BLOCK_REJ()
{
        echo -e "\\n-> New block rejected";
        ##Telegram
        #TGAUE=$(curl -s -X POST $TG_URL -d text="$HOSTN Block just Rejected N:$BLOCKS_REJECTED R:$REASON_REJECTED %0APOOLTHEIGHT: $PoolT_max %0APOOLINFO: %0ADS: $POOL_DELEGATED_STAKEQ LR: $LAST_EPOCH_POOL_REWARDS");
        ##Gotify
        #AUE=$(curl -s -X POST "http://172.13.0.4/message?token=Ap59j48LrTeyvQx" -F "title=HOSTN Block just Rejected" -F "message=$HOSTN Block just Made N:$BLOCKS_MADE POOLTHEIGHT: $PoolT_max" -F "priority=8");
}

EXPLORER_CHECK()
{
curl -s 'https://explorer.incentivized-testnet.iohkdev.io/explorer/graphql' -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:71.0) Gecko/20100101 Firefox/71.0' -H 'Accept: */*' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H "Referer: https://shelleyexplorer.cardano.org/en/block/$LAST_HASH/" -H 'Content-Type: application/json' -H 'Origin: https://shelleyexplorer.cardano.org' -H 'DNT: 1' -H 'Connection: keep-alive' -H 'TE: Trailers' --data "{\"query\":\"\n    query {\n      block (id: \\\"$LAST_HASH\\\") {\n        id\n      }\n    }\n  \"}" | grep "\"block\":{\"id\":\"$LAST_HASH\"" &> $LOG_DIRECTORY/explorer.check.log;
RESU=$?;

if [ $RESU -gt 0 ]; then
    STATUS="$RED- HASH NOT IN EPLORER! -$NC"
elif [[ $FLATLINERSCOUNTER -gt 3 ]]; then
    STATUS="$RED- FLATLINER DETECTED! n:$FLATLINERSCOUNTER -$NC"
else
    STATUS="$GREEN - Looking Good! - $NC"
fi
}

EVAL_PAGE_BLOCK()
{
if [ $BLOCKS_REJECTED -gt $BLOCKS_REJECTED_TMP ]; then
    PAGER_BLOCK_REJ;
    BLOCKS_REJECTED_TMP="$BLOCKS_REJECTED";
else
    BLOCKS_REJECTED_TMP="$BLOCKS_REJECTED";
fi
    
if [ $BLOCKS_MADE -gt $BLOCKS_MADE_TMP ]; then
    PAGER_BLOCK_MADE;
    BLOCKS_MADE_TMP="$BLOCKS_MADE";
else
    BLOCKS_MADE_TMP="$BLOCKS_MADE";
fi
}

## Reset Variables
BLOCKS_MADE_TMP=0;
BLOCKS_REJECTED_TMP=0;
FLATLINERS=0;
FLATLINERSCOUNTER=0;
TRY=0;

## Main process ##
#      v1.1      #
#    12/2019     #
##################
while :
do
        INIT_JSTATS;
        EXPLORER_CHECK;
        POOLTOOL;
        if [ $lastBlockHeight -eq $FLATLINERS ];
        then
            let FLATLINERSCOUNTER+=1;
            let TRY+=1;
        else 
            FLATLINERS="$lastBlockHeight";
            FLATLINERSCOUNTER=0;
        fi 
        if ([ $RESU -gt 0 ] && [[ $PoolToolHeight != $lastBlockHeight || $PoolToolHeight == "000000" ]] && [[ "$lastBlockHeight" -lt $(($PoolT_max - $Block_delay)) ]]) || [ "$lastBlockHeight" -lt $(($PoolT_max - $Block_diff)) ] || [ "$FLATLINERSCOUNTER" -gt "$FLATCYCLES" ];
        then
                       echo "--> Evaluating Recovery Restart ";
                        until [  $TRY -gt $RECOVERY_CYCLES ]; do
                        LAST_HASH=$(CLI node stats get | grep lastBlockHash | cut -d ":" -f 2| cut -d " " -f 2);
                        EXPLORER_CHECK;
                        POOLTOOL;
                                if ([ $RESU -gt 0 ] && [[ $PoolToolHeight != $lastBlockHeight || $PoolToolHeight == "000000" ]] && [[ "$lastBlockHeight" -lt $(($PoolT_max - $Block_delay)) ]]) || [ "$lastBlockHeight" -lt $(($PoolT_max - $Block_diff)) ] || [ "$FLATLINERSCOUNTER" -gt "$FLATCYCLES" ];
                                then
                                        let TRY+=1;
                                        INIT_JSTATS;
                                        POOLTOOL;
                                        PRINT_SCREEN;
                                        echo -e "Attempt number: $RED$TRY$NC/$ORANGE$RECOVERY_CYCLES$NC before recovery restart.";
                                        if [ "$TRY" -eq "$RECOVERY_CYCLES" ] || [ "$FLATLINERSCOUNTER" -gt $FLATCYCLES ];then
                                            echo -e "$RED--> Attempt number $RECOVERY_CYCLES reached \\n --> Recovering...$NC";
                                            RECOVERY_RESTART;
                                        sleep 180;
                                        fi
                                        
                                        #YOUR pager
                                        if [ "$TRY" -gt "$ALERT_MINIMUM" ] || [ "$FLATLINERSCOUNTER" -gt "$FLATCYCLES" ];
                                        then
                                            PAGER;
                                        fi

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
                EVAL_PAGE_BLOCK;
                sleep $FREQ;
        fi
done
