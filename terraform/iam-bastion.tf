# CI/CD (GitHub Actions) からAnsibleを適用するための最小権限グループ・ポリシー
#
# ユーザー本体の作成・APIキーの発行・グループへの追加は本リポジトリのスコープ外とし、
# 管理者が手動で行う（7章 アカウント管理）。Terraformが管理するのは、
# OCI Bastionのセッション管理のみを許可するグループとポリシーに限る。
resource "oci_identity_group" "cicd_bastion" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project_name}-cicd-bastion-group"
  description    = "GitHub ActionsがOCI Bastionのセッションを作成するための専用グループ"
}

resource "oci_identity_policy" "cicd_bastion" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project_name}-cicd-bastion-policy"
  description    = "CI/CD専用グループにOCI Bastionのセッション管理のみを許可する"
  statements = [
    "allow group ${oci_identity_group.cicd_bastion.name} to manage bastion-session in compartment id ${var.compartment_ocid}",
    # セッション作成時にBastion自体を参照するために必要な最小限の読み取り権限
    "allow group ${oci_identity_group.cicd_bastion.name} to read bastion in compartment id ${var.compartment_ocid}",
  ]
}
