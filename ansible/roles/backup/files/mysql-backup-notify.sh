#!/bin/bash
# バックアップ失敗を OCI Notifications へ発行する（mysql-backup.service の OnFailure から起動）
set -euo pipefail

source /etc/mysql-backup.env
export OCI_CLI_AUTH=instance_principal

"$OCI_CLI_BIN" ons message publish --topic-id "$BACKUP_TOPIC_ID" \
  --title "[$(hostname)] DBバックアップ失敗" \
  --body "mysql-backup.service が失敗しました。ホスト上で journalctl -u mysql-backup.service を確認してください。" \
  > /dev/null
