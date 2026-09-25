# DBバックアップ失敗の通知
resource "oci_ons_notification_topic" "backup_failure" {
  compartment_id = var.compartment_ocid
  name           = "${var.project_name}-backup-failure"
  description    = "DBバックアップの失敗を通知するトピック"
}

# 購読するメールアドレスは確認メールのリンクを押すまで有効にならない
resource "oci_ons_subscription" "backup_failure_email" {
  compartment_id = var.compartment_ocid
  topic_id       = oci_ons_notification_topic.backup_failure.id
  protocol       = "EMAIL"
  endpoint       = var.notification_email
}
