resource "azurerm_public_ip" "sql" {
  name                         = "azw-${lookup(var.penv,terraform.workspace)}-sqmn-01-pubip"
  location                     = "${azurerm_resource_group.rg.location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  public_ip_address_allocation = "dynamic"
  domain_name_label            = "azw-${lookup(var.penv,terraform.workspace)}-sqmn-01-${lower(azurerm_resource_group.rg.name)}"
}

resource "azurerm_network_interface" "sql" {
  name                = "azw-${lookup(var.penv,terraform.workspace)}-sqmn-${format("%02d", count.index+1)}-nic"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  count                        = "${lookup(var.count_sql_vms,terraform.workspace)}"

  ip_configuration {
    name                          = "azw-${lookup(var.penv,terraform.workspace)}-sqmn-${format("%02d", count.index+1)}-ipconf"
    subnet_id                     = "${lookup(var.sql_subnet_id,terraform.workspace)}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.sql.*.id[count.index]}"
  }
}

resource "azurerm_virtual_machine" "sql" {
  name                  = "azw-${lookup(var.penv,terraform.workspace)}-sqmn-01"
  location              = "${azurerm_resource_group.rg.location}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  network_interface_ids = ["${azurerm_network_interface.sql.id}"]
  vm_size               = "${var.sql_vm_size}"

  delete_os_disk_on_termination    = false
  delete_data_disks_on_termination = false

  provisioner "local-exec" {
    when    = "destroy"
    command = "knife node delete azw-${lookup(var.penv,terraform.workspace)}-sqmn-01-${azurerm_resource_group.rg.name} -y; knife client delete azw-${lookup(var.penv,terraform.workspace)}-sqmn-01-${azurerm_resource_group.rg.name} -y"
  }

  storage_image_reference {
    publisher = "${var.win_image_publisher}"
    offer     = "${var.win_image_offer}"
    sku       = "${var.win_image_sku}"
    version   = "${var.win_image_version}"
  }

  storage_os_disk {
    name          = "azw-${lookup(var.penv,terraform.workspace)}-sqlmn-${format("%02d", count.index+1)}-osdisk"
    managed_disk_type = "Standard_LRS"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

storage_data_disk {
    name          = "azw-${lookup(var.penv,terraform.workspace)}-sqlmn-${format("%02d", count.index+1)}-datadisk-0"
    managed_disk_type = "Standard_LRS"
    disk_size_gb  = "979"
    create_option = "Empty"
    lun           = 0
  }

  os_profile {
    computer_name  = "azw-${lookup(var.penv,terraform.workspace)}-sqmn-01"
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

resource "azurerm_virtual_machine_extension" "sql_disk_setup" {
  name                 = "disksetup"
  location             = "${azurerm_resource_group.rg.location}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  virtual_machine_name = "${azurerm_virtual_machine.sql.name}"
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  settings = <<SETTINGS
    {
      "fileUris": ["https://aztrksa0qyat0bootscripts.blob.core.windows.net/custom-script-extension-scripts/Windows/disk_setup_windows.ps1"],
      "commandToExecute": "powershell.exe -executionpolicy Unrestricted -File \"./Windows/disk_setup_windows.ps1\""
    }
SETTINGS

  protected_settings = <<SETTINGS
    {
      "storageAccountName": "aztrksa0qyat0bootscripts",
      "storageAccountKey": "${local.script_storage_key}"
    }
SETTINGS

  tags {
    environment = "Terraform"
  }
}

resource "azurerm_virtual_machine_extension" "adjoin" {
  name                 = "adjoin"
  location             = "${azurerm_resource_group.rg.location}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  virtual_machine_name = "${azurerm_virtual_machine.sql.name}"
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"
  depends_on           = ["azurerm_virtual_machine_extension.sql_disk_setup"]

  # NOTE: the `OUPath` field is intentionally blank, to put it in the Computers OU
  settings = <<SETTINGS
    {
        "Name": "trek.web",
        "OUPath": "",
        "User": "trek.web\\${local.ad_user}",
        "Restart": "true",
        "Options": "3"
    }
SETTINGS

  protected_settings = <<SETTINGS
    {
        "Password": "${local.ad_password}"
    }
SETTINGS
}

resource "null_resource" "sql_mon_bootstrap" {
  count      = "${lookup(var.count_sql_vms,terraform.workspace)}"
  depends_on = [
    "azurerm_virtual_machine_extension.adjoin",
  ]

  triggers{
    sql_mon_bootstrap_instance = "${azurerm_virtual_machine.sql.*.id[count.index]}"
  }

  provisioner "local-exec" {
    command = <<BOOTSTRAP
      sleep $((10 * ${count.index})) && \
      ssh-keygen -R ${azurerm_network_interface.sql.*.private_ip_address[count.index]} && \
      knife bootstrap windows winrm ${azurerm_network_interface.sql.*.private_ip_address[count.index]} \
        -N ${azurerm_virtual_machine.sql.*.name[count.index]}-${azurerm_resource_group.rg.name} \
        --bootstrap-version ${var.chef_client_version} \
        --environment ${lookup(var.chef_environment,terraform.workspace)} \
        -x ${local.admin_user} -P ${local.admin_password} \
        --run-list '${var.base_runlist}' \
        --bootstrap-vault-item 'infrastructure-vaults:credentials' \
        --bootstrap-vault-item 'infrastructure-vaults:sumologic' \
        --node-ssl-verify-mode none --yes && \
      knife tag create ${azurerm_virtual_machine.sql.*.name[count.index]}-${azurerm_resource_group.rg.name} hybris_sql_mon
    BOOTSTRAP
  }
}
