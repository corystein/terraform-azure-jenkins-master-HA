resource "azurerm_public_ip" "jenkins_master_primary_pip" {
  name                         = "jenkins-master-primary-pip"
  location                     = "${azurerm_resource_group.res_group.location}"
  resource_group_name          = "${azurerm_resource_group.res_group.name}"
  public_ip_address_allocation = "static"
}

resource "azurerm_network_interface" "jenkins_master_primary_nic" {
  name                = "${var.config["jenkins_master_primrary_nic"]}"
  resource_group_name = "${azurerm_resource_group.res_group.name}"
  location            = "${azurerm_resource_group.res_group.location}"

  ip_configuration {
    name = "ipconfig1"

    #private_ip_address_allocation = "static"
    private_ip_address_allocation           = "dynamic"
    subnet_id                               = "${azurerm_subnet.subnet1.id}"
    public_ip_address_id                    = "${azurerm_public_ip.jenkins_master_primary_pip.id}"
    load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.jenkins_lb_backend.id}"]

    #load_balancer_inbound_nat_rules_ids     = ["${azurerm_lb_rule.lb_rule.id}"]

    #private_ip_address            = "${var.config["jenkins_master_primary_ip_address"]}"
  }
}

resource "azurerm_virtual_machine" "jenkins_master_primary_vm" {
  name                  = "${var.config["jenkins_master_primary_vmname"]}"
  resource_group_name   = "${azurerm_resource_group.res_group.name}"
  location              = "${azurerm_resource_group.res_group.location}"
  availability_set_id   = "${azurerm_availability_set.avset.id}"
  network_interface_ids = ["${azurerm_network_interface.jenkins_master_primary_nic.id}"]
  vm_size               = "${var.config["jenkins_master_vmsize"]}"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "${var.config["jenkins_master_vm_image_publisher"]}"
    offer     = "${var.config["jenkins_master_vm_image_offer"]}"
    sku       = "${var.config["jenkins_master_vm_image_sku"]}"
    version   = "${var.config["jenkins_master_vm_image_version"]}"
  }
  storage_os_disk {
    name = "jenkins-master-primary-osdisk"

    #vhd_uri           = "${azurerm_storage_account.jenkins_storage.primary_blob_endpoint}${azurerm_storage_container.jenkins_cont.name}/osdisk-1.vhd"
    caching           = "ReadWrite"
    managed_disk_type = "Standard_LRS"
    create_option     = "FromImage"
    disk_size_gb      = "128"
  }
  storage_data_disk {
    name              = "jenkins-master-primary-data-disk"
    managed_disk_type = "Standard_LRS"
    create_option     = "Empty"
    lun               = 0
    disk_size_gb      = "512"
  }
  os_profile {
    computer_name  = "${var.config["os_name"]}"
    admin_username = "${var.config["vm_username"]}"
    admin_password = "${var.config["vm_password"]}"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
}

resource "azurerm_virtual_machine_extension" "jenkins_terraform" {
  name                 = "jenkins_extension"
  location             = "${azurerm_resource_group.res_group.location}"
  resource_group_name  = "${azurerm_resource_group.res_group.name}"
  virtual_machine_name = "${azurerm_virtual_machine.jenkins_master_primary_vm.name}"
  publisher            = "Microsoft.OSTCExtensions"
  type                 = "CustomScriptForLinux"
  type_handler_version = "1.2"

  settings = <<SETTINGS
  {
          "fileUris": ["https://raw.githubusercontent.com/corystein/terraform-azure-jenkins-master-HA/master/scripts/jenkinsInstall.sh"],
          "commandToExecute": "sh jenkinsInstall.sh"
      }
SETTINGS
}
