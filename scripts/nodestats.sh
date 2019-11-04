#!/bin/bash
shopt -s expand_aliases
echo "Content-type: application/json" # Tells the browser what kind of content to expect
echo "" # An empty line. Mandatory, if it is missed the page content will not load
JORMUNGANDR_RESTAPI_URL=http://127.0.0.1:4100/api
alias cli="$(which jcli) rest v0"
# Node stats data
lastBlockDateSlot=$(cli node stats get --output-format json | jq -r .lastBlockDate | cut -f2 -d.)
blockRecvCnt=$(cli node stats get --output-format json | jq -r .blockRecvCnt)
lastBlockHeight=$(cli node stats get --output-format json | jq -r .lastBlockHeight)
uptime=$(cli node stats get --output-format json | jq -r .uptime)
lastBlockTx=$(cli node stats get --output-format json | jq -r .lastBlockTx)
txRecvCnt=$(cli node stats get --output-format json | jq -r .txRecvCnt)
productionInEpoch=$(cli leaders logs get | grep -c "finished_at_time\: \"20")
tmpdt=$(cli leaders logs get | grep finished_at_ | sort | grep -v \~ | tail -1 | awk '{print $2}')
lastBlkCreated=$(cli leaders logs get | grep -A1 $tmpdt | tail -1 |awk '{print $2}' | sed s#\"##g | awk '{print $1 * 1000}')
tmpdt=$(cli leaders logs get | grep -A2 finished_at_time:\ ~ | grep scheduled_at_time | sort | head -1 | awk '{print $2}')
nextBlkSched=$(cli leaders logs get | grep -B1 $tmpdt | head -1 |awk '{print $2}' | sed s#\"##g | awk '{print $1 * 1000}')

# Netstat remote connections
nodesEstablished=$(sudo netstat -anlp | egrep "ESTABLISHED+.*jormungandr" | cut -c 45-68 | cut -d ":" -f 1 | wc -l)
nodesEstablishedUnique=$(sudo netstat -anlp | egrep "ESTABLISHED+.*jormungandr" | cut -c 45-68 | cut -d ":" -f 1 | sort | uniq -c | wc -l)
nodesSynSent=$(sudo netstat -anlp 2>/dev/null | egrep "SYN_SENT+.*jormungandr" | cut -c 45-68 | cut -d ":" -f 1 | sort | uniq | wc -l)

# Note ^^ : if you run Jormungandr as a different user, you can call netstat with 
# echo "your_root_password" | sudo -S netstat ... 


# default NULL values to 0
if [ "$lastBlockDateSlot" == "" ]; then
        lastBlockDateSlot="0"
fi
if [ "$blockRecvCnt" == "" ]; then
        blockRecvCnt="0"
fi
if [ "$lastBlockHeight" == "" ]; then
        lastBlockHeight="0"
fi
if [ "$uptime" == "" ]; then
        uptime="0"
fi
if [ "$lastBlockTx" == "" ]; then
        lastBlockTx="0"
fi
if [ "$txRecvCnt" == "" ]; then
        txRecvCnt="0"
fi
if [ "$productionInEpoch" == "" ]; then
        productionInEpoch="0"
fi
if [ "$lastBlkCreated" == "" ]; then
        lastBlkCreated="0"
fi
if [ "$nextBlkSched" == "" ]; then
        nextBlkSched="0"
fi
if [ "$nodesEstablished" == "" ]; then
        nodesEstablished="0"
fi
if [ "$nodesEstablishedUnique" == "" ]; then
        nodesEstablishedUnique="0"
fi
if [ "$nodesSynSent" == "" ]; then
        nodesSynSent="0"
fi

# return a JSON dataset as required for PRTG Monitoring
echo {\"prtg\": {\"result\": [{\"channel\": \"nodesEstablished\", \"value\": \"${nodesEstablished}\", \"unit\": \"custom\", \"customunit\": \"nodes\" }, {\"channel\": \"nodesEstablishedUnique\", \"value\": \"${nodesEstablishedUnique}\", \"unit\": \"custom\", \"customunit\": \"nodes\" }, {\"channel\": \"nodesSynSent\", \"value\": \"${nodesSynSent}\", \"unit\": \"custom\", \"customunit\": \"nodes\" }, {\"channel\": \"lastBlockDateSlot\", \"value\": \"${lastBlockDateSlot}\", \"unit\": \"custom\", \"customunit\": \"blks\" }, {\"channel\": \"blockRecvCnt\", \"value\": \"${blockRecvCnt}\", \"unit\": \"custom\", \"customunit\": \"blks\" }, {\"channel\": \"lastBlockHeight\", \"value\": \"${lastBlockHeight}\", \"unit\": \"custom\", \"customunit\": \"blks\" }, {\"channel\": \"uptime\", \"value\": \"${uptime}\", \"unit\": \"custom\", \"customunit\": \"sec\" }, {\"channel\": \"lastBlockTx\", \"value\": \"${lastBlockTx}\", \"unit\": \"custom\", \"customunit\": \"tx\" }, {\"channel\": \"txRecvCnt\", \"value\": \"${txRecvCnt}\", \"unit\": \"custom\", \"customunit\": \"tx\" }, {\"channel\": \"productionInEpoch\", \"value\": \"${productionInEpoch}\", \"unit\": \"custom\", \"customunit\": \"blks\" }, {\"channel\": \"lastBlkCreated\", \"value\": \"${lastBlkCreated}\", \"unit\": \"custom\", \"customunit\": \"eblk\" }, {\"channel\": \"nextBlkSched\", \"value\": \"${nextBlkSched}\", \"unit\": \"custom\", \"customunit\": \"eblk\" } ]}} | python -m json.tool

