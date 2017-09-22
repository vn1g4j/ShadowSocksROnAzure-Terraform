variable "myip" {
    default = "0.0.0.0/0"
}

variable "sshpassword" {
    default = "aslongaspossible"
}

variable "sspassword" {
    default = "password123321"
}

variable "cryptor_method" {
    default = "aes-256-cfb"
}

variable "auth_method" {
    default = "auth_aes128_md5"
}

variable "obfs_method" {
    default = "tls1.2_ticket_auth"
}

variable "port" {
    default = "443"
}

# Southeast Asia	Singapore
# East Asia	Hong Kong
# Australia East	New South Wales
# Australia Southeast	Victoria
# China East	Shanghai
# China North	Beijing
# Central India	Pune
# West India	Mumbai
# South India	Chennai
# Japan East	Tokyo, Saitama
# Japan West	Osaka
# Korea Central	Seoul
# Korea South	Busan
variable "region" {
    default = "East Asia"
}


# Configure the Microsoft Azure Provider
provider "azurerm" {
    subscription_id = ""
    client_id       = ""
    client_secret   = ""
    tenant_id       = ""
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "ss" {
    name     = "ssgroup"
    location = "${var.region}"

    tags {
        environment = "Terraform SS"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "${var.region}"
    resource_group_name = "${azurerm_resource_group.ss.name}"

    tags {
        environment = "Terraform SS"
    }
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
    name                 = "mySubnet"
    resource_group_name  = "${azurerm_resource_group.ss.name}"
    virtual_network_name = "${azurerm_virtual_network.myterraformnetwork.name}"
    address_prefix       = "10.0.0.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "myPublicIP"
    location                     = "${var.region}"
    resource_group_name          = "${azurerm_resource_group.ss.name}"
    public_ip_address_allocation = "dynamic"

    tags {
        environment = "Terraform SS"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "myNetworkSecurityGroup"
    location            = "${var.region}"
    resource_group_name = "${azurerm_resource_group.ss.name}"

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "${var.myip}"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "SS"
        priority                   = 1000
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "${var.myip}"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "Outbound"
        priority                   = 999
        direction                   = "Outbound"
        access                      = "Allow"
        protocol                    = "Tcp"
        source_port_range           = "*"
        destination_port_range      = "*"
        source_address_prefix       = "*"
        destination_address_prefix  = "*"
    }

    tags {
        environment = "Terraform SS"
    }
}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
    name                      = "myNIC"
    location                  = "${var.region}"
    resource_group_name       = "${azurerm_resource_group.ss.name}"
    network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = "${azurerm_subnet.myterraformsubnet.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id          = "${azurerm_public_ip.myterraformpublicip.id}"
    }

    tags {
        environment = "Terraform SS"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.ss.name}"
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                = "diag${random_id.randomId.hex}"
    resource_group_name = "${azurerm_resource_group.ss.name}"
    location            = "${var.region}"
    account_type        = "Standard_LRS"

    tags {
        environment = "Terraform SS"
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "myterraformvm" {
    name                  = "ssvm"
    location              = "${var.region}"
    resource_group_name   = "${azurerm_resource_group.ss.name}"
    network_interface_ids = ["${azurerm_network_interface.myterraformnic.id}"]
    vm_size               = "Basic_A0"

    storage_os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "ssvm"
        admin_username = "azureuser"
        admin_password = "${var.sshpassword}"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    tags {
        environment = "Terraform SS"
    }
}

data "azurerm_public_ip" "datasourceip" { name = "myPublicIP" resource_group_name = "${azurerm_virtual_machine.myterraformvm.resource_group_name}" }

resource "null_resource" "init_ss" {
    triggers {
        instance = "${azurerm_virtual_machine.myterraformvm.id}"
    }
    connection {
                user = "azureuser"
                password = "${var.sshpassword}"
                host = "${data.azurerm_public_ip.datasourceip.ip_address}"
                type = "ssh"
            }
    provisioner "remote-exec" {
        inline = [
            "sudo apt-get install -y git",
            "sudo git clone https://github.com/shadowsocksr-backup/shadowsocksr.git",
            "cd ~/shadowsocksr",
            "sudo git checkout manyuser",
            "sudo bash initcfg.sh",
            "sudo python shadowsocks/server.py -p ${var.port} -k ${var.sspassword} -m ${var.cryptor_method} -O ${var.auth_method} -o ${var.obfs_method} -d start"
        ]
    }
}

output "address" {
    value = "${data.azurerm_public_ip.datasourceip.ip_address}"
}