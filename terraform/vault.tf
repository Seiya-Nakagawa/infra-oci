# OCI Vault (Secrets Management)
#
# 個人開発プロジェクト間で共有する app-dbuser のパスワードを、各プロジェクトの
# .env へ平文で書き写す運用をやめ、OCI Vault を真実源として一元管理する。
# Always Free 枠に収めるため DEFAULT Vault（ソフトウェア鍵）を使用し、
# HSM は使用しない（HSM保護モードは課金対象のため）。
resource "oci_kms_vault" "secrets" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-vault"
  vault_type     = "DEFAULT"
}

resource "oci_kms_key" "app_db_password_key" {
  compartment_id      = var.compartment_ocid
  display_name        = "${var.project_name}-app-db-key"
  management_endpoint = oci_kms_vault.secrets.management_endpoint
  protection_mode     = "SOFTWARE"

  key_shape {
    algorithm = "AES"
    length    = 32
  }
}

# MySQLのIDENTIFIED WITH ... BY '...'へ安全に埋め込める文字種に限定する
resource "random_password" "app_db_password" {
  length  = 32
  special = false
}

resource "oci_vault_secret" "app_db_password" {
  compartment_id = var.compartment_ocid
  vault_id       = oci_kms_vault.secrets.id
  key_id         = oci_kms_key.app_db_password_key.id
  secret_name    = "app-dbuser-password"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(random_password.app_db_password.result)
  }

  # 値は初回作成時のみ Terraform が設定する。以降は MySQL の実パスワードに合わせて
  # 新バージョンを登録するため、Terraform がランダム値へ巻き戻さないようにする
  lifecycle {
    ignore_changes = [secret_content]
  }
}

# External Secrets Operator (Kubernetes上) がInstance Principalで
# OCI Vaultを読み取れるようにする。
resource "oci_identity_dynamic_group" "eso" {
  # Dynamic GroupはテナンシOCID配下にのみ作成できる
  compartment_id = var.tenancy_ocid
  name           = "${var.project_name}-eso-dynamic-group"
  description    = "External Secrets OperatorがInstance PrincipalでOCI Vaultを読むためのDynamic Group"
  matching_rule  = "ANY {instance.id = '${oci_core_instance.main.id}'}"
}

resource "oci_identity_policy" "eso_vault_read" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project_name}-eso-vault-read-policy"
  description    = "External Secrets OperatorのInstance Principalによるsecret読み取りを許可する"
  statements = [
    "allow dynamic-group ${oci_identity_dynamic_group.eso.name} to read secret-family in compartment id ${var.compartment_ocid}"
  ]
}
