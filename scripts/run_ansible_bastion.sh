#!/bin/bash

# Ansible Run via OCI Bastion (Managed SSH Session) v1.0
# GitHub Actions から、セキュリティ・リストを変更せずに Ansible を適用するためのラッパー。
# OCI CLI が認証済み（環境変数 OCI_CLI_USER / OCI_CLI_FINGERPRINT / OCI_CLI_KEY_CONTENT 等、
# または ~/.oci/config）であることを前提とする。

set -e

# --- Help ---
show_help() {
    echo "Usage: $0 [ansible-playbook-options]"
    echo "This script creates an OCI Bastion Managed SSH Session and runs ansible-playbook through it."
    echo "All options are passed directly to ansible-playbook."
    echo ""
    echo "Environment variables:"
    echo "  TF_DIR                 Path to terraform directory (default: <repo root>/terraform)"
    echo "  BASTION_SESSION_TTL    Bastion session TTL in seconds (default: 1800)"
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    show_help
    exit 0
fi

# --- Check Requirements ---
for cmd in ansible-playbook jq oci ssh-keygen ssh; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is not installed." >&2
        exit 1
    fi
done

# --- Resolve Terraform Directory ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TF_DIR="${TF_DIR:-$SCRIPT_DIR/../terraform}"

if [ ! -d "$TF_DIR" ]; then
    echo "Error: Terraformディレクトリが見つかりません: $TF_DIR" >&2
    exit 1
fi

# --- Get Info from Terraform ---
echo "=== [1/3] Terraformから接続情報を取得中... (Dir: $TF_DIR) ==="
TF_OUTPUT=$(cd "$TF_DIR" && terraform output -json)

INSTANCE_OCID=$(echo "$TF_OUTPUT" | jq -r '.instance_ocid.value // empty')
INSTANCE_PRIVATE_IP=$(echo "$TF_OUTPUT" | jq -r '.instance_private_ip.value // empty')
OS_USERNAME=$(echo "$TF_OUTPUT" | jq -r '.instance_user.value // "seiya"')
BASTION_ID=$(echo "$TF_OUTPUT" | jq -r '.bastion_id.value // empty')
OCI_REGION=$(echo "$TF_OUTPUT" | jq -r '.oci_region.value // empty')
OCI_TENANCY_OCID=$(echo "$TF_OUTPUT" | jq -r '.oci_tenancy_ocid.value // empty')
OCI_VAULT_ID=$(echo "$TF_OUTPUT" | jq -r '.oci_vault_id.value // empty')
OCI_COMPARTMENT_OCID=$(echo "$TF_OUTPUT" | jq -r '.oci_compartment_ocid.value // empty')
BACKUP_BUCKET_NAME=$(echo "$TF_OUTPUT" | jq -r '.backup_bucket_name.value // empty')
BACKUP_NAMESPACE=$(echo "$TF_OUTPUT" | jq -r '.objectstorage_namespace.value // empty')
BACKUP_TOPIC_ID=$(echo "$TF_OUTPUT" | jq -r '.backup_topic_id.value // empty')

if [ -z "$BASTION_ID" ] || [ -z "$INSTANCE_PRIVATE_IP" ] || [ -z "$INSTANCE_OCID" ]; then
    echo "Error: terraform output から Bastion / インスタンスの情報が取得できませんでした。" >&2
    exit 1
fi

export OCI_CLI_REGION="$OCI_REGION"
export OCI_CLI_TENANCY="$OCI_TENANCY_OCID"

echo "  Bastion ID  : $BASTION_ID"
echo "  Instance IP : $INSTANCE_PRIVATE_IP (private)"

# --- Create Ephemeral SSH Key ---
SESSION_DIR=$(mktemp -d)
cleanup() {
    if [ -n "$SESSION_ID" ]; then
        echo "=== セッションを削除中... (Session ID: $SESSION_ID) ==="
        oci bastion session delete --session-id "$SESSION_ID" --force > /dev/null 2>&1 || true
    fi
    rm -rf "$SESSION_DIR"
}
trap cleanup EXIT

ssh-keygen -t ed25519 -N "" -f "$SESSION_DIR/id_ed25519" -q

# --- Create Bastion Managed SSH Session ---
echo "=== [2/3] OCI Bastion の Managed SSH Session を作成中... ==="
SESSION_ID=$(oci --debug bastion session create-managed-ssh \
    --bastion-id "$BASTION_ID" \
    --target-resource-id "$INSTANCE_OCID" \
    --target-os-username "$OS_USERNAME" \
    --target-private-ip "$INSTANCE_PRIVATE_IP" \
    --ssh-public-key-file "$SESSION_DIR/id_ed25519.pub" \
    --session-ttl "${BASTION_SESSION_TTL:-1800}" \
    --display-name "gha-ansible-$(date +%s)" \
    --wait-for-state SUCCEEDED --wait-for-state FAILED \
    --query 'data.resources[0].identifier' --raw-output)

if [ -z "$SESSION_ID" ]; then
    echo "Error: Bastion セッションの作成に失敗しました。" >&2
    exit 1
fi
echo "  Session ID: $SESSION_ID"

BASTION_HOST="host.bastion.${OCI_REGION}.oci.oraclecloud.com"
PROXY_COMMAND="ssh -i $SESSION_DIR/id_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p -p 22 ${SESSION_ID}@${BASTION_HOST}"

# --- Build Extra Vars File ---
# ProxyCommandを含む値をシェルのクォート経由で-eへ渡すと壊れやすいため、
# JSONファイル経由（-e @file）でAnsibleへ渡す
EXTRA_VARS_FILE="$SESSION_DIR/extra_vars.json"
ANSIBLE_HOST="$INSTANCE_PRIVATE_IP" \
ANSIBLE_USER="$OS_USERNAME" \
ANSIBLE_SSH_PRIVATE_KEY_FILE="$SESSION_DIR/id_ed25519" \
ANSIBLE_SSH_COMMON_ARGS="-o ProxyCommand=\"$PROXY_COMMAND\" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
EXTRA_OCI_VAULT_ID="$OCI_VAULT_ID" \
EXTRA_OCI_REGION="$OCI_REGION" \
EXTRA_OCI_COMPARTMENT_OCID="$OCI_COMPARTMENT_OCID" \
EXTRA_BACKUP_BUCKET_NAME="$BACKUP_BUCKET_NAME" \
EXTRA_BACKUP_NAMESPACE="$BACKUP_NAMESPACE" \
EXTRA_BACKUP_TOPIC_ID="$BACKUP_TOPIC_ID" \
python3 -c '
import json, os
print(json.dumps({
    "ansible_host": os.environ["ANSIBLE_HOST"],
    "ansible_user": os.environ["ANSIBLE_USER"],
    "ansible_ssh_private_key_file": os.environ["ANSIBLE_SSH_PRIVATE_KEY_FILE"],
    "ansible_ssh_common_args": os.environ["ANSIBLE_SSH_COMMON_ARGS"],
    "oci_vault_id": os.environ["EXTRA_OCI_VAULT_ID"],
    "oci_region": os.environ["EXTRA_OCI_REGION"],
    "oci_compartment_ocid": os.environ["EXTRA_OCI_COMPARTMENT_OCID"],
    "backup_bucket_name": os.environ["EXTRA_BACKUP_BUCKET_NAME"],
    "backup_namespace": os.environ["EXTRA_BACKUP_NAMESPACE"],
    "backup_topic_id": os.environ["EXTRA_BACKUP_TOPIC_ID"],
}))
' > "$EXTRA_VARS_FILE"

# --- Run Ansible ---
echo "=== [3/3] Ansibleの実行を開始します... ==="
cd "$SCRIPT_DIR/../ansible"
ansible-playbook -i hosts.yml site.yml -e "@$EXTRA_VARS_FILE" "$@"
