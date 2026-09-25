terraform {
  required_version = "~> 1.14"

  # Terraform Cloud使用時はコメント解除
  # ローカル実行時はコメントアウトのまま
  cloud {
    organization = "aibdlnew1-organization"
    workspaces {
      name = "infra-oci"
    }
  }

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "oci" {
  # 認証情報の設定方法:
  #
  # [Terraform Cloud使用時]
  # Workspace の Variables セクションで以下を設定:
  # - tenancy_ocid (Sensitive)
  # - user_ocid (Sensitive)
  # - fingerprint (Sensitive)
  # - private_key (Sensitive) ← 秘密鍵の内容を直接設定
  # - region
  #
  # [ローカル実行時]
  # terraform.tfvars ファイルまたは環境変数で設定
  # private_key = file("~/.oci/oci_api_key.pem") のように指定可能
  tenancy_ocid = var.tenancy_ocid
  user_ocid    = var.user_ocid
  fingerprint  = var.fingerprint
  private_key  = var.private_key
  region       = var.region
}
