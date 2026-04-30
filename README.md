# Terraform-AWS-Two-Tier-Architecture-EC2-RDS
This repository contains the Terraform configuration to provision the entire AWS infrastructure for the EpicBook full-stack bookstore application. The application uses Node.js for the backend, MySQL on Amazon RDS, and runs on an EC2 instance inside a custom VPC with public and private subnets.

Everything is defined as code – reproducible, versionable, and easy to tear down.

## 📘 Architecture Overview

<p align="center">
  <img src="https://github.com/Jayanidu-Abeysinghe/Terraform-AWS-Two-Tier-Architecture-EC2-RDS/blob/main/Images/Architecture%20diagram.png" width="800"><br><br>
  <em>Architecture Diagram</em>
</p>

```text
Internet
   |
Internet Gateway
   |
Public Subnet (10.0.1.0/24)           Private Subnet A (10.0.2.0/24)
   |                                      |
EC2 Instance (Web Server)                 RDS MySQL Database
   |                                      |
Web Server Security Group                 DB Security Group
   (allows 0.0.0.0/0:80,8080,22)          (allows 3306 from Web SG)
   └──────────────────────────────────────┘
```



- VPC – Isolated network with CIDR 10.0.0.0/16
- Public Subnet – Hosts the EC2 instance, has a route to the Internet Gateway
- Private Subnets – Two subnets (us-east-1a and us-east-1b) for the RDS database (Multi-AZ ready)
- Internet Gateway – Provides outbound internet access for the public subnet
- Security Groups:
  - epicbook-sg: Allows HTTP (80), application port (8080), and SSH (22) from anywhere
  - rds-mysql-sg: Allows MySQL (3306) only from the web server’s security group
- EC2 Instance – t2.micro Ubuntu 20.04 running the Node.js/Express app
- RDS MySQL – db.t3.micro, 20 GB storage, not publicly accessible

All resources are tagged for easy identification.

## 🧱 Resources Created by Terraform

| Resource Type | Name | Purpose |
|---|---|---|
| aws_vpc | epicbook_vpc | Isolated network |
| aws_subnet (public) | public_subnet | EC2 placement (auto-assign public IP) |
| aws_subnet (private) | private_subnet | DB subnet A (us-east-1a) |
| aws_subnet (private) | private_subnet_b | DB subnet B (us-east-1b) |
| aws_internet_gateway | epicbook_igw | Public internet access |
| aws_route_table (public) | epicbook_public_rt | Route 0.0.0.0/0 via IGW |
| aws_route_table (private) | epicbook_private_rt | Local routing only |
| aws_security_group | epicbook_sg | Web server firewall rules |
| aws_security_group | rds_sg | DB firewall (allow 3306 from web SG) |
| aws_key_pair | ssh_key | SSH key pair using local ~/.ssh/id_rsa.pub |
| aws_instance | epicbook_vm | EC2 web server |
| aws_db_subnet_group | db_subnet | Subnet group for RDS |
| aws_db_instance | mysql | MySQL 8.0 database |

## Prerequisites

- AWS Account with programmatic access (Access Key ID + Secret Access Key)
- Terraform >= 1.0 (Installation guide: https://developer.hashicorp.com/terraform/downloads)
- AWS CLI (Installation guide: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- SSH Key Pair – A public key at ~/.ssh/id_rsa.pub.
  If you don’t have one, generate it:

  ```bash
  ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
  ```

- Git (optional, to clone the repository)

> Important: Never hardcode AWS credentials in Terraform files. Use environment variables.

## 🚀 Deployment Guide

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd epicbook-terraform
```

### 2. Configure AWS Credentials

Set your credentials as environment variables (recommended):

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

If you initially had hardcoded keys in main.tf, remove them now. The provider block should look like:

```hcl
provider "aws" {
  region = "us-east-1"
}
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review the Execution Plan

```bash
terraform plan
```

Verify that Terraform will create the VPC, subnets, EC2, RDS, etc.

### 5. Apply the Configuration

```bash
terraform apply
```

Type "yes" when prompted.
Creation takes about 5–6 minutes (mainly the RDS database).
At the end you will see outputs similar to:

<p align="center">
  <img src="https://github.com/Jayanidu-Abeysinghe/Terraform-AWS-Two-Tier-Architecture-EC2-RDS/blob/main/Images/Img1.png" width="800"><br><br>
  <em>Apply the Configuration</em>
</p>

```text
instance_public_ip = "100.26.211.201"
database_endpoint = "terraform-2026...amazonaws.com:3306"
```

## 🛠️ Application Deployment on EC2

The Terraform code only creates the infrastructure. You must manually set up the application on the EC2 instance.

### 6. SSH into the Instance

```bash
ssh -i ~/.ssh/id_rsa ubuntu@<instance_public_ip>
```

### 7. Install Node.js (if not already available)

```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 8. Clone Your Application Repository (or upload your code)

```bash
git clone <your-app-repo>
cd <app-directory>
```

### 9. Configure Environment Variables

Create a .env file with your database connection details. Use the database_endpoint output without the :3306 port as the host.

```bash
echo 'DB_HOST=<rds_endpoint_without_port>
DB_PORT=3306
DB_USER=admin
DB_PASSWORD=StrongPassword123!
DB_NAME=epicbook' > .env
```

### 10. Install Dependencies and Start the Application

```bash
npm install
npm run start    # or node server.js
```

If your app uses Sequelize, make sure config/config.js reads from .env:

```javascript
require('dotenv').config();
module.exports = {
  development: {
    username: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    host: process.env.DB_HOST,
    dialect: "mysql"
  }
};
```

Then run migrations:

```bash
npx sequelize-cli db:migrate
```

### 11. (Optional) Keep the App Running in the Background

Use a process manager like pm2:

```bash
npm install -g pm2
pm2 start server.js
pm2 save
pm2 startup
```

## Testing the Application

Open a browser and navigate to:

http://<instance_public_ip>:8080

You should see the EpicBook! storefront (see screenshot: Screenshot 2026-04-18 233451.png).
Add a book to your cart, proceed to checkout – the application will interact with the RDS database.

Verify database connectivity from inside the EC2 instance:

setting up mysql client on your local machine

```bash
sudo apt update
sudo apt install mysql-client -y
```

```bash
mysql -h <rds_endpoint> -u admin -p epicbook
```
<p align="center">
  <img src="https://github.com/Jayanidu-Abeysinghe/Terraform-AWS-Two-Tier-Architecture-EC2-RDS/blob/main/Images/Img2.png" width="800"><br><br>
  <em>Database Logs</em>
</p>

## Cleanup

To avoid ongoing costs, destroy the entire environment when you are done:

```bash
terraform destroy
```

Confirm with yes. All resources (VPC, subnets, EC2, RDS, etc.) will be permanently deleted.

## Repository File Structure

```text
.
├── main.tf                  # Full Terraform configuration
├── .terraform/              # Provider plugins (after terraform init)
├── .terraform.lock.hcl      # Dependency lock file
├── terraform.tfstate        # Local state file (DO NOT COMMIT to git!)
└── screenshots/             # Architecture diagram, terminal logs, website
    ├── P1-1.png
    ├── Screenshot 2026-04-18 233414.png
    ├── Screenshot 2026-04-18 233451.png
    └── Screenshot 2026-04-18 233856.png
```


## Security Considerations

- Never commit AWS credentials to version control. Use environment variables.
- The RDS password is stored in plaintext inside main.tf (for demo purposes). In production, use Terraform variables, a .tfvars file (git‑ignored), or AWS Secrets Manager.
- The SSH port (22) is open to 0.0.0.0/0. Restrict it to your own IP address in the security group.
- Add the following to your .gitignore:

  ```text
  terraform.tfstate
  terraform.tfstate.backup
  .terraform/
  *.tfvars
  ```

## Notes / Troubleshooting

- AMI Filter: Uses the latest official Ubuntu 20.04 AMI from Canonical. If it changes, update the filter.
- Region: All resources are in us-east-1. Change the provider’s region to deploy elsewhere.
- RDS Creation Time: The DB instance takes about 5 minutes. Do not interrupt the process.
- State File: terraform.tfstate contains sensitive info. Do not commit it. For team use, configure a remote backend with state locking (e.g., S3 + DynamoDB).
- MySQL Client (optional): To test DB connectivity from your local machine:

  ```bash
  sudo apt update && sudo apt install mysql-client -y
  mysql -h <rds_endpoint> -u admin -p
  ```

## Contributing

Feel free to fork this repository and adapt it to your own projects. Pull requests are welcome.

## License

This project is intended for educational purposes. You are free to use and modify it as you wish.

Now you can recreate the entire EpicBook deployment with just a few commands. Happy building!
