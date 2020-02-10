#!/bin/bash

# WARNING:
# - If you're not sure what the script does, please do not use it directly on the network. Incorrect implementation may cause you to create an adversarial fork and (correctly) report you accordingly on some community sites

# DISCLAIMER:
# - The script works for a specific 2-node scenario. It is expected that you customise this to your environment and usage (in spite of 'Do not modify' section for basic users).
# - While the actual script is pretty basic in nature, It is assumed that someone using this method is well equipped and qualifies as per the skills and requirements expected of a stakepool operator in the URL below:
#      https://testnet.iohkdev.io/en/cardano/shelley/about/skills-and-requirements/
# - The most important outcome is to prevent having multiple nodes exhibiting same key at a time, except for epoch transition. 
# - We are learning and testing the script (so far the results have been satisfying), please do feel free to add any feedbacks/suggestions to github repo itself
# - Do not expect any tech support from IOHK Help Desk/official support mediums on the script, it is made by the community - for the community

# How nodes are started?
# - The case below expects that the two leaders are started with their keys during boot up time.
# - Example script that can be created to deploy to systemd (1 for each node):
#   cat ~/jormu/scripts/itn1.sh
#     #!/bin/bash
#     while true; do
#         jormungandr --config itn1.yaml --genesis-block-hash $(cat ~/jormu/files/ genesis.hash) --secret ~/jormu/priv/pool-secret.yaml > ~/jormu/logs/node1.log 2>&1
#     done
# - Example systemd script that can be created to run as service (1 for each node):
#   cat /etc/systemd/system/itn1.service
#     [Unit]
#     Description=Jormungandr ITN Service
#     After=network.target
#     
#     [Service]
#     User=username
#     Group=username
#     Type=simple
#     Restart=on-failure
#     ExecStart=/bin/bash -l -c 'exec /home/username/jormu/scripts/itn1.sh 2>&1'
#     WorkingDirectory=/home/username/jormu/scripts
#     LimitNOFILE=350000
#     [Install]
#     WantedBy=multi-user.target

tput reset
shopt -s expand_aliases

##########################
# Variables to modify
##########################
jkey=~/jormu/priv/pool-secret.yaml
## Parameters for reporting tip to pooltool
POOL_ID=$(grep node_id $jkey |awk '{print $2}') # assumes you use the YAML2 (default) format for your node keys
POOLTOOL_UID_FILE=~/jormu/priv/pooltool.uid # Grab this by login to https://pooltool.io/profile
platformName="jormungandr-leaders-failover.sh"
GENESIS="8e4d2a343f3dcf9330ad9035b3e8d168e6728904262f2c434a4f8f934ec7b676"
J1_URL=http://127.0.0.1:4100/api ## Assumes two nodes operating on same host on different ports, change to method as desired
J2_URL=http://127.0.0.1:4101/api ## It is *NOT* recommended to publish your API endpoint to non trusted client connections

##########################
# Do not modify below
##########################
# Function to set/swap Leader URL vars
setURLvars() {
  J1_URL=$1
  J2_URL=$2
}

# Collect chain settings
jsettingsf="/tmp/.jormu_settings.delme"
jcli rest v0 settings get --output-format json -h $J1_URL > $jsettingsf
rc=$?
if [ $rc -ne 0 ]; then
  setURLvars $J2_URL $J1_URL
  jcli rest v0 settings get --output-format json -h $J1_URL > $jsettingsf
  if [ $rc -ne 0 ]; then
    echo "Atleast one of the nodes needs to be up and responding before starting this script!"
    exit 1
  fi
fi
slotDuration=$(cat $jsettingsf | jq -r .slotDuration)
slotsPerEpoch=$(cat $jsettingsf | jq -r .slotsPerEpoch)
jormVersion=$(jcli rest v0 node stats get --output-format json -h $J1_URL | jq -r .version)
rm -f /tmp/.jormu_settings.delme
i=0
timeout=30 # Number of slots to test before taking action on node that's behind. On ITN, value of 30 for $timeout means 60 seconds
j=1
while (test "$i" -le $timeout )
do
  lBH1=$(jcli rest v0 node stats get --output-format json -h $J1_URL | jq -r .lastBlockHeight)
  lBH2=$(jcli rest v0 node stats get --output-format json -h $J2_URL | jq -r .lastBlockHeight)
  #currslot=$(echo $((($(date +%s)-1576264417)/$slotsPerEpoch/$slotDuration)).$(((($(date +%s)-1576264417)%($slotsPerEpoch*$slotDuration))/$slotDuration)) | cut -d . -f 2)
  currslot=$(( (($(date +%s)-1576264417)%($slotsPerEpoch*$slotDuration))/$slotDuration ))
  diffepochend=$(expr $slotsPerEpoch - $currslot)
  if [ -z "${lBH1}" ] || [ "${lBH1}" == "null" ] ;then
    # RISK: If node stats endpoint was hung , eg: when using an untested release, this could mean you end up loading keys to both nodes!
    # Expect delete calls to fail, and hence send output of those delete calls to /dev/null, but calls are present to ensure we dont have condition with double load for leaders.
    echo -e "$(date +%D-%T) - $J1 is unavailable, Attempting to load keys to $J2..."
    jcli rest v0 leaders delete 1 -h $J2_URL 2>&1 >/dev/null
    jcli rest v0 leaders post -f $jkey -h $J2_URL 2>&1 >/dev/null
    jcli rest v0 leaders delete 1 -h $J1_URL 2>&1 >/dev/null
    setURLvars $J2_URL $J1_URL
    echo -e "$(date +%D-%T) - Node Down, Failover not possible: $i $lBH1 $lBH2 - $diffepochend $J1_URL $J2_URL"
  elif [ -z "${lBH2}" ] || [ "${lBH2}" == "null" ]; then
    sleep $(($slotDuration+1))
    echo -e "$(date +%D-%T) - Node Down, Failover not possible: $i $lBH1 $lBH2 - $diffepochend $J1_URL $J2_URL"
  else
    hdiff=$(( $lBH2 - $lBH1 ))
    lBD=$(jcli rest v0 node stats get --output-format json -h $J1_URL | jq -r .lastBlockDate)
    # The echo command below is only for troubleshooting while initially setting up, take it out
    echo -en "\r$(date +%d/%m-%T) - $lBH1 $hdiff $diffepochend $(echo $J1_URL |cut -d/ -f3|cut -d: -f2) $lBD"
    if [ $diffepochend -lt $(($slotDuration+1)) ]; then # Note: Adds a remote (2/43200) probability of creating an adversarial fork if assigned a leadership slot right at the epoch transition
      echo -e "$(date +%D-%T) - Adding keys to both nodes for epoch transition"
      # Based on this script J1 is active and will always have the leader key, so add to J2
      jcli rest v0 leaders post -f $jkey -h $J2_URL > /dev/null
      sleep $(($slotDuration+1))
      J2LEADSLOTCNT=0
      # Wait in a loop until we see the leader logs fulfilled before doing a delete
      while(test "$J2LEADSLOTCNT" -eq 0)
      do
        sleep 1
        J2LEADSLOTCNT=$(jcli rest v0 leaders logs get -h $J2_URL | grep "wake_at_time: ~"  | wc -l)
      done
      jcli rest v0 leaders delete 1 -h $J2_URL > /dev/null
    fi
    # Change if appropriate to your case: The extract below assumes your leaders will only have 1 key, and that leader ID 1(referred later for delete) points to the pool used for failover
    # Ensure J1 only has 1 leader ID, delete others
    loopchk=1
    while [ "$loopchk" -eq 1 ]; do
      J1LEADCNT=$(jcli rest v0 leaders get -h $J1_URL | tail -1 | awk '{print $2}')
      loopchk=0
      if [ ! -z "$J1LEADCNT" ]; then
        if [ $J1LEADCNT -gt 1 ]; then
          jcli rest v0 leaders delete $J1LEADCNT -h $J1_URL > /dev/null
          loopchk=1
        fi
      else
        jcli rest v0 leaders post -f $jkey -h $J1_URL > /dev/null
      fi
    done

    # As per this script only J1 should be a leader, if J2 has leader keys, delete them
    loopchk=1
    while [ "$loopchk" -eq 1 ]; do
      J2LEADCNT=$(jcli rest v0 leaders get -h $J2_URL | tail -1 | awk '{print $2}')
      if [ ! -z "$J2LEADCNT" ]; then
        jcli rest v0 leaders delete 1 -h $J2_URL > /dev/null
      else
        loopchk=0
      fi
    done
    sleep $(($slotDuration/2))
    if [ "$hdiff" -gt 0 ]; then
      echo -e "\n$(date +%D-%T) - J1 found to be behind J2 $((i++ + 1)) times"
      if [ "$i" -ge 2 ]; then # if J2 is ahead for consecutive 1.5 slots, swap leadership for 2nd slot
        echo -e "$(date +%D-%T) - Swapping keys..."
        jcli rest v0 leaders post -f $jkey -h $J2_URL > /dev/null
        jcli rest v0 leaders delete 1 -h $J1_URL > /dev/null
		setURLvars $J2_URL $J1_URL
		i=0
      fi
    elif [ "$hdiff" -lt -5 ]; then
      echo -e "\n$(date +%D-%T) - J2 found to be behind J1 $((i++ + 1)) times"
      if [ "$i" -ge $timeout ]; then
        # Restarting the node is not a good solution for the network, and if used - should only be a temporary remidiation. Starting from 0.8.6, the node is able to catch up fine without restart
        #jcli rest v0 shutdown get -h $J2_URL
        echo -e "$(date +%D-%T) - J2 has been stuck; Resetting due to timeout..\n" >> /tmp/killjormu.log >&2
        i=0
      fi
    else
      i=0
    fi
  fi
  if [ $(( j++ + 1)) -gt 15 ]; then
    curl -s -G --data-urlencode "platform=$platformName" --data-urlencode "jormver=$jormVersion" "https://api.pooltool.io/v0/sharemytip?poolid=${POOL_ID}&userid=$(cat $POOLTOOL_UID_FILE)&genesispref=${GENESIS}&mytip=${lBH1}" > /dev/null
	j=1
  fi
  sleep $(($slotDuration/2))
done
