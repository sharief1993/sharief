terraform{
required_providers{
aws = {
source = "hashicorp/aws"
version = "~>5.0"
} 
}
}

provider "aws"{
region = "us-east-1"
}

###Vpc
resource "aws_vpc" "vpc" {
cidr_block = "10.0.0.0/16"
tags = {Name = "vpc"}
}

locals {
subnets = {
sub1 = {
zone = "us-east-1a"
name = "pub1"
cidr = "10.0.0.0/24"
pb = true
}
sub2 = {
zone = "us-east-1b"
name = "pub2"
cidr = "10.0.1.0/24"
pb = false
}
}
}

##subnets
resource "aws_subnet" "subs"{
vpc_id = aws_vpc.vpc.id
for_each = local.subnets
cidr_block = each.value.cidr
availability_zone = each.value.zone
map_public_ip_on_launch = each.value.pb
tags = {Name = each.value.name}
}

##internetgw
resource "aws_internet_gateway" "igw"{
vpc_id = aws_vpc.vpc.id
tags = {Name = "IGW"}
}

##EIP
resource "aws_eip" "eip" {
vpc = true
tags = {Name = "elastic_ip"}
}

##Natgw
resource "aws_nat_gateway" "ngw"{
allocation_id = aws_eip.eip.id
subnet_id = aws_subnet.subs["sub1"].id
}

##route table oublic subnet
resource "aws_route_table" "rbig"{
vpc_id = aws_vpc.vpc.id 
route{
cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.igw.id
}
tags = {Name = "rt_pb"}

}

##route table for private subnet
resource "aws_route_table" "rbng"{
vpc_id = aws_vpc.vpc.id
route{
cidr_block = "0.0.0.0/0"
nat_gateway_id = aws_nat_gateway.ngw.id
}
tags = {Name = "rt_pv"}
}

##rouet table associations public
resource "aws_route_table_association" "rtpbas"{
subnet_id = aws_subnet.subs["sub1"].id
route_table_id = aws_route_table.rbig.id
}

##rouet table associations pvriate
resource "aws_route_table_association" "rtpvas"{
subnet_id = aws_subnet.subs["sub2"].id
route_table_id = aws_route_table.rbng.id
}


variable "port"{
default = [22,80,443]
} 

##security_group
resource "aws_security_group" "sgrp"{
vpc_id = aws_vpc.vpc.id
name = "sgrp"
dynamic ingress {
for_each = var.port
content{
from_port = ingress.value
to_port = ingress.value
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
}
egress{
from_port = 0
to_port = 0
protocol = -1 
cidr_blocks = ["0.0.0.0/0"]
}
tags = {Name = "security_group"}
}

##key_pair
resource "aws_key_pair" "key"{
key_name = "khasim"
public_key = file("/root/.ssh/id_rsa.pub")
}

##ec2_instance
variable "tags" {
default = ["public", "private"]
}
resource "aws_instance" "inst"{
ami = "ami-0583d8c7a9c35822c"
for_each = aws_subnet.subs
subnet_id = each.value.id
key_name = aws_key_pair.key.key_name
instance_type = "t2.micro"
security_groups = [aws_security_group.sgrp.id]
}
