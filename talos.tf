locals {
  talos_node_ip      = var.talos_vm.network.address
  talos_cluster_name = var.talos_vm.name
}

resource "proxmox_download_file" "talos_iso" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_node_name
  url          = "https://factory.talos.dev/image/${var.talos_image_factory_id}/${var.talos_version}/nocloud-amd64.iso"
  file_name    = "talos-${var.talos_version}-nocloud-amd64.iso"

  overwrite = false
}

resource "proxmox_virtual_environment_vm" "talos_01" {
  name        = var.talos_vm.name
  description = "Single-node Talos Kubernetes VM"
  tags        = ["terraform", "talos", "kubernetes", "wordpress"]

  node_name = var.proxmox_node_name
  vm_id     = var.talos_vm.id

  bios          = "ovmf"
  machine       = "q35"
  scsi_hardware = "virtio-scsi-pci"

  on_boot         = true
  started         = true
  stop_on_destroy = true

  agent {
    enabled = true
  }
  cpu {
    cores = var.talos_vm.cores
    type  = "host"
  }

  memory {
    dedicated = var.talos_vm.memory
    floating  = 0
  }

  efi_disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    type         = "4m"
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = var.talos_vm.disk_gb
    file_format  = "raw"
    cache        = "writethrough"
    discard      = "on"
    ssd          = true
  }

  cdrom {
    file_id   = proxmox_download_file.talos_iso.id
    interface = "ide2"
  }

  boot_order = ["scsi0", "ide2"]

  network_device {
    bridge      = var.talos_vm.network.bridge
    model       = "virtio"
    vlan_id     = var.talos_vm.network.vlan_id
    mac_address = var.talos_vm.network.mac
  }

  operating_system {
    type = "l26"
  }

  serial_device {
    device = "socket"
  }

  vga {
    type = "std"
  }
}

resource "talos_machine_secrets" "talos_01" {
  talos_version = var.talos_version
}

data "talos_client_configuration" "talos_01" {
  cluster_name         = local.talos_cluster_name
  client_configuration = talos_machine_secrets.talos_01.client_configuration
  nodes                = [local.talos_node_ip]
  endpoints            = [local.talos_node_ip]
}

data "talos_machine_configuration" "talos_01" {
  cluster_name     = local.talos_cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${local.talos_node_ip}:6443"
  machine_secrets  = talos_machine_secrets.talos_01.machine_secrets

  config_patches = [
    yamlencode({
      cluster = {
        allowSchedulingOnControlPlanes = true
      }
      machine = {
        network = {
          interfaces = [
            {
              interface = "eth0"
              dhcp      = false
              addresses = [var.talos_vm.network.address]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = var.talos_vm.network.gateway
                }
              ]
            }
          ]
          nameservers = var.talos_vm.network.dns
        }

        install = {
          disk  = "/dev/sda"
          image = "factory.talos.dev/nocloud-installer/${var.talos_image_factory_id}:${var.talos_version}"
        }
      }
    })
  ]
}

resource "talos_machine_configuration_apply" "talos_01" {
  client_configuration        = talos_machine_secrets.talos_01.client_configuration
  machine_configuration_input = data.talos_machine_configuration.talos_01.machine_configuration

  node     = local.talos_node_ip
  endpoint = local.talos_node_ip

  depends_on = [
    proxmox_virtual_environment_vm.talos_01
  ]
}

resource "talos_machine_bootstrap" "talos_01" {
  client_configuration = talos_machine_secrets.talos_01.client_configuration
  node                 = local.talos_node_ip
  endpoint             = local.talos_node_ip

  depends_on = [
    talos_machine_configuration_apply.talos_01
  ]
}

resource "talos_cluster_kubeconfig" "talos_01" {
  client_configuration = talos_machine_secrets.talos_01.client_configuration
  node                 = local.talos_node_ip
  endpoint             = local.talos_node_ip

  depends_on = [
    talos_machine_bootstrap.talos_01
  ]
}

output "talosconfig" {
  value     = data.talos_client_configuration.talos_01.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.talos_01.kubeconfig_raw
  sensitive = true
}