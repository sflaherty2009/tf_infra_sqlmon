resource "azurerm_public_ip" "sql" {
  name                         = "azw-${lookup(var.penv,terraform.workspace)}-sqlmonmon-01-pubip"
  location                     = "${azurerm_resource_group.rg.location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  public_ip_address_allocation = "dynamic"
  domain_name_label            = "azw-${lookup(var.penv,terraform.workspace)}-sqlmonmon-01-${lower(azurerm_resource_group.rg.name)}"
}

resource "azurerm_network_interface" "sql" {
  name                = "azw-${lookup(var.penv,terraform.workspace)}-sqlmonmon-01-nic"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  ip_configuration {
    name                          = "azw-${lookup(var.penv,terraform.workspace)}-sqlmon-01-ipconf"
    subnet_id                     = "${lookup(var.sql_subnet_id,terraform.workspace)}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${element(azurerm_public_ip.sql.*.id, count.index)}"
  }
}

resource "azurerm_storage_account" "sql" {
  name                     = "azw${lookup(var.penv,terraform.workspace)}sqlmon01s"
  resource_group_name      = "${azurerm_resource_group.rg.name}"
  location                 = "${azurerm_resource_group.rg.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "sql" {
  name                  = "vhds"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  storage_account_name  = "${azurerm_storage_account.sql.name}"
  container_access_type = "private"
}

resource "azurerm_storage_account" "sqlp" {
  name                     = "azw${lookup(var.penv,terraform.workspace)}sqlmon01p"
  resource_group_name      = "${azurerm_resource_group.rg.name}"
  location                 = "${azurerm_resource_group.rg.location}"
  account_tier             = "Premium"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "sqlp" {
  name                  = "vhds"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  storage_account_name  = "${azurerm_storage_account.sqlp.name}"
  container_access_type = "private"
}

resource "azurerm_virtual_machine" "sql" {
  name                  = "azw-${lookup(var.penv,terraform.workspace)}-sqlmon-01"
  location              = "${azurerm_resource_group.rg.location}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  network_interface_ids = ["${azurerm_network_interface.sql.id}"]
  vm_size               = "${var.sql_vm_size}"

  delete_os_disk_on_termination    = false
  delete_data_disks_on_termination = false

  provisioner "local-exec" {
    when    = "destroy"
    command = "knife node delete azw-${lookup(var.penv,terraform.workspace)}-sqlmon-01-${azurerm_resource_group.rg.name} -y; knife client delete azw-${lookup(var.penv,terraform.workspace)}-sqlmon-01-${azurerm_resource_group.rg.name} -y"
  }

  storage_image_reference {
    publisher = "${var.win_image_publisher}"
    offer     = "${var.win_image_offer}"
    sku       = "${var.win_image_sku}"
    version   = "${var.win_image_version}"
  }

  storage_os_disk {
    name          = "osdisk"
    vhd_uri       = "${azurerm_storage_account.sql.primary_blob_endpoint}${azurerm_storage_container.sql.name}/osdisk.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  storage_data_disk {
    name          = "datadisk-0"
    vhd_uri       = "${azurerm_storage_account.sqlp.primary_blob_endpoint}${azurerm_storage_container.sqlp.name}/datadisk-0.vhd"
    disk_size_gb  = "1024"
    create_option = "Empty"
    lun           = 0
  }

  os_profile {
    computer_name  = "azw-${lookup(var.penv,terraform.workspace)}-sqlmon-01"
    admin_username = "${local.admin_user}"
    admin_password = "${local.admin_password}"
  }

  os_profile_windows_config {
    provision_vm_agent = "true"
  }

  tags {
    environment = "${lookup(var.environment_name,terraform.workspace)}"
  }
}

resource "azurerm_virtual_machine_extension" "sql" {
  name                       = "ChefClient"
  location                   = "${azurerm_resource_group.rg.location}"
  resource_group_name        = "${azurerm_resource_group.rg.name}"
  virtual_machine_name       = "${azurerm_virtual_machine.sql.name}"
  publisher                  = "Chef.Bootstrap.WindowsAzure"
  type                       = "ChefClient"
  type_handler_version       = "1210.12"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
  {
    "client_rb": "ssl_verify_mode :verify_none",
    "bootstrap_version": "${var.chef_client_version}",
    "bootstrap_options": {
      "chef_node_name": "${azurerm_virtual_machine.sql.name}-${azurerm_resource_group.rg.name}",
      "chef_server_url": "${var.chef_server_url}",
      "environment": "${lookup(var.chef_environment,terraform.workspace)}",
      "validation_client_name": "${var.chef_user_name}"
    },
    "custom_json_attr": {
      "dvo_user": {
        "ALM_environment": "${lookup(var.environment_name,terraform.workspace)}"
      }
     },
     "runlist": "${var.sql_chef_runlist}"
  }
  SETTINGS

  protected_settings = <<SETTINGS
  {
    "validation_key": "${file("${path.module}/secrets/validation.pem")}",
    "secret": "${file("${path.module}/secrets/database_secret")}"
  }
  SETTINGS
}
