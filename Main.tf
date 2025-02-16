# Configure the AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Create a VPC (Virtual Private Cloud)
resource "aws_vpc" "Trevorvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "Trevorvpc"
  }
}

# Public Subnets for Web Server Tier
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.Trevorvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.Trevorvpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet-2"
  }
}

# Private Subnets for RDS Tier
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.Trevorvpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "PrivateSubnet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.Trevorvpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "PrivateSubnet-2"
  }
}

# Private Route Table
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.Trevorvpc.id
}

resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.IGW.id
}

# Public Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.Trevorvpc.id
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.IGW.id
}

# Public Route Table Association
resource "aws_route_table_association" "routetableassociation1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "routetableassociation2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Private Route Table Association
resource "aws_route_table_association" "privaterouteassociation1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "privaterouteassociation2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}

# Create an Internet Gateway
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.Trevorvpc.id

  tags = {
    Name = "MainIGW"
  }
}

# Creating a Security Group for Web Server
resource "aws_security_group" "web_sg" {
  name        = "web_sg"
  description = "Allow inbound HTTP and SSH"
  vpc_id      = aws_vpc.Trevorvpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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
}

# Security Group for RDS MySQL
resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Allow inbound MySQL"
  vpc_id      = aws_vpc.Trevorvpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creating EC2 Instance 1 
resource "aws_instance" "Ec2_instances1" {
  ami                    = "ami-085ad6ae776d8f09c" # Change It to your own AMI
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  subnet_id              = aws_subnet.public_subnet_1.id
  key_name               = "Ec2Kp"
  user_data              = base64encode(file("userdata_script.sh"))
  tags = {
    name = "Ec2_instance1"
  }
}

# Creating EC2 Instance 2
resource "aws_instance" "Ec2_instances2" {
  ami                    = "ami-085ad6ae776d8f09c" # Change It to your own AMI
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  subnet_id              = aws_subnet.public_subnet_2.id
  key_name               = "Ec2Kp"
  user_data              = base64encode(file("userdata_script.sh"))
  tags = {
    name = "Ec2_instance2"
  }
}
#Create DataBase
resource "aws_db_instance" "mydb" {
  identifier             = "mydb"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "trevordatabase"
  username               = "admin"
  password               = "password"
  db_subnet_group_name   = aws_db_subnet_group.dbmain.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  multi_az               = false
  storage_type           = "gp2"
  skip_final_snapshot    = true
}

# Database for Subnet Group
resource "aws_db_subnet_group" "dbmain" {
  name       = "main-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = {
    Name = "MainDataBase"
  }
}