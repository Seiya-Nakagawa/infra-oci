# DBダンプの保管先バケット
#
# 日次は daily/、月次は monthly/ のプレフィックスで保管し、
# ライフサイクルルールで世代数（保持日数）を超えたオブジェクトを自動削除する。
locals {
  backup_bucket_name = "${var.project_name}-db-backup"

  # 日次30世代、月次12世代（月次は1か月あたり1世代のため日数へ換算）
  backup_daily_retention_days   = 30
  backup_monthly_retention_days = 365
}

resource "oci_objectstorage_bucket" "db_backup" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.main.namespace
  name           = local.backup_bucket_name
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = "Disabled"
}

resource "oci_objectstorage_object_lifecycle_policy" "db_backup" {
  namespace = data.oci_objectstorage_namespace.main.namespace
  bucket    = oci_objectstorage_bucket.db_backup.name

  rules {
    name        = "expire-daily"
    action      = "DELETE"
    is_enabled  = true
    time_amount = local.backup_daily_retention_days
    time_unit   = "DAYS"

    object_name_filter {
      inclusion_prefixes = ["daily/"]
    }
  }

  rules {
    name        = "expire-monthly"
    action      = "DELETE"
    is_enabled  = true
    time_amount = local.backup_monthly_retention_days
    time_unit   = "DAYS"

    object_name_filter {
      inclusion_prefixes = ["monthly/"]
    }
  }

  # ライフサイクルルールの実行には、Object Storage サービスへの権限付与が先に必要
  depends_on = [oci_identity_policy.objectstorage_lifecycle]
}
