#!/bin/bash

# DISCLAIMER:
# - This script is not supposed to work out of the box , due to variance of how operators will create their environment and design their failover setup. It is expected that you customise this to your environment and usage.
# - While the actual script is pretty basic in nature, It is assumed that someone using this method is well equipped and qualifies as per the skills and requirements expected of a stakepool operator in the URL below:
#      https://testnet.iohkdev.io/en/cardano/shelley/about/skills-and-requirements/
# - The most important outcome is to prevent having multiple nodes exhibiting same key at a time, except for epoch transition. 
# - We are learning and testing the script (so far the results have been satisfying), please do feel free to add any feedbacks/suggestions to github repo itself
# - Do not expect any tech support from IOHK Help Desk/official support mediums on the script, it is made by the community - for the community
# - The case below expects that the two leaders are started with their keys during boot up time

shopt -s expand_aliases

jkey=/opt/jormungandr/priv/pool-secret.yaml

# Assume two nodes operating on same node on different ports, change to method as desired to get/post settings, node stats and leader interaction with your nodes
# It is *NOT* recommended to publish your API endpoint to non trusted client connections
J1_URL=http://127.0.0.1:4100/api
J2_URL=http://127.0.0.1:4101/api

slotDuration=$(jcli rest v0 settings get --output-format json -h $J1_URL | jq -r .slotDuration)
slotsPerEpoch=$(jcli rest v0 settings get --output-format json -h $J1_URL | jq -r .slotsPerEpoch)
i=0
timeout=10 # Number of slots to test before testing. On ITN, value of 10 for $timeout means 20 seconds

while (test "$i" -le $timeout )
do
  lBH1=$(jcli rest v0 node stats get --output-format json -h $J1_URL | jq -r .lastBlockHeight)
  lBH2=$(jcli rest v0 node stats get --output-format json -h $J2_URL | jq -r .lastBlockHeight)
  #currslot=$(echo $((($(date +%s)-1576264417)/$slotsPerEpoch/$slotDuration)).$(((($(date +%s)-1576264417)%($slotsPerEpoch*$slotDuration))/$slotDuration)) | cut -d . -f 2)
  currslot=$((((($(date +%s)-1576264417)/$slotDuration)%($slotsPerEpoch*$slotDuration))/$slotDuration))
  diffepochend=$(expr $slotsPerEpoch - $currslot)
  # The echo command below iss only for troubleshooting while initially setting up, take it out
  echo $i $lBH1 $lBH2 $diffepochend
  if [ $diffepochend -lt $(($slotDuration+1)) ]; then # Adds a small probability of losing very rare leadership task if assigned for last slot of the epoch, or first block of next epoch
    echo "Adding keys to both nodes for epoch transition:"
    # Based on this script J1 is active and will always have the leader key
    jcli rest v0 leaders post -f $jkey -h $J2_URL
    sleep $(($slotDuration+1))
    jcli rest v0 leaders delete 1 -h $J2_URL    
  fi
  if [ -z "${lBH1}" ] || [ -z "${lBH2}" ] || [ "${lBH1}" == "null" ] || [ "${lBH2}" == "null" ] ;then
    echo "One of the node is down; failover not possible"
  else
    # Change if appropriate to your case: The extract below assumes your leaders will only have 1 key, and that leader ID 1(referred later for delete) points to the pool used for failover
    # Ensure J1 only has 1 leader ID, delete others
    loopchk=1
    while [ "$loopchk" -eq 1 ]; do
      J1LEADCNT=$(jcli rest v0 leaders get -h $J1_URL | tail -1 | awk '{print $2}')
      if [ ! -z "$J1LEADCNT" ]; then
        if [ "$J1LEADCNT" -gt 1 ]; then
          jcli rest v0 leaders delete $J1LEADCNT -h $J1_URL
        else
         loopchk=0
        fi
      else
        loopchk=0
      fi
    done

    # As per this script only J1 should be a leader, if J2 has leader keys, delete them
    loopchk=1
    while [ "$loopchk" -eq 1 ]; do
      J2LEADCNT=$(jcli rest v0 leaders get -h $J2_URL | tail -1 | awk '{print $2}')
      if [ ! -z "$J2LEADCNT" ]; then
        jcli rest v0 leaders delete 1 -h $J2_URL
      else
        loopchk=0
      fi
    done
    sleep $(($slotDuration/2))
    if [ "$lBH1" -lt "$lBH2" ]; then
      echo "J1 found to be behind J2 $((i++)) times"
      if [ "$i" -ge $timeout ]; then
        echo "Timeout reached; Swapping keys..."
        jcli rest v0 leaders post -f $jkey -h $J2_URL
        jcli rest v0 leaders delete 1 -h $J1_URL
        TMPURL=$J1_URL
        J1_URL=$J2_URL
        J2_URL=$TMPURL
        # If you'd like to kill your jormungandr J2 (previously J1) session because its out of sync (for example you may have configured auto restart *OUT OF THIS SCRIPT* - to start node back up when killed/shutdown/panic), uncomment below
        # (PS: Its not always good to stay in restart loop, how an operator would like to tackle a case where node restarts multiple times - would be up to them)
        #jcli rest v0 shutdown get -h $J2_URL
        i=0
      fi
    else
      i=0
    fi
  fi
  sleep $(($slotDuration/2))
done

