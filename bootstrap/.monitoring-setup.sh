#!/bin/bash

##################################################################################################################
# Rackspace Cloud CPU monitor setup
# Author: Jakub Krajcovic
# Modified by: Gerhard Pretorius
# Version: 0.2    Released: 31 May 2014
#
# This script will:
# 1) Start RAX Cloud monitoring agent and chkconfig it on so it will start automatically on next boot
# 2) Check if CPU check and CPU Usage alert exists for the current host, and create them if they do not exist
#
# Must be run as root
#
# Requires:
# 1) rackspace-monitoring-agent must be installed
# 2) raxmon must be installed
# 3) raxmon credentials must be present in /root/.raxrc:
#    [credentials]
#    username=<RAX Cloud username>
#    api_key=<RAX Cloud API Key>
# 4) A Rackspace Cloud Monitoring Notification Plan for the CPU monitoring to use
#    You can use ../autoscale/raxmon-setup.sh to set this up
#    NOTIFY_PLAN_ID should be set to the ID of the Notification Plan you created. You can also set it using the command line option --notification-plan-id
#    More on Notification Plans: http://www.rackspace.com/knowledge_center/article/getting-started-with-rackspace-monitoring-cli
#
# TODO:
# 1) Log output to a file
# 2) See if we can get rid of having to statically define NOTIFY_PLAN_ID, by looking at the current notification plans. At least so we can reference it by name and not ID.
# 3) Install rackspace-monitoring-agent and raxmon if they dont exist
##################################################################################################################

#Function to print command line usage
function print_usage () {
   cat <<EOF
Usage: $0 [OPTIONS]
  --notification-plan-id NOTIFICATION_PLAN_ID   The ID of the RAX Cloud Webhook Notification Plan configured with the Autoscale scale up and scale down webhooks
EOF
}


#Log the date
DATE=$(/bin/date +%F_%T)
echo $DATE

#Notification Plan you will use 
NOTIFY_PLAN_ID="<NOTIFICATION_PLAN_ID>"
NOTIFY_PLAN_ID="npUO0xEcYG"

#Command line options parsing
case "$#" in
    0 )
    echo "Notification Plan ID not specified as option"
    ;;

    1 )
    echo "Too few arguments"
    print_usage
    exit 1
    ;;

    2 )
    case $1 in
        --notification-plan-id )
        #Playing with the idea for sed to update NOTIFY_PLAN_ID in this file, but I dont think that is the best solution.
        #sed -i 's/NOTIFY_PLAN_ID="<NOTIFICATION_PAN_ID>"/NOTIFY_PLAN_ID='"$2/" ./monitoring-setup.sh
        NOTIFY_PLAN_ID=$2
        ;;

        * )
        print_usage
        exit 1
    esac
    ;;

    * )
    echo "Too many arguments"
    print_usage
    exit 1
esac

#NOTIFY_PLAN_ID="DF4e4536Gg"

#Validate that the supplied notification ID matches the regex [a-zA-Z0-9]{10}
if [ $(echo "$NOTIFY_PLAN_ID" | grep -xE "^[a-zA-Z0-9]{10}$") ]
then
    echo "Notification Plan ID set to : "$NOTIFY_PLAN_ID
else
    echo "FAILURE: Not a valid Notification Plan ID, exiting!! : $NOTIFY_PLAN_ID"
    exit 1
fi

#Start rackspace-monitoring-agent if it's not running, and chkconfig it on:
if [ -z $(pidof rackspace-monitoring-agent) ]
then
    service rackspace-monitoring-agent start
    chkconfig rackspace-monitoring-agent on
fi

#print the Entity command to check its output, this is for debugging:
raxmon-entities-list

#Get the hostname
MONITOR_HOST=$(hostname)
#This is to test on another host
#MONITOR_HOST="as-web-iad-asae9616ef"

#For some reason the first call always returns null, so we are checking 5 times with a 10 sec sleep between checks
for i in {1..5}
do
    #Get the current hosts entity-id
    ENTITY=$(raxmon-entities-list | grep label=${MONITOR_HOST} | awk -F "=" '{print($2); }' | awk '{print($1); }')    

    #Get the length of ENTITY (not actually used in validation, just here for debugging)
    #CHECK_LENGTH=${#ENTITY}
    #echo "CHECK_LENGTH :" $CHECK_LENGTH

    #Validate that ENTITY matches the regex [a-zA-Z0-9]{10}
    #if [[ $ENTITY =~ [a-z][A-Z][0-9]{10} ]] <-- originally this is how I did it, but it's bash only so might not work on other distros
    if [ $(echo "$ENTITY" | grep -xE "^[a-zA-Z0-9]{10}$") ]
    then
        echo "Entity found : "$ENTITY
        break
    else
        echo "FAILURE : Problem with extracting ENTITY-ID, checking again : "$ENTITY
        sleep 10
    fi
done

#If after 5 tries we still dont have the entity, exit with an error
if ! [ $(echo "$ENTITY" | grep -xE "^[a-zA-Z0-9]{10}$") ]
then
    echo "FAILURE : Problem DOH with extracting ENTITY-ID, exiting!! : "$ENTITY
    exit 1
fi

#Confirm if a CPU check already exists
echo "Verifying if CPU check exists..."
CHECK=$(raxmon-checks-list --entity-id=${ENTITY} | grep -E "CPU" | awk -F " " '{print($2); }' | awk -F "=" '{print($2); }')
if [ $(echo "$CHECK" | grep -xE "^[a-zA-Z0-9]{10}$") ]
then
    #CHECK=$(echo ${CHECK} | awk -F " " '{print($2); }' | awk -F "=" '{print($2); }')
    echo "CPU check already exists : "$CHECK
    echo "Verifying if CPU Usage alarm exists..."
    ALARM=$(raxmon-alarms-list --entity-id=${ENTITY} | grep -E "CPU Usage" | awk -F " " '{print($2); }' | awk -F "=" '{print($2); }' | awk -F "," '{print($1); }')
    echo "ALARM: "$ALARM
    if [ $(echo "$ALARM" | grep -xE "^[a-zA-Z0-9]{10}$") ]
    then
        #ALARM=$(echo ${ALARM} | awk -F " " '{print($2); }' | awk -F "=" '{print($2); }')
        echo "CPU Usage alarm already exists, we are done : "$ALARM
        exit 0
    else
        echo "CPU Usage alarm does not exist"
    fi
else
    #Neither the check or alarm exisits, create check, alarm will be created below
    echo "CPU check does not exist"
    echo "Creating CPU check..."
    #exit 0
    CHECK=$(raxmon-checks-create --entity-id=${ENTITY} --label=CPU --type agent.cpu --timeout=15 --period=30 --details "CPU Usage Monitor" | awk -F " " '{print($4); }')
    #Validate that CHECK matches the regex [a-zA-Z0-9]{10}
    if [ $(echo "$CHECK" | grep -xE "^[a-zA-Z0-9]{10}$") ]
    then
        echo "CPU check created : "$CHECK
    else
        echo "FAILURE: Problem with creating/extracting CHECK-ID, exiting!! CHECK-ID: " $CHECK
    fi
fi

#Validate that CHECK matches the regex [a-zA-Z0-9]{10}
if [ $(echo "$CHECK" | grep -xE "^[a-zA-Z0-9]{10}$") ]
then
    echo "Creating CPU Usage alarm..."
    raxmon-alarms-create --entity-id=${ENTITY} --label="CPU Usage" --check-id=${CHECK} --notification-plan-id=${NOTIFY_PLAN_ID} --metadata="template_name=agent.cpu_usage_average" --criteria="if (metric['usage_average'] > 95) {return new AlarmStatus(CRITICAL, 'CPU usage is #{usage_average}%, above your critical threshold of 95%');} if (metric['usage_average'] > 90) {return new AlarmStatus(WARNING, 'CPU usage is #{usage_average}%, above your warning threshold of 90%');} return new AlarmStatus(OK, 'CPU usage is #{usage_average}%, below your warning threshold of 90%');"
else
    echo "FAILURE: Problem with extracting CHECK-ID, exiting!! CHECK-ID: " $CHECK
fi
