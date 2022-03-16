resource "random_password" "AdminPassword" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "azurerm_resource_group" "dev" {
  name     = "${var.resource_group_name_prefix}-resource-group"
  location = var.resource_group_location
  tags     = merge(local.common_tags)
}

resource "azurerm_key_vault" "dev" {
  name                       = "${var.resource_group_name_prefix}-key-vault"
  location                   = azurerm_resource_group.dev.location
  resource_group_name        = azurerm_resource_group.dev.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "create",
      "get",
    ]

    secret_permissions = [
      "set",
      "get",
      "list",
      "delete",
      "purge",
      "recover"
    ]
  }

  tags = merge(local.common_tags)
}

resource "azurerm_key_vault_secret" "AdminPassword" {
  name         = "AdminPassword"
  value        = random_password.AdminPassword.result # random_password.password.result
  key_vault_id = azurerm_key_vault.dev.id
}

resource "azurerm_storage_account" "dev" {
  name                     = "${var.resource_group_name_prefix}storaccount"
  resource_group_name      = azurerm_resource_group.dev.name
  location                 = azurerm_resource_group.dev.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_blob_public_access = true

  tags = merge(local.common_tags)
}

resource "azurerm_storage_blob" "dev" {
  name                   = "install.sh"
  storage_account_name   = azurerm_storage_account.dev.name
  storage_container_name = azurerm_storage_container.dev.name
  type                   = "Block"
  source                 = "install.sh"
}

resource "azurerm_storage_container" "dev" {
  name                  = "${var.resource_group_name_prefix}-storage-container"
  storage_account_name  = azurerm_storage_account.dev.name
  container_access_type = "blob"
}

resource "azurerm_virtual_network" "dev" {
  name                = "${var.resource_group_name_prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name

  tags = merge(local.common_tags)
}

resource "azurerm_subnet" "dev" {
  name                 = "${var.resource_group_name_prefix}-network-internal"
  resource_group_name  = azurerm_resource_group.dev.name
  virtual_network_name = azurerm_virtual_network.dev.name
  address_prefixes     = ["10.0.2.0/24"]

}

resource "azurerm_public_ip" "dev" {
  name                = "${var.resource_group_name_prefix}-ip-public"
  resource_group_name = azurerm_resource_group.dev.name
  location            = azurerm_resource_group.dev.location
  allocation_method   = "Static"

  tags = merge(local.common_tags)
}

resource "azurerm_network_interface" "dev" {
  name                = "${var.resource_group_name_prefix}-nic"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dev.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.dev.id
  }

  tags = merge(local.common_tags)
}

resource "azurerm_linux_virtual_machine" "dev" {
  name                            = "${var.resource_group_name_prefix}-vm"
  resource_group_name             = azurerm_resource_group.dev.name
  location                        = azurerm_resource_group.dev.location
  size                            = "Standard_B1s"
  admin_username                  = var.resource_group_name_prefix
  disable_password_authentication = false
  admin_password                  = azurerm_key_vault_secret.AdminPassword.value
  network_interface_ids = [
    azurerm_network_interface.dev.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  tags = merge(local.common_tags)
}


resource "azurerm_dev_test_global_vm_shutdown_schedule" "dev" {
  virtual_machine_id = azurerm_linux_virtual_machine.dev.id
  location           = azurerm_resource_group.dev.location
  enabled            = true

  daily_recurrence_time = "1900"
  timezone              = "Russian Standard Time"


  notification_settings {
    enabled = true
    email   = var.owner

  }

  tags = merge(local.common_tags)
}

resource "azurerm_virtual_machine_extension" "dev" {
  name                 = "InitialScript"
  virtual_machine_id   = azurerm_linux_virtual_machine.dev.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"
  settings = jsonencode({
    "fileUris" : ["https://${azurerm_storage_account.dev.name}.blob.core.windows.net/${azurerm_storage_container.dev.name}/${azurerm_storage_blob.dev.name}"],
    "commandToExecute" = "sh install.sh"
    }
  )
}

resource "azurerm_sql_server" "dev" {
  name                         = "${var.resource_group_name_prefix}-mssql-server"
  resource_group_name          = azurerm_resource_group.dev.name
  location                     = azurerm_resource_group.dev.location
  version                      = "12.0"
  administrator_login          = var.resource_group_name_prefix
  administrator_login_password = azurerm_key_vault_secret.AdminPassword.value

  tags = merge(local.common_tags)
}

resource "azurerm_sql_database" "dev" {
  name                = "${var.resource_group_name_prefix}-mssql-database"
  resource_group_name = azurerm_resource_group.dev.name
  location            = azurerm_resource_group.dev.location
  server_name         = azurerm_sql_server.dev.name

  tags = merge(local.common_tags)
}
