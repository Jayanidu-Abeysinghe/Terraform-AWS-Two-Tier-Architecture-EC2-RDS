provider "aws" {
    region = "us-east-1"
    access_key = ""
    secret_key = ""     
}

resource "aws_vpc" "epicbook_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "epicbook-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.epicbook_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true     # EC2  automatically get public IP when launched in this subnet
   
  tags = {
    Name = "epicbook-public-subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.epicbook_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "epicbook-private-subnet"
  }
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id            = aws_vpc.epicbook_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "epicbook-private-subnet-b"
  }
}

resource "aws_internet_gateway" "epicbook_igw" {
  vpc_id = aws_vpc.epicbook_vpc.id

  tags = {
    Name = "epicbook-igw"
  }
}

resource "aws_route_table" "epicbook_public_rt" {
  vpc_id = aws_vpc.epicbook_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.epicbook_igw.id
  }

  tags = {
    Name = "epicbook-public-rt"
  }
}

#Private route table should NOT have IGW route. It will be used for private subnets that do not have direct access to the internet.

resource "aws_route_table" "epicbook_private_rt" {
  vpc_id = aws_vpc.epicbook_vpc.id

  tags = {
    Name = "epicbook-private-rt"
  }
}

resource "aws_route_table_association" "epicbook_public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.epicbook_public_rt.id
}

resource "aws_route_table_association" "epicbook_private_rta" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.epicbook_private_rt.id
}

resource "aws_route_table_association" "epicbook_private_rta_b" {
  subnet_id      = aws_subnet.private_subnet_b.id
  route_table_id = aws_route_table.epicbook_private_rt.id
}

resource "aws_security_group" "epicbook_sg" {
  name        = "epicbook-sg"
  description = "Security group for EpicBook application"
  vpc_id      = aws_vpc.epicbook_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress  {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "epicbook-sg"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}


resource "aws_key_pair" "ssh_key" {
  key_name   = "epicbook-ssh-key"
  public_key = file("~/.ssh/id_rsa.pub")        
}

resource "aws_instance" "epicbook_vm" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  vpc_security_group_ids  = [aws_security_group.epicbook_sg.id]
  key_name = aws_key_pair.ssh_key.key_name

   tags = {
        Name = "epicbook-vm"
    }
}



# RDS MySQL Database

resource "aws_db_subnet_group" "db_subnet" {
  name       = "epicbook-db-subnet"
  subnet_ids = [aws_subnet.private_subnet.id, aws_subnet.private_subnet_b.id]

  tags = {
    Name = "epicbook-db-subnet"
  }
}

resource "aws_security_group" "rds_sg" {
  name   = "rds-mysql-sg"
  vpc_id = aws_vpc.epicbook_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.epicbook_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "mysql" {
  allocated_storage    = 20
  engine               = "mysql"
  instance_class       = "db.t3.micro"
  db_name              = "epicbook"
  username             = "admin"
  password             = "StrongPassword123!"
  publicly_accessible  = false
  skip_final_snapshot  = true

  db_subnet_group_name = aws_db_subnet_group.db_subnet.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}

output "instance_public_ip" {
  description = "Public IP address of the EpicBook EC2 instance"
  value       = aws_instance.epicbook_vm.public_ip
}

output "database_endpoint" {
  description = "RDS MySQL endpoint"
  value       = aws_db_instance.mysql.endpoint
}


/*
Internet
   |
Internet Gateway
   |
Public Subnet (EC2)
   |
Private Subnet (RDS)

EC2 can talk to RDS.
Internet cannot talk to RDS.

-------------------------------------

(.env) file includes;

DB_HOST=terraform-20260418163549453400000001.cgt6cw62an4r.us-east-1.rds.amazonaws.com
DB_PORT=3306
DB_USER=admin
DB_PASSWORD=StrongPassword123!
DB_NAME=epicbook


--------------------------------------

Make Sure dotenv Is Used

Install dotenv (if not installed)
*** npm install dotenv ***

Open your server.js

At the very top, you MUST have
*** require('dotenv').config(); ***

-------------------------------------

Edit config.json

cat config/config.js

add below part;
{
  "development": {
    "username": process.env.DB_USER,
    "password": process.env.DB_PASSWORD,
    "database": process.env.DB_NAME,
    "host": process.env.DB_HOST,
    "dialect": "mysql"
  }
}


------------------------------------

setting up mysql client on your local machine

sudo apt update
sudo apt install mysql-client -y

mysql -h 'RDS endpoint' -u admin -p

*/
