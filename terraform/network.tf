# VCN (Virtual Cloud Network)
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = [var.vcn_cidr_block]
  display_name   = "${var.project_name}-vcn"
  dns_label      = "newscheck"

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
  }
}

# Internet Gateway
resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-igw"
  enabled        = true

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
  }
}

# Route Table
resource "oci_core_route_table" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-route-table"

  route_rules {
    network_entity_id = oci_core_internet_gateway.main.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
  }
}

# Security List
resource "oci_core_security_list" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-security-list"

  # Egress Rules (送信ルール: すべての通信を許可)
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
  }

  # Ingress Rule: SSH (22) - From User IP (Direct)
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = var.allowed_client_cidr
    stateless   = false
    description = "Allow SSH access from user IP"

    tcp_options {
      min = 22
      max = 22
    }
  }


  # Ingress Rule: SSH (22) - From OCI Bastion private endpoint (Managed SSH Session)
  # Bastionのプライベート・エンドポイントは対象サブネット（このサブネット自身）内の
  # IPアドレスを使用するため、インターネットへの新たな開放は発生しない
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = var.subnet_cidr_block
    stateless   = false
    description = "Allow SSH from OCI Bastion private endpoint (CI/CD)"

    tcp_options {
      min = 22
      max = 22
    }
  }

  # Ingress Rule: HTTP (80)
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    stateless   = false
    description = "Allow HTTP access"

    tcp_options {
      min = var.app_http_port
      max = var.app_http_port
    }
  }

  # Ingress Rule: HTTPS (443)
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    stateless   = false
    description = "Allow HTTPS access"

    tcp_options {
      min = var.app_https_port
      max = var.app_https_port
    }
  }

  # Ingress Rule: ICMP (ping)
  ingress_security_rules {
    protocol    = "1" # ICMP
    source      = "0.0.0.0/0"
    stateless   = false
    description = "Allow ICMP (ping)"
  }

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
  }
}

# Public Subnet
resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.subnet_cidr_block
  display_name               = "${var.project_name}-public-subnet"
  dns_label                  = "public"
  route_table_id             = oci_core_route_table.main.id
  security_list_ids          = [oci_core_security_list.main.id]
  prohibit_public_ip_on_vnic = false

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
  }
}
