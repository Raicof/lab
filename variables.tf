variable "proxmox_node_name" {
  description = "Parent node name"
  type        = string
  default     = "node_name"
}

variable "talos_version" {
  type    = string
  default = "v1.5.0"
}

variable "talos_image_factory_id" {
  type    = string
  default = "factory"
}

variable "talos_vm" {
  type = object({
    id      = number
    name    = string
    cores   = number
    memory  = number
    disk_gb = number

    network = object({
      bridge  = string
      vlan_id = number
      mac     = string
      address = string
      gateway = string
      dns     = list(string)
    })
  })
}

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
  default     = "https://proxmox.example.com:8006/api2/json"
}

variable "proxmox_api_token" {
  description = "Proxmox VE API token"
  type        = string
  sensitive   = true
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.35.2"
}

variable "cluster_name" {
  description = "Cluster name"
  type        = string
  default     = "talos-cluster"
}