# DevOps Internship: Terraform Task 2
## Hometask

* Написать terraform манифест для разворачивания AWS EC2/Azure VM. Этот инстанс должен содержать nginx. Nginx должен быть установлен во время провиженинга инстанса, например с помощью user data.
* (Дополнительно) Добавить в манифест код для создания базы данных AWS RDS/Azure Database. Тип базы на ваше усмотрение. 


## Solution
The task is completely solved with the help of Terraform

Components:
* Resource group
* Key vault secret
* Storage:
    * Account
    * Container
    * Blob
* Virtual network
* Subnet
* Public ip
* Network interface
* Windows virtual machine
* Virtual machine:
    * Shutdown schedule
    * Extension
* SQL
    * Server
    * Database


## Terraform Commands
### Azure Authentication

```bash
az login
```

### Create
```bash
terraform init
terraform plan -out main.tfplan
terraform apply main.tfplan
```

### Destroy
```bash
terraform plan -destroy -out main.destroy.tfplan
terraform apply main.destroy.tfplan
```