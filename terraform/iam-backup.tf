# DBバックアップ用の権限
#
# バックアップスクリプトはインスタンスプリンシパルで動作する。対象のインスタンスは
# vault.tf の Dynamic Group（oci_identity_dynamic_group.eso）に含まれるため、
# 新たな Dynamic Group は作らず、権限のみをポリシーで追加する。
# Vault Secret の読み取りは eso_vault_read で付与済み。
resource "oci_identity_policy" "db_backup" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project_name}-db-backup-policy"
  description    = "DBバックアップ用にバケットへの書き込みと通知の発行のみを許可する"
  statements = [
    "allow dynamic-group ${oci_identity_dynamic_group.eso.name} to manage objects in compartment id ${var.compartment_ocid} where target.bucket.name = '${local.backup_bucket_name}'",
    "allow dynamic-group ${oci_identity_dynamic_group.eso.name} to use ons-topics in compartment id ${var.compartment_ocid} where request.permission = 'ONS_TOPIC_PUBLISH'",
  ]
}

# バケットのライフサイクルルールがオブジェクトを削除できるようにする
resource "oci_identity_policy" "objectstorage_lifecycle" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project_name}-objectstorage-lifecycle-policy"
  description    = "Object Storage のライフサイクルルールによるオブジェクト削除を許可する"
  statements = [
    "allow service objectstorage-${var.region} to manage object-family in compartment id ${var.compartment_ocid}"
  ]
}
