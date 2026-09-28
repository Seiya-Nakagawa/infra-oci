# OCI Bastion (Managed SSH Session)
#
# Ansible の適用を GitHub Actions から行うため、セキュリティ・リストへ
# インターネット向けの新たな SSH 受信ルールを追加せず、対象サブネット内に置く
# Bastion のプライベート・エンドポイント経由で Compute Instance へ接続する。
resource "oci_bastion_bastion" "main" {
  compartment_id   = var.compartment_ocid
  bastion_type     = "STANDARD"
  name             = "${var.project_name}-bastion"
  target_subnet_id = oci_core_subnet.public.id

  # GitHub-hosted runner の送信元IPは動的で事前に列挙できないため、
  # セッション作成の可否は最小権限のIAMポリシー（iam-bastion.tf）で制御する
  client_cidr_block_allow_list = ["0.0.0.0/0"]

  max_session_ttl_in_seconds = var.bastion_max_session_ttl_in_seconds

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
  }
}
