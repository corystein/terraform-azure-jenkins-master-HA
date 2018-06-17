/* This terraform configuration creates storage account on Azure & creates a container for storing virtual machine HD image */

resource "azurerm_storage_account" "jenkins_storage" {
  name                     = "${var.config["storage_account_name"]}"
  resource_group_name      = "${azurerm_resource_group.res_group.name}"
  location                 = "${azurerm_resource_group.res_group.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "jenkins_cont" {
  name                  = "${var.config["container_name"]}"
  resource_group_name   = "${azurerm_resource_group.res_group.name}"
  storage_account_name  = "${azurerm_storage_account.jenkins_storage.name}"
  container_access_type = "private"
}
