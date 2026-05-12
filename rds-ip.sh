#!/usr/bin/env bash 

# Description: AWS PrivateLink IP Helper — resolves the private IP address(es) of an RDS instance's
#              Elastic Network Interface (ENI) using the AWS CLI.
#              When setting up AWS PrivateLink, you need to register the RDS instance's private IP(s)
#              as targets in a Network Load Balancer (NLB) target group. This script automates that discovery step.
# Usage:       ./rds-ip.sh <RDS_INSTANCE_IDENTIFIER> [-q|--quiet]
# Version:     1.2
# Author:      Petro Sydor

# Parse flags
QUIET=false
for arg in "$@"; do
    case "$arg" in
        -q|--quiet) QUIET=true ;;
    esac
done

info() { [ "$QUIET" = false ] && echo "$@"; }

info "┌─────────────────────────────────────────────────────────────────────────────────────────────────┐"
info "│ NOTE: RDS security groups can be shared across multiple RDS instances or other AWS resources.   │"
info "│ The script may return wrong IP addresses if the security group is associated with more than one.│"
info "│ Ensure to verify uniqueness of the security group associated for your specific RDS instance.    │"
info "└─────────────────────────────────────────────────────────────────────────────────────────────────┘"
info ""

#   Check if AWS CLI is installed and configured
if ! command -v aws &>/dev/null; then
    echo "[ERROR] AWS CLI is not installed. Please install it and configure your credentials."
    echo "You can install AWS CLI by following the instructions at: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
    exit 126
fi

# Get AWS Account ID to verify credentials and for informational purposes
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>&1)
if [ $? -ne 0 ]; then
    printf "[ERROR] Couldn't retrieve AWS Account ID: %s\n" "${AWS_ACCOUNT_ID#$'\n'}"
    exit 61
fi
info "[INFO] AWS Account ID: ${AWS_ACCOUNT_ID}"

# Check if RDS instance identifier is provided
RDS_NAME=""
for arg in "$@"; do
    case "$arg" in
        -q|--quiet) ;;
        *) RDS_NAME="$arg" ;;
    esac
done
if [ -z "$RDS_NAME" ]; then
    echo "Usage: $0 <RDS_INSTANCE_IDENTIFIER> [-q|--quiet]"
    exit 61
fi

# Retrieve the security group ID associated with the RDS instance
RDS_SG=$(aws rds describe-db-instances --db-instance-identifier "${RDS_NAME}" --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text 2>&1)
if [ $? -ne 0 ]; then
    printf "[ERROR] %s\n" "${RDS_SG#$'\n'}"
    exit 61
fi
info "[INFO] Found security group '${RDS_SG}' for RDS database '${RDS_NAME}'"

# Assign variables (ENI, VPC, Subnet, and Private IPs) for all interfaces
INTERFACES=$(aws ec2 describe-network-interfaces \
    --filters "Name=group-id,Values=${RDS_SG}" \
    --query 'NetworkInterfaces[*].[NetworkInterfaceId, VpcId, SubnetId, join(` `, PrivateIpAddresses[*].PrivateIpAddress)]' \
    --output text 2>&1)
# Check if the command executed successfully
if [ $? -ne 0 ]; then
    printf "[ERROR] %s\n" "${INTERFACES#$'\n'}"
    exit 61
fi

# Check if any interfaces were found
if [ -z "$INTERFACES" ]; then
    echo "[ERROR] No network interfaces found for security group '${RDS_SG}'"
    exit 61
fi

# Print the VPC ID (assuming all interfaces belong to the same VPC)
DEFAULT_VPC_ID=$(echo "$INTERFACES" | awk 'NR==1{print $2}')
if [ -z "$DEFAULT_VPC_ID" ]; then
    echo "[ERROR] Unable to determine VPC ID from the network interfaces"
    exit 61
fi
info "[INFO] VPC ID: ${DEFAULT_VPC_ID}"

# Iterate over each interface
INDEX=0
while read -r ENI_ID VPC_ID SUBNET_ID IPs; do
    if [ -z "$ENI_ID" ] || [ -z "$VPC_ID" ] || [ -z "$SUBNET_ID" ] || [ -z "$IPs" ]; then
        info "[WARN] Interface ${INDEX} has missing fields, skipping"
        (( INDEX++ ))
        continue
    fi
    info "  ───────────────────────────────────────"
    if [ "$VPC_ID" != "$DEFAULT_VPC_ID" ]; then
        info "[WARN] Interface ${INDEX} belongs to a different VPC (${VPC_ID}), skipping"
        (( INDEX++ ))
        continue
    fi
    info "[INFO]  Subnet ID: ${SUBNET_ID}"
    if [ "$QUIET" = true ]; then
        echo "${IPs}"
    else
        echo "        Private IP(s): ${IPs}"
    fi
    (( INDEX++ ))
done <<< "$INTERFACES"

exit 0