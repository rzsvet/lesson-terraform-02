variable "resource_group_location" {
  default     = "westeurope"
  description = "Location of the resource group."
}

variable "resource_group_name_prefix" {
  default     = "myresource"
  description = "Name of the resource group."
}

variable "owner" {
  default     = "info@po4ta.me"
  description = "Email of owner resource"
}

locals {
  common_tags = {
    Owner = "${var.owner}"
  }
}
