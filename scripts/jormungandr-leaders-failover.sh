#!/bin/bash

# DISCLAIMER:
# - This script is not supposed to work out of the box , due to variance of how operators will create their environment and design their failover setup. It is expected that you customise this to your environment and usage.
# - While the actual script is pretty basic in nature, It is assumed that someone using this method is well equipped and qualifies as per the skills and requirements expected of a stakepool operator in the URL below:
#      https://testnet.iohkdev.io/en/cardano/shelley/about/skills-and-requirements/
# - The most important outcome is to prevent having multiple nodes exhibiting same key at a time, except for epoch transition. 
# - We are learning and testing the script (so far the results have been satisfying), please do feel free to add any feedbacks/suggestions to github repo itself
# - Do not expect any tech support from IOHK Help Desk/official support mediums on the script, it is made by the community - for the community

shopt -s expand_aliases

jkey=/opt/jormungandr/priv/pool-secret.yaml

# Assume two nodes operating on same node on different ports, change to method as desired to get/post settings, node stats and leader interaction with your nodes
# It is *NOT* recommended to publish your API endpoint to non trusted client connections
J1_URL=http://127.0.0.1:4100/api
J2_URL=http://127.0.0.1:4101/api

slotDuration=$(jcli rest v0 settings get --output-format json -h $J1_URL | jq -r .slotDuration)
slotsPerEpoch=$(jcli rest v0 settings get --output-format json -h $J1_URL | jq -r .slotsPerEpoch)
i=0
timeout=10

while (test "$i" -lt $timeout )
do
  lBH1=$(jcli rest v0 node stats get --output-format json -h $J1_URL | jq -r .lastBlockHeight)
  lBH2=$(jcli rest v0 node stats get --output-format json -h $J2_URL | jq -r .lastBlockHeight)
  currslot=$(echo $((($(date +%s)-1576264417)/86400)).$(((($(date +%s)-1576264417)%86400)/$slotDuration)) | cut -d . -f 2)
  diffepochend=$(expr $slotsPerEpoch - $currslot)
  if [ $diffepochend -lt 3 ]; then
    echo "Adding keys to both nodes for epoch transition:"
    # Risk of overrunning if bad latency to API
    # Based on this script J1 is active and will always have the leader key
    jcli rest v0 leaders post -f $jkey -h $J2_URL
    sleep 5
    jcli rest v0 leaders delete 1 -h $J2_URL    
  fi
  sleep $slotDuration
  echo $i $lBH1 $lBH2 $lBD $diffepochend
  if [ -z "${lBH1}" ] || [ -z "${lBH2}" ] || [ "${lBH1}" == "null" ] || [ "${lBH2}" == "null" ] ;then
    echo "One of the node is down; failover not possible"
  else
    if [ "$lBH1" -lt "$lBH2" ]; then
      echo "Attempt #: $((i++))"
      if [ "$i" -ge $timeout ]; then
        J2LEADCNT=$(jcli rest v0 leaders get -h $J2_URL)
        if [ "$J2LEADCNT" -gt 0 ]; then
          echo "Swapping keys..."
          jcli rest v0 leaders post -f $jkey -h $J2_URL
          jcli rest v0 leaders delete 1 -h $J1_URL
          TMPURL=$J1_URL
          J1_URL=$J2_URL
          J2_URL=$TMPURL
          #If you'd like to kill your jormungandr J1 session because its out of sync, uncomment below - whether you do a manual analysis or want it to be auto restarted is an env specific query
          #ps -ef | grep [j]ormungandr | awk '{print $2}' | xargs kill -9
        fi
        i=0
      fi
    else
      i=0
    fi
  fi
done

