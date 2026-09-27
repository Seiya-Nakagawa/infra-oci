# Compute Instance
resource "oci_core_instance" "main" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = var.instance_display_name
  shape               = var.instance_shape

  # Always Free: VM.Standard.A1.Flex (ARM) - 4 OCPU, 24GB RAM
  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_in_gbs
  }

  # Oracle Cloud Agentの設定
  # BastionプラグインはOCI BastionのManaged SSH Sessionが一時鍵を
  # 反映するために必要なため有効化する（bastion.tf）
  agent_config {
    is_management_disabled = false
    is_monitoring_disabled = false

    plugins_config {
      desired_state = "ENABLED"
      name          = "Bastion"
    }
  }

  # OS Image (Ubuntu 24.04 ARM64)
  source_details {
    source_type             = "image"
    source_id               = var.os_image_id != "" ? var.os_image_id : data.oci_core_images.ubuntu_arm64.images[0].id
    boot_volume_size_in_gbs = 200 # Always Free: max 200GB
  }

  # Network設定
  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    display_name     = "${var.instance_display_name}-vnic"
  }

  # Cloud-init & SSH Key
  metadata = {
    ssh_authorized_keys = var.ssh_public_key # Keep for default user access as backup
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
      ssh_public_key = var.ssh_public_key
      instance_user  = var.instance_user
    }))
  }

  # 永続化設定
  # インスタンス削除時もブートボリューム（MySQL データを含む）を残す
  preserve_boot_volume = true

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
  }

  # 誤った削除・置換を防ぐ
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      source_details[0].source_id, # OSイメージの更新を無視
      metadata,                    # メタデータの変更による再作成を無視
    ]
  }
}
