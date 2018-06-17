# Terraform Azure scripts for Jenkins HA

Setup you private Azure creds before running the script :

```
subscription_id     = "---"
client_id           = "---"
client_secret       = "---"
tenant_id           = "---"
```

Note: Above should be stored in a file called terraform.tfvars

## Terraform Files

The following table describes the terraform files and their purpose.  

| File                | Description       | 
| ------------------- | ----------------- | 
| variables.tf      | Contains variables and config values used for deployment| 
| provider.tf       | Contains provider settings     |
| rsg.tf       | Contains resource group settings     |
| nsg.tf            | Contains network security group     |   
| network.tf       | Contains network settings     |
| storage.tf       | Contains storage account settings     |
| vm-master-primary.tf       | Jenkins master virtual machine (Primary)     |
| vm-master-secondary.tf       | Jenkins master virtual machine (Secondary)     |

Note: variables.tf should be customized for your specific settings

##### Steps to initialize this project
- Enter all the variables in variable file (terraform.tfvars)
- Add storage account , container name , Access Key at the end of  azure_vm.tf file for storing terraform state file remotely to azure (you need to have a already created storage account for storing the state file )

Run following commands to run & test Terraform scripts :

- terraform init        (To initialize the project)
- terraform plan        (To check the changes to be made by Terraform on azure )
- terraform apply       (To apply the changes to azure)


To verify Jenkins , open the public ip Azure VM in browser
```azure_vm_public_ip:8080```    
& get Jenkins Admin password by SSHing the VM

- The Backend state file will be stored on your azure storage container.
- This file can be used for next module .

## Virtual Machine (Configuration)
The following is the configuration for the virtual machine produced using these scripts

VM Size: Standard_DS2_v2

Operating System: Linux Cent OS 7.3

Disk: 

    - OS Disk : 128GB
    - Data Disk : 512GB