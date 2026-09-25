#!/bin/bash

# Ansible Run Wrapper v2.0
# This script resolves the target host from terraform output and runs ansible-playbook.

set -e

# --- Default Values ---
SSH_PRIV_KEY_FILE="$HOME/.ssh/id_rsa"

# --- Help ---
show_help() {
    echo "Usage: $0 [ansible-playbook-options]"
    echo "This script runs ansible-playbook against the instance created by Terraform."
    echo "All options are passed directly to ansible-playbook."
    echo ""
    echo "Environment variables:"
    echo "  SSH_PRIV_KEY_FILE  SSH private key path (default: $HOME/.ssh/id_rsa)"
    echo "  TF_DIR             Path to terraform directory (default: <repo root>/terraform)"
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    show_help
    exit 0
fi

# --- Check Requirements ---
if ! command -v ansible-playbook &> /dev/null; then
    echo "Error: ansible-playbook is not installed."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed."
    exit 1
fi

# --- Resolve Terraform Directory ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TF_DIR="${TF_DIR:-$SCRIPT_DIR/../terraform}"

if [ ! -d "$TF_DIR" ]; then
    echo "Error: Terraformディレクトリが見つかりません: $TF_DIR"
    exit 1
fi

# --- Get Info from Terraform ---
echo "=== [1/2] Terraformから情報を取得中... (Dir: $TF_DIR) ==="
TF_OUTPUT=$(cd "$TF_DIR" && terraform output -json)

INSTANCE_IP=$(echo "$TF_OUTPUT" | jq -r '.instance_public_ip.value // empty')
OS_USERNAME=$(echo "$TF_OUTPUT" | jq -r '.instance_user.value // "seiya"')
OCI_VAULT_ID=$(echo "$TF_OUTPUT" | jq -r '.oci_vault_id.value // empty')
OCI_REGION=$(echo "$TF_OUTPUT" | jq -r '.oci_region.value // empty')
OCI_COMPARTMENT_OCID=$(echo "$TF_OUTPUT" | jq -r '.oci_compartment_ocid.value // empty')
BACKUP_BUCKET_NAME=$(echo "$TF_OUTPUT" | jq -r '.backup_bucket_name.value // empty')
BACKUP_NAMESPACE=$(echo "$TF_OUTPUT" | jq -r '.objectstorage_namespace.value // empty')
BACKUP_TOPIC_ID=$(echo "$TF_OUTPUT" | jq -r '.backup_topic_id.value // empty')

if [ -z "$INSTANCE_IP" ]; then
    echo "Error: terraform output からパブリックIPアドレス (instance_public_ip) が取得できませんでした。"
    exit 1
fi

echo "  Instance IP: $INSTANCE_IP"
echo "  User      : $OS_USERNAME"

# --- Run Ansible ---
echo "=== [2/2] Ansibleの実行を開始します... ==="
cd "$SCRIPT_DIR/../ansible"
ansible-playbook -i hosts.yml site.yml \
    -e "ansible_host=$INSTANCE_IP" \
    -e "ansible_user=$OS_USERNAME" \
    -e "ansible_ssh_private_key_file=$SSH_PRIV_KEY_FILE" \
    -e "oci_vault_id=$OCI_VAULT_ID" \
    -e "oci_region=$OCI_REGION" \
    -e "oci_compartment_ocid=$OCI_COMPARTMENT_OCID" \
    -e "backup_bucket_name=$BACKUP_BUCKET_NAME" \
    -e "backup_namespace=$BACKUP_NAMESPACE" \
    -e "backup_topic_id=$BACKUP_TOPIC_ID" \
    "$@"
