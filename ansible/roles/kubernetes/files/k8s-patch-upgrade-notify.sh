#!/bin/bash
# パッチ自動更新の失敗を OCI Notifications へ発行する（k8s-patch-upgrade.service の OnFailure から起動）
# 通知先と OCI CLI は、DB バックアップの失敗通知と同じ設定を使う
set -euo pipefail

source /etc/mysql-backup.env
export OCI_CLI_AUTH=instance_principal

"$OCI_CLI_BIN" ons message publish --topic-id "$BACKUP_TOPIC_ID" \
  --title "[$(hostname)] Kubernetes パッチ自動更新失敗" \
  --body "k8s-patch-upgrade.service が失敗しました。ホスト上で journalctl -u k8s-patch-upgrade.service を確認してください。/var/lib/k8s-patch-upgrade/failed がある場合は、原因に対処して削除するまで自動更新を再開しません。" \
  > /dev/null
