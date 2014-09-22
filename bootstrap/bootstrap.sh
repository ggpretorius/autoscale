#!/bin/bash

##################################################################################################################
# Seup script
# Author: Gerhard Pretorius
# Version: 0.1    Released: 31 May 2014
#
# Runs the setup on bootup
# Must be run as root
#
# For this to work, the following must be in /etc/rc/rc.local:
# -----------------------------------------------------------------------
# #bootstrap tasks
# yum --assumeyes install git
# rm -rf /root/autoscale
# git clone https://github.com/ggpretorius/autoscale /root/autoscale
# /root/autoscale/bootstrap/bootstrap.sh 2>&1 > /var/log/bootstrap.log
# -----------------------------------------------------------------------
#
# Requires:
# 1) rackspace-monitoring-agent must be installed
# 2) raxmon must be installed
# 3) raxmon credentials must be present in /root/.raxrc:
#    [credentials]
#    username=<RAX Cloud username>
#    api_key=<RAX Cloud API Key>
#
# TODO:
# 1) Log output to a file
##################################################################################################################

DATE=$(/bin/date +%F_%T)

#Set up CPU monitoring
#/root/autoscale/bootstrap/monitoring-setup.sh --notification-plan-id npUO0xEcYG  2>&1 > /var/log/monitoring-setup.log

#Set up CPU monitoring using Server Side Configuration
/root/autoscale/bootstrap/monitoring-setup-server-side.sh --notification-plan-label plan-email-and-webhook-as-web-hkg

#The rest of your bootstrap process goes here
