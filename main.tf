resource "azurerm_resource_group" "test" {
 name     = "acctestrg"
 location = "Canada East"
}

resource "azurerm_virtual_network" "test" {
 name                = "acctvn"
 address_space       = ["10.0.0.0/16"]
 location            = "${azurerm_resource_group.test.location}"
 resource_group_name = "${azurerm_resource_group.test.name}"
}

resource "azurerm_subnet" "test" {
 name                 = "acctsub"
 resource_group_name  = "${azurerm_resource_group.test.name}"
 virtual_network_name = "${azurerm_virtual_network.test.name}"
 address_prefix       = "10.0.0.0/24"
}

resource "azurerm_public_ip" "test" {
 name                         = "publicIPForLB"
 location                     = "${azurerm_resource_group.test.location}"
 resource_group_name          = "${azurerm_resource_group.test.name}"
 public_ip_address_allocation = "static"
}

resource "azurerm_lb" "test" {
 name                = "loadBalancer"
 location            = "${azurerm_resource_group.test.location}"
 resource_group_name = "${azurerm_resource_group.test.name}"

 frontend_ip_configuration {
   name                 = "publicIPAddress"
   public_ip_address_id = "${azurerm_public_ip.test.id}"
 }
}

resource "azurerm_lb_backend_address_pool" "test" {
 resource_group_name = "${azurerm_resource_group.test.name}"
 loadbalancer_id     = "${azurerm_lb.test.id}"
 name                = "BackEndAddressPool"
}

resource "azurerm_network_security_group" "test" {
    name                = "myNetworkSecurityGroup"
    location            = "${azurerm_resource_group.test.location}"
    resource_group_name = "${azurerm_resource_group.test.name}"

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags {
        environment = "staging"
    }
}

resource "azurerm_network_interface" "test" {
 count               = 2
 name                = "acctni${count.index}"
 location            = "${azurerm_resource_group.test.location}"
 resource_group_name = "${azurerm_resource_group.test.name}"
 network_security_group_id = "${azurerm_network_security_group.test.id}"

 ip_configuration {
   name                          = "testConfiguration"
   subnet_id                     = "${azurerm_subnet.test.id}"
   private_ip_address_allocation = "dynamic"
   load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.test.id}"]
 }
}

resource "azurerm_managed_disk" "test" {
 count                = 2
 name                 = "datadisk_existing_${count.index}"
 location             = "${azurerm_resource_group.test.location}"
 resource_group_name  = "${azurerm_resource_group.test.name}"
 storage_account_type = "Standard_LRS"
 create_option        = "Empty"
 disk_size_gb         = "300"
}

resource "azurerm_availability_set" "avset" {
 name                         = "avset"
 location                     = "${azurerm_resource_group.test.location}"
 resource_group_name          = "${azurerm_resource_group.test.name}"
 platform_fault_domain_count  = 2
 platform_update_domain_count = 2
 managed                      = true
}

resource "azurerm_virtual_machine" "test" {
 count                 = 2
 name                  = "acctvm${count.index}"
 location              = "${azurerm_resource_group.test.location}"
 availability_set_id   = "${azurerm_availability_set.avset.id}"
 resource_group_name   = "${azurerm_resource_group.test.name}"
 network_interface_ids = ["${element(azurerm_network_interface.test.*.id, count.index)}"]
 vm_size               = "Standard_D1_V2"
 delete_os_disk_on_termination = true
 delete_data_disks_on_termination = true

 storage_image_reference {
   publisher = "OpenLogic"
   offer     = "CentOS"
   sku       = "7.4"
   version   = "latest"
 }

 storage_os_disk {
   name              = "myosdisk${count.index}"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

 # Optional data disks
 storage_data_disk {
   name              = "datadisk_new_${count.index}"
   managed_disk_type = "Standard_LRS"
   create_option     = "Empty"
   lun               = 0
   disk_size_gb      = "300"
 }

 storage_data_disk {
   name            = "${element(azurerm_managed_disk.test.*.name, count.index)}"
   managed_disk_id = "${element(azurerm_managed_disk.test.*.id, count.index)}"
   create_option   = "Attach"
   lun             = 1
   disk_size_gb    = "${element(azurerm_managed_disk.test.*.disk_size_gb, count.index)}"
 }

 os_profile {
   computer_name  = "hostname"
   admin_username = "venerari"
 }

 os_profile_linux_config {
   disable_password_authentication = false
   ssh_keys {
       path =  "/home/venerari/.ssh/authorized_keys"
       key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDPj8ZTnznnsJ7PfLckx8Xp6UMm9tr1Mj8KV6/Ki0S0aJ9dZOT+ayAfZDYf88m+RnaUnYiEu1cDl3vuM1Yr8PR/hwnzuPRIFvserxoJZTwxgy5XvvQMRlVxgV3LBINmD5L/PPuVvqpdZLWzhbWENQjar4IG+JdvnZdP2ncYocVQglSmKQXaz/Xz/xdaaTsYAuHeeuXlqoLWDWb0pPTAmau7I/G+urORs6lkH+dwvfZe7NuMNjFBnbvOB38XhaqbF5/y0EVgiy1IbXXX96wcZzXMbUpmojWExySfV1ZOJzzKQiLM51m7DWdra89bjnORUGDMCKBxoqOjImiTDWxk+FnJ venerari@sdcgigdcapmdw01"
   }
 }

 tags {
   environment = "staging"
 }
}
