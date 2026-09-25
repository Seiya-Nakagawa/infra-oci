#!/bin/bash
# 全データベースを個別にダンプし、gzip 圧縮して Object Storage へ退避する。
# 月初は、月次用のプレフィックスにも同じダンプを保管する。
set -euo pipefail

source /etc/mysql-backup.env
export OCI_CLI_AUTH=instance_principal

# 標準の管理用スキーマはダンプ対象外
EXCLUDE_SCHEMAS_REGEX='^(information_schema|performance_schema|mysql|sys)$'

WORK_DIR=$(mktemp -d /var/tmp/mysql-backup.XXXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT

# パスワードはコマンドラインへ出さず、一時ファイル経由で mysqldump へ渡す
PASSWORD=$("$OCI_CLI_BIN" secrets secret-bundle get-secret-bundle-by-name \
  --secret-name "$BACKUP_SECRET_NAME" --vault-id "$OCI_VAULT_ID" \
  --query 'data."secret-bundle-content".content' --raw-output | base64 -d)
DEFAULTS_FILE="$WORK_DIR/client.cnf"
umask 077
printf '[client]\nuser=%s\npassword=%s\nsocket=/var/run/mysqld/mysqld.sock\n' \
  "$BACKUP_DB_USER" "$PASSWORD" > "$DEFAULTS_FILE"
unset PASSWORD

TODAY=$(date +%F)
THIS_MONTH=$(date +%Y-%m)
IS_FIRST_DAY=$([ "$(date +%d)" = "01" ] && echo yes || echo no)

mapfile -t DATABASES < <(mysql --defaults-extra-file="$DEFAULTS_FILE" -N -B -e 'SHOW DATABASES' \
  | grep -Ev "$EXCLUDE_SCHEMAS_REGEX")

if [ "${#DATABASES[@]}" -eq 0 ]; then
  echo "ダンプ対象のデータベースがありません" >&2
  exit 1
fi

upload() {
  "$OCI_CLI_BIN" os object put --namespace-name "$BACKUP_NAMESPACE" --bucket-name "$BACKUP_BUCKET" \
    --name "$1" --file "$2" --force > /dev/null
}

for db in "${DATABASES[@]}"; do
  dump_file="$WORK_DIR/${db}.sql.gz"
  mysqldump --defaults-extra-file="$DEFAULTS_FILE" \
    --single-transaction --routines --triggers --events --no-tablespaces \
    --databases "$db" | gzip > "$dump_file"
  gzip -t "$dump_file"

  upload "daily/${TODAY}/${db}.sql.gz" "$dump_file"
  if [ "$IS_FIRST_DAY" = "yes" ]; then
    upload "monthly/${THIS_MONTH}/${db}.sql.gz" "$dump_file"
  fi
  echo "バックアップ完了: ${db}"
  rm -f "$dump_file"
done
