terraform{
required_providers{
aws = {
source = "hashicorp/aws"
version = "~>5.8"
}
}
}

provider "aws" {
region = "us-east-1"
}

resource "aws_vpc" "vpc" {
cidr_block = "10.0.0.0/16"
tags = {Name = "public_vpc"}
}
##Pub_subnet
resource "aws_subnet" "pusub"{
vpc_id = aws_vpc.vpc.id
map_public_ip_on_launch = true
availability_zone = "us-east-1a"
cidr_block = "10.0.0.0/24"
tags = {Name = "public_subnet"}
}

##Private_subnet
resource "aws_subnet" "pvsub"{
vpc_id = aws_vpc.vpc.id
availability_zone = "us-east-1b"
cidr_block = "10.0.1.0/24"
tags = {Name = "private_subnet"}
}

##Internet Gateway
resource "aws_internet_gateway" "igw"{
vpc_id = aws_vpc.vpc.id
tags = {Name = "internetgatw"}
}

##Elastic_ip
resource "aws_eip" "eip"{
vpc = true
tags = {Name = "EIP"}
}

##Nat_gateway
resource "aws_nat_gateway" "ngw"{
allocation_id = aws_eip.eip.id
subnet_id = aws_subnet.pusub.id
tags = {Name = "Nat_gateway"}
}
##route_table for public subnet
resource "aws_route_table" "rtbl"{
vpc_id = aws_vpc.vpc.id
route{
cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.igw.id
}
tags = {Name = "rtbligw"}
}

##Route table for private subnet
resource "aws_route_table" "rtng"{
vpc_id = aws_vpc.vpc.id
route{
cidr_block = "0.0.0.0/0"
nat_gateway_id = aws_nat_gateway.ngw.id
}
tags = {Name = "rtblngw"}
}

##Route_tble_association for public subnet
resource "aws_route_table_association" "rtpbs"{
subnet_id = aws_subnet.pusub.id
route_table_id = aws_route_table.rtbl.id
}

##Rouet table Associaion for private subnet
resource "aws_route_table_association" "rtpvs"{
subnet_id = aws_subnet.pvsub.id
route_table_id = aws_route_table.rtng.id
}

## security group

locals {
sgrp = [{port = 22},{port = 80}]
}

variable "cust" {
default = {
0 = ["0.0.0.0/0"]
}
}

resource "aws_security_group" "sgw1"{
vpc_id =  aws_vpc.vpc.id
name = "sgwpb"

dynamic ingress {
for_each = local.sgrp
content{
from_port = ingress.value.port
to_port = ingress.value.port
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
}
ingress{
from_port = -1 
to_port = -1
protocol = "icmp"
cidr_blocks = ["0.0.0.0/0"]

}
dynamic egress{
for_each = var.cust
content{
from_port = egress.key
to_port = egress.key
protocol = -1
cidr_blocks = egress.value
}
}
}

##key_pri
resource "aws_key_pair" "key"{
key_name = "khasim"
public_key = file("/root/.ssh/id_rsa.pub")
}

##aws instance public

resource "aws_instance" "inst1"{
ami = "ami-0583d8c7a9c35822c"
subnet_id = aws_subnet.pusub.id
instance_type = "t2.micro"
key_name = aws_key_pair.key.key_name
vpc_security_group_ids = [aws_security_group.sgw1.id]
connection{
user = "ec2-user"
type = "ssh"
private_key = file("/root/.ssh/id_rsa")
host = self.public_ip
}
user_data = <<EOF
#!/bin/bash
sudo -i
yum install nmap -y
echo instaled nmap
EOF
tags = {Name = "Jump_server"}
}

resource "aws_instance" "inst2"{
ami = "ami-0583d8c7a9c35822c"
subnet_id = aws_subnet.pvsub.id
instance_type = "t2.micro"
key_name = aws_key_pair.key.key_name
vpc_security_group_ids = [aws_security_group.sgw1.id]
tags = {Name = "local"}
}
