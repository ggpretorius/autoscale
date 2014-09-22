#!/bin/bash

##################################################################################################################
# Rackspace Cloud CPU monitor setup
# Author: Jakub Krajcovic
# Modified by: Gerhard Pretorius
# Version: 0.1
# Released: 31 May 2014
#
# Rackspace cloud monitoring setup is done in 2 ways:
# We first have to setup some account-wide settings and then we configure checks and alarms per each instance
# The 2 things that are "account-wide" that we need to setup are: notifications and notification plans
#
# The webhook notification plans are intended to be used with Rackspace Cloud Autoscale to trigger scaling based on monitoring events
#
# This script will:
# 1) Create 4 notifications: 
#    - Email   : email general (for OK events), email escalation (for CRITICAL events)
#    - Webhook : webhook scale down (for OK events), webhook scale up (for CRITICAL events)
#
# 2) Create 3 notification plans:
#    - Combined email and webhook so you get an email every time a scaleup or scaledown will occur
#    - Email only
#    - Webhook only
#
#################################################################################################################################

#Function to print command line usage
function print_usage () {
   cat <<EOF
Usage: $0 [OPTIONS]
  --region REGION                          Your RAX Cloud Region (only used for naming the notifications and notification plans)
  --email EMAIL                            Email to use for email notifications
  --webhook_scale_up WEBHOOK_SCALE_UP      Autoscale webhook to scale up
  --webhook_scale_down WEBHOOK_SCALE_DOWN  Autoscale webhook to scale down
EOF
}

#Command line options parsing
if [ "$#" -lt 8 ]
then
    print_usage
    exit 1
fi

while [[ $1 =~ ^-- ]]; do
    case $1 in 
        --region )
	REGION=$2
	shift ;;

        --email )
	EMAIL=$2
        shift ;;

        --webhook_scale_up )
	WEBHOOK_SCALE_UP=$2
	shift ;;

        --webhook_scale_down )
	WEBHOOK_SCALE_DOWN=$2
	shift ;;

        * )
	print_usage
        exit 1
    esac
    shift
done

#Debugging - prints parsed command line arguments
echo "REGION: "$REGION
echo "EMAIL: "$EMAIL
echo "WEBHOOK_SCALE_UP: "$WEBHOOK_SCALE_UP
echo "WEBHOOK_SCALE_DOWN: "$WEBHOOK_SCALE_DOWN

# Since we now use command line arguments this is not used anymore, will remove it at some point once I'm sure
#The RAX Cloud Region your autoscale group is in. This is only to label the notification plans
#REGION="TEST"

#Inputs required for the notifications and notification plans
#EMAIL="test@test.com"
#WEBHOOK_SCALE_UP="https://iad.autoscale.api.rackspacecloud.com/v1.0/execute/1/scaleup/"
#WEBHOOK_SCALE_DOWN="https://iad.autoscale.api.rackspacecloud.com/v1.0/execute/1/scaledown/"

###############
# Notifications
NOTIFY_EMAIL_GENERAL=$(raxmon-notifications-create --label=email-general-${REGION} --type=email --details="address=${EMAIL}" | awk -F " " '{print($4); }')
if [[ $NOTIFY_EMAIL_GENERAL =~ [a-zA-Z0-9]{10} ]]
then
    echo "NOTIFY_EMAIL_GENERAL   : "$NOTIFY_EMAIL_GENERAL
else
    echo "FAILURE: Problem with creating notification, exiting!! NOTIFY_EMAIL_GENERAL: "${NOTIFY_EMAIL_GENERAL}
    exit 1
fi

NOTIFY_EMAIL_ESCALATION=$(raxmon-notifications-create --label=email-escalation${REGION} --type=email --details="address=${EMAIL}" | awk -F " " '{print($4); }')
if [[ $NOTIFY_EMAIL_ESCALATION =~ [a-zA-Z0-9]{10} ]]
then
    echo "NOTIFY_EMAIL_ESCALATION: "$NOTIFY_EMAIL_ESCALATION
else
    echo "FAILURE: Problem with creating notification, exiting!! NOTIFY_EMAIL_ESCALATION: "${NOTIFY_EMAIL_ESCALATION}
    exit 1
fi


NOTIFY_SCALE_UP=$(raxmon-notifications-create --label=webhook-as-web-${REGION}-scale-up --type=webhook --details="url=${WEBHOOK_SCALE_UP}" | awk -F " " '{print($4); }')

if [[ $NOTIFY_SCALE_UP =~ [a-zA-Z0-9]{10} ]]
then
    echo "NOTIFY_SCALE_UP        : "$NOTIFY_SCALE_UP
else
    echo "FAILURE: Problem with creating notification, exiting!! NOTIFY_SCALE_UP: "${NOTIFY_SCALE_UP}
    exit 1
fi


NOTIFY_SCALE_DOWN=$(raxmon-notifications-create --label=webhook-as-web-${REGION}-scale-down --type=webhook --details="url=${WEBHOOK_SCALE_DOWN}" | awk -F " " '{print($4); }')
if [[ $NOTIFY_SCALE_DOWN =~ [a-zA-Z0-9]{10} ]]
then
    echo "NOTIFY_SCALE_DOWN      : "$NOTIFY_SCALE_DOWN
else
    echo "FAILURE: Problem with creating notification, exiting!! NOTIFY_SCALE_DOWN: "${NOTIFY_SCALE_DOWN}
    exit 1
fi


#####################
# Notifications plans

#Create a combined email and webhook notification plan so you get an email every time a scaleup or scaledown will occur:
echo "Creating combined email and webhook notification plan..."
raxmon-notification-plans-create --label=plan-email-and-webhook-as-web-${REGION}  --ok-state=${NOTIFY_EMAIL_GENERAL},$NOTIFY_SCALE_DOWN --critical-state=${NOTIFY_EMAIL_ESCALATION},$NOTIFY_SCALE_UP

echo "Notification plan plan-email-and-webhook-as-web-${REGION} created"

#Create email notification plan
#echo "Creating email notification plan..."
#raxmon-notification-plans-create --label=plan-email-${REGION} --ok-state=${NOTIFY_EMAIL_GENERAL} --critical-state=${NOTIFY_EMAIL_ESCALATION}

#Create webhook notification plan
#echo "Creating webhook notification plan..."
#raxmon-notification-plans-create --label=plan-webhook-as-web-${REGION} --ok-state=${NOTIFY_SCALE_DOWN} --critical-state=${NOTIFY_SCALE_UP}
