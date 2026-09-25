# データソース: Availability Domain
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# データソース: OS Image (Ubuntu 24.04 ARM64)
data "oci_core_images" "ubuntu_arm64" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# データソース: Object Storage ネームスペース
data "oci_objectstorage_namespace" "main" {
  compartment_id = var.compartment_ocid
}
