variable "subscription_id" {
  default = {
    "default" = "9fbf7025-df40-4908-b7fb-a3a2144cee91"
    "prod"    = "9fbf7025-df40-4908-b7fb-a3a2144cee91"
    "test"    = "9db13c96-62ad-4945-9579-74aeed296e48"
  }
}

variable "location" {
  description = "The default Azure region for the resource provisioning"
  default     = "East US 2"
}

variable "environment_name" {
  description = "Full name of the environment to be created"

  default = {
    "default" = "prodarm"
    "prod"    = "prodarm"
    "test"    = "testarm"
  }
}

variable "penv" {
  description = "Shorthand version of the environment name"

  default = {
    "default" = "prd"
    "prod"    = "prd"
    "test"    = "tst"
  }
}

variable "chef_server_url" {
  description = "Enter full chef url using private ip"
  default     = "https://10.16.192.4/organizations/trek"
}

variable "chef_environment" {
  description = "Enter desired environment to be setup on chef server"

  default = {
    "default" = "production"
    "prod"    = "production"
    "test"    = "staging"
  }
}

variable "chef_user_name" {
  description = "Enter username to be utilized with validation key"
  default     = "trek-validator"
}

variable "chef_client_version" {
  description = "Version of Chef-Client to utilized during provision time"
  default     = "13.8.5"
}

variable "win_image_publisher" {
  description = "Publisher name of the windows machine image"
  default     = "MicrosoftSQLServer"
}

variable "win_image_offer" {
  description = "Offer name of the windows machine image"
  default     = "SQL2016SP1-WS2016"
}

variable "win_image_sku" {
  description = "SKU of the windows machine image"
  default     = "SQLDEV"
}

variable "win_image_version" {
  description = "Image version desired for windows machines"
  default     = "13.1.900302"
}

variable "base_runlist" {
  default = "cb_dvo_chefclient, cb_dvo_adjoin, cb_dvo_sshd, cb_dvo_authorization, cb_dvo_prtg, cb_dvo_logging"
}

variable "vnet" {
  description = "Name of the virtual network to be used."

  default = {
    "default" = "AZ-VN-EastUS2-02"
    "prod"    = "AZ-VN-EastUS2-02"
    "test"    = "AZ-VN-EastUS2-01"
  }
}

variable "sql_vm_size" {
  description = "Desired size of the SQL node"
  default     = "Standard_D2_v2"
}

variable "count_sql_vms" {
  description = "Number of desired sql vms"

  default = {
    default = 1
    prod    = 1
    test    = 1
    devops  = 1
  }
}

variable "sql_subnet_id" {
  description = "Full path of the subnet desired for the SQL node"

  default = {
    default = "/subscriptions/9fbf7025-df40-4908-b7fb-a3a2144cee91/resourceGroups/AZ-RG-Network/providers/Microsoft.Network/virtualNetworks/AZ-VN-EastUS2-02/subnets/AZ-SN-back"
    prod    = "/subscriptions/9fbf7025-df40-4908-b7fb-a3a2144cee91/resourceGroups/AZ-RG-Network/providers/Microsoft.Network/virtualNetworks/AZ-VN-EastUS2-02/subnets/AZ-SN-back"
    test    = "/subscriptions/9db13c96-62ad-4945-9579-74aeed296e48/resourceGroups/AZ-RG-Network/providers/Microsoft.Network/virtualNetworks/AZ-VN-EastUS2-01/subnets/AZ-SN-back"
  }
}

variable "sql_chef_runlist" {
  description = "An ordered runlist to be sent to the chef server on provision for the SQL node"
  default     = "cb_dvo_chefclient, cb_dvo_prtg"
}

locals {
  admin_credentials = "${split("\n",file("${path.module}/secrets/admin_credentials"))}"
  admin_user        = "${local.admin_credentials[0]}"
  admin_password    = "${local.admin_credentials[1]}"
  ad_credentials    = "${split("\n",file("${path.module}/secrets/ad_credentials"))}"
  ad_user           = "${local.ad_credentials[0]}"
  ad_password       = "${local.ad_credentials[1]}"
  script_storage_key = "${trimspace(file("${path.module}/secrets/script_storage_key"))}"
}
