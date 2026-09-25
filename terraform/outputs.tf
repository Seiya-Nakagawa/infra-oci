# インスタンスの公開IPアドレス
output "instance_public_ip" {
  description = "Public IP address of the compute instance"
  value       = oci_core_instance.main.public_ip
}

# インスタンスのプライベートIPアドレス
output "instance_private_ip" {
  description = "Private IP address of the compute instance"
  value       = oci_core_instance.main.private_ip
}

# インスタンスOCID
output "instance_ocid" {
  description = "OCID of the compute instance"
  value       = oci_core_instance.main.id
}

# VCN OCID
output "vcn_ocid" {
  description = "OCID of the VCN"
  value       = oci_core_vcn.main.id
}

# Subnet OCID
output "subnet_ocid" {
  description = "OCID of the public subnet"
  value       = oci_core_subnet.public.id
}

# Cloud Shell経由の接続案内
output "cloud_shell_instruction" {
  description = "Connection instruction using Cloud Shell"
  value       = "Use OCI Cloud Shell or Console Connection to access the instance."
}

# インスタンスの状態
output "instance_state" {
  description = "Current state of the instance"
  value       = oci_core_instance.main.state
}

# アプリケーションURL
output "application_url" {
  description = "URL to access the application"
  value       = "http://${oci_core_instance.main.public_ip}"
}

# 使用しているOSイメージ
output "os_image_name" {
  description = "Name of the OS image used"
  value       = var.os_image_id != "" ? "Custom Image" : data.oci_core_images.ubuntu_arm64.images[0].display_name
}

# インスタンスのユーザー名
output "instance_user" {
  description = "Default SSH user for the instance"
  value       = var.instance_user
}

# OCI Vault OCID (Ansible/ESOがSecret参照に使用)
output "oci_vault_id" {
  description = "OCID of the OCI Vault storing shared application secrets"
  value       = oci_kms_vault.secrets.id
}

# コンパートメントOCID (ClusterSecretStore設定に使用)
output "oci_compartment_ocid" {
  description = "Compartment OCID where the vault and its secrets live"
  value       = var.compartment_ocid
  sensitive   = true
}

# リージョン (ClusterSecretStore設定に使用)
output "oci_region" {
  description = "OCI region where the vault is provisioned"
  value       = var.region
}

# DBバックアップの保管先バケット名
output "backup_bucket_name" {
  description = "Object Storage bucket name for DB dumps"
  value       = oci_objectstorage_bucket.db_backup.name
}

# Object Storage ネームスペース
output "objectstorage_namespace" {
  description = "Object Storage namespace of the tenancy"
  value       = data.oci_objectstorage_namespace.main.namespace
}

# バックアップ失敗通知トピックのOCID
output "backup_topic_id" {
  description = "OCID of the notification topic for backup failures"
  value       = oci_ons_notification_topic.backup_failure.id
}
