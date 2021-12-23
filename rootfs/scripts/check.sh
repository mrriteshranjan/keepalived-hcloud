#!/bin/bash
###############################################################################
# Keepalived check script for Hetzner HCloud Floating-IPs
# Usage: check.sh <vrrp_instance_name> <floating-ip>
#
# 1. Checks ENABLED state of "enabled" file. Must be 1 to succeed
# 2. Checks if given Floating-IP is assigned to this node when STATE=MASTER
#    STATE must be set using set-state.sh notify script
###############################################################################

set -e -o pipefail

NAME=$1
FLOATING_IP=$2

function reportOK() {
  exit 0
}
function reportFAULT() {
  echo "Check $NAME with $FLOATING_IP = FAULT: $1"| tee -a /tmp/keepalived_notify.log
  exit 1
}

[ -z "$NAME" ] && reportFAULT "NAME Parameter is empty"
[ -z "$FLOATING_IP" ] && reportFAULT "FLOATING_IP Parameter is empty"
[ -z "$HCLOUD_TOKEN" ] && reportFAULT "HCLOUD_TOKEN env-var is empty"

# Check "enabled"
source /etc/keepalived/enabled
[ "$ENABLED" != "1" ] && reportFAULT "keepalived is disabled by file-flag"

# Check Floating-IP assignment

# No state known
[ ! -e /tmp/keepalive_state_${NAME} ] && reportOK

STATE=$(cat /tmp/keepalive_state_${NAME})

# State is not master, no need to check floating-ip assignment
[ "$STATE" != "MASTER" ] && reportOK


FLOATING_IP_ID=$(curl -f -sSL -H "Authorization: Bearer ${HCLOUD_TOKEN}" "https://api.hetzner.cloud/v1/floating_ips" | jq ".floating_ips[] | select(.ip == \"${FLOATING_IP}\") | .id")

ASSIGNED_IP_IDs=$(curl -f -sSL -H "Authorization: Bearer ${HCLOUD_TOKEN}" "https://api.hetzner.cloud/v1/servers?name=${HOSTNAME}" | jq -r  '.servers[0].public_net.floating_ips | @sh')

# Check if Floating-IP ID is assigned to this server
for F_ID in $ASSIGNED_IP_IDs ; do
  [ "$FLOATING_IP_ID" -eq "$F_ID" ] && reportOK
done

reportFAULT "Floating-IP not assigned to this node"
