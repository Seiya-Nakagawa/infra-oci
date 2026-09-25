# OCI認証情報
variable "tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
}

variable "user_ocid" {
  description = "OCI User OCID"
  type        = string
}

variable "fingerprint" {
  description = "OCI API Key Fingerprint"
  type        = string
}

variable "private_key" {
  description = "OCI API private key content (PEM format)"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "OCI Region"
  type        = string
  default     = "ap-tokyo-1"
}

# コンパートメント
variable "compartment_ocid" {
  description = "OCI Compartment OCID where resources will be created"
  type        = string
}

# インスタンス設定
variable "instance_shape" {
  description = "Instance shape (Always Free: VM.Standard.A1.Flex)"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "instance_ocpus" {
  description = "Number of OCPUs for the instance (Always Free: max 4)"
  type        = number
  default     = 4
}

variable "instance_memory_in_gbs" {
  description = "Amount of memory in GBs (Always Free: max 24)"
  type        = number
  default     = 24
}

variable "instance_display_name" {
  description = "Display name for the compute instance"
  type        = string
  default     = "infra-oci-app-server"
}

variable "instance_user" {
  description = "OS user to create on the instance"
  type        = string
  default     = "seiya"
}



# OS設定
variable "os_image_id" {
  description = "OCID of the OS image (Oracle Linux 9 or Ubuntu 24.04 ARM64)"
  type        = string
  # デフォルトは空にして、data sourceから取得する
  default = ""
}

# ネットワーク設定
variable "vcn_cidr_block" {
  description = "CIDR block for the VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr_block" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# アプリケーション設定
variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH directly to the instance public IP (default: 0.0.0.0/0)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "allowed_client_cidr" {
  description = "CIDR block allowed to SSH directly to the instance (Your home IP)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "app_http_port" {
  description = "HTTP port for the application"
  type        = number
  default     = 80
}

variable "app_https_port" {
  description = "HTTPS port for the application"
  type        = number
  default     = 443
}

# タグ
variable "project_name" {
  description = "Project name for tagging resources"
  type        = string
  default     = "infra-oci"
}

variable "environment" {
  description = "Environment name (e.g., production, staging)"
  type        = string
  default     = "production"
}
# アプリケーション秘密情報
variable "gemini_api_key" {
  description = "Gemini API Key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "youtube_api_key" {
  description = "YouTube API Key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain name for the application (e.g., infra-oci.example.com)"
  type        = string
  default     = ""
}

variable "notification_email" {
  description = "DBバックアップ失敗の通知先メールアドレス"
  type        = string
}
