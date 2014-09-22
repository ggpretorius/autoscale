#!/bin/bash
##################################################################################################################
# Rackspace Cloud Monitoring Setup and simple bootstrap process using /etc/rc.d/rc.local
# Author: Gerhard Pretorius
# Version: 0.1
# Released: 21 July 2014
#
# Must be run as root
#
# This script will:
# 1) Install the Rackspace Cloud Monitoring agent:
#    www.rackspace.com/knowledge_center/article/install-the-cloud-monitoring-agent
#
# 2) Install raxmon - The Rackspace Cloud Monitoring CLI tool:
#    www.rackspace.com/knowledge_center/article/getting-started-with-rackspace-monitoring-cli
#
# 3) Set up a very simple server bootstrap configuration process using /etc/rc.d/rc.local
#    This will add the ability to define actions that will be performed at bootup in a script located at /root/autoscale/bootstrap/bootstrap.sh
#
# An example bootstrap.sh file is provided that sets up a CPU check using Rackspace Cloud Monitoring
# 
###################################################################################################################

RAX_USERNAME="<RAX_USERNAME>"
RAX_API_KEY="<RAX_API_KEY>"


#INSTALL MONITORING AGENT:
curl https://monitoring.api.rackspacecloud.com/pki/agent/centos-6.asc > /tmp/signing-key.asc
sudo rpm --import /tmp/signing-key.asc
cat << EOF > /etc/yum.repos.d/rackspace-cloud-monitoring.repo
[rackspace]
name=Rackspace Monitoring
baseurl=http://stable.packages.cloudmonitoring.rackspace.com/centos-6-x86_64
enabled=1
EOF

sudo yum --assumeyes install rackspace-monitoring-agent
rackspace-monitoring-agent --setup --username $RAX_USERNAME --apikey $RAX_API_KEY
service rackspace-monitoring-agent start
chkconfig rackspace-monitoring-agent on

#Install Rackspace-Monitoring CLI tool:
sudo pip install rackspace-monitoring-cli
cat << EOF > ~/.raxrc
[credentials]
username=$RAX_USERNAME
api_key=$RAX_API_KEY
EOF

raxmon-entities-list

cat << EOF >> /etc/rc.d/rc.local


#bootstrap tasks
yum --assumeyes install git
rm -rf /root/autoscale
git clone https://github.com/ggpretorius/autoscale /root/autoscale
/root/autoscale/bootstrap/bootstrap.sh 2>&1 > /var/log/bootstrap.log
EOF

