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
  --notification-plan-label NOTIFICATION_PLAN_LABEL   The label of the RAX Cloud Webhook Notification Plan configured with the Autoscale scale up and scale down webhooks
EOF
}


#Log the date
DATE=$(/bin/date +%F_%T)
echo $DATE

#Notification Plan you will use 
NOTIFY_PLAN_LABEL="<NOTIFICATION_PLAN_LABEL>"
#NOTIFY_PLAN_LABEL="npUO0xEcYG"

#Command line options parsing
case "$#" in
    0 )
    echo "Notification Plan Label not specified as option"
    ;;

    1 )
    echo "Too few arguments"
    print_usage
    exit 1
    ;;

    2 )
    case $1 in
        --notification-plan-label )
        NOTIFY_PLAN_LABEL=$2
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


#Get the notification plan ID from the notification plan name
NOTIFY_PLAN_ID=$(raxmon-notification-plans-list --details | grep ${NOTIFY_PLAN_LABEL} --before-context=1 | grep id | awk -F "'" '{print($4); }')

echo "NOTIFY_PLAN_ID" $NOTIFY_PLAN_ID

#NOTIFY_PLAN_ID="DF4e4536Gg"

#Validate that the supplied notification ID matches the regex [a-zA-Z0-9]{10}
if [ $(echo "$NOTIFY_PLAN_ID" | grep -xE "^[a-zA-Z0-9]{10}$") ]
then
    echo "Notification Plan ID set to : "$NOTIFY_PLAN_ID
else
    echo "FAILURE: Not a valid Notification Plan ID, exiting!! : $NOTIFY_PLAN_ID"
    exit 1
fi

if [ ! -d /etc/rackspace-monitoring-agent.conf.d/ ]
then
   mkdir /etc/rackspace-monitoring-agent.conf.d/
fi

#if [! -f /etc/rackspace-monitoring-agent.conf.d/cpu_check.yaml ]
#then
    \cp /root/autoscale/bootstrap/cpu_check.yaml /etc/rackspace-monitoring-agent.conf.d/
#else
    #/etc/rackspace-monitoring-agent.conf.d/cpu_check.yaml already exists, so exit
#fi

#Update server-side config with the notification plan ID
sed -i s/\<NOTIFY_PLAN_ID\>/$NOTIFY_PLAN_ID/g /etc/rackspace-monitoring-agent.conf.d/cpu_check.yaml

#Sleep for a while before restarting the monitoring agent
sleep 30
service rackspace-monitoring-agent restart

#Server-side monitoring will now create the monitors for us!

