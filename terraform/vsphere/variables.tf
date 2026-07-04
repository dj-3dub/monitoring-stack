variable "vsphere_server" {
  type        = string
  description = "vSphere or ESXi server address"
}

variable "vsphere_user" {
  type        = string
  description = "vSphere username"
}

variable "vsphere_password" {
  type        = string
  description = "vSphere password"
  sensitive   = true
}

variable "allow_unverified_ssl" {
  type        = bool
  default     = true
}

variable "datacenter" {
  type        = string
  description = "vSphere datacenter name"
}

variable "datastore" {
  type        = string
  description = "Target datastore"
}

variable "resource_pool" {
  type        = string
  description = "Target resource pool"
}

variable "network" {
  type        = string
  description = "Target VM network"
}

variable "template_name" {
  type        = string
  description = "Debian template name"
}

variable "vm_name" {
  type    = string
  default = "monitoring01"
}

variable "vm_cpu" {
  type    = number
  default = 2
}

variable "vm_memory" {
  type    = number
  default = 4096
}

variable "vm_disk_size" {
  type    = number
  default = 80
}
