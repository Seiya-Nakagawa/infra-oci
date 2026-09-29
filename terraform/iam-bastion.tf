# CI/CD (GitHub Actions) からAnsibleを適用するための最小権限グループ・ポリシー
#
# ユーザー本体の作成・APIキーの発行・グループへの追加は本リポジトリのスコープ外とし、
# 管理者が手動で行う（7章 アカウント管理）。Terraformが管理するのは、
# OCI Bastionのセッション管理と、MySQLロールがVaultからアプリケーションユーザーの
# パスワードを取得するために必要な最小限のSecret読み取りのみを許可するグループと
# ポリシーに限る。
resource "oci_identity_group" "cicd_bastion" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project_name}-cicd-bastion-group"
  description    = "GitHub ActionsがOCI Bastionのセッションを作成するための専用グループ"
}

resource "oci_identity_policy" "cicd_bastion" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project_name}-cicd-bastion-policy"
  description    = "CI/CD専用グループにOCI Bastionのセッション管理とVault Secretの読み取りのみを許可する"
  # Managed SSH Sessionの作成に必要な権限一式。Oracle公式のBastion IAM Policy Reference
  # （https://docs.oracle.com/en-us/iaas/Content/Bastion/Reference/bastionpolicyreference.htm）の
  # 「create, connect to, and terminate sessions」の例に加え、read private-ips を追加する。
  # manage bastion-session だけでは対象インスタンス・VNIC・エージェントプラグインの参照ができず、
  # セッション作成が404で失敗する。read private-ips が無い場合も、セッション作成時に指定した
  # target-private-ip の検証（ListPrivateIps/GetPrivateIp、Core Services IAM Policy Reference
  # https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/corepolicyreference.htm 参照）が
  # 権限不足となり、「Unknown resource <private-ip>」で404になる。
  #
  # read secret-family は、AnsibleのMySQLロールがVaultからアプリケーションユーザーの
  # パスワードを取得するタスク（delegate_to: localhostでAnsible実行元のOCI CLI認証情報を使う。
  # ansible/roles/mysql/tasks/main.yml）に必要。Instance Principal用ポリシー（vault.tfの
  # eso_vault_read）と同じverbに揃える。このタスクは--checkドライランではスキップされるため、
  # 実適用（CD）で初めて必要性が判明した。
  statements = [
    "allow group ${oci_identity_group.cicd_bastion.name} to use bastion in compartment id ${var.compartment_ocid}",
    "allow group ${oci_identity_group.cicd_bastion.name} to manage bastion-session in compartment id ${var.compartment_ocid}",
    "allow group ${oci_identity_group.cicd_bastion.name} to read instances in compartment id ${var.compartment_ocid}",
    "allow group ${oci_identity_group.cicd_bastion.name} to read vcn in compartment id ${var.compartment_ocid}",
    "allow group ${oci_identity_group.cicd_bastion.name} to read subnets in compartment id ${var.compartment_ocid}",
    "allow group ${oci_identity_group.cicd_bastion.name} to read instance-agent-plugins in compartment id ${var.compartment_ocid}",
    "allow group ${oci_identity_group.cicd_bastion.name} to read vnic-attachments in compartment id ${var.compartment_ocid}",
    "allow group ${oci_identity_group.cicd_bastion.name} to read vnics in compartment id ${var.compartment_ocid}",
    "allow group ${oci_identity_group.cicd_bastion.name} to read private-ips in compartment id ${var.compartment_ocid}",
    "allow group ${oci_identity_group.cicd_bastion.name} to read secret-family in compartment id ${var.compartment_ocid}",
  ]
}
