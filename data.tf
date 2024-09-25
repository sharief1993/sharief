provider "aws" {
region = "us-east-1"
}

resource "aws_vpc" "vpc"{
cidr_block = "10.0.0.0/16"
tags = {Name = "vpc"}
}

variable "sub"{
default = {
sub1 = {
cidr = "10.0.0.0/24"
zone = "us-east-1a"
tag = "pubsub"
pb = true
},
sub2 = {
cidr = "10.0.1.0/24"
zone = "us-east-1b"
tag = "pvtsub"
pb = false
}
}
}

resource "aws_subnet" "subs" {
for_each = var.sub
cidr_block = each.value.cidr
availability_zone = each.value.zone
map_public_ip_on_launch = each.value.pb
tags = {Name = each.value.tag}
vpc_id = aws_vpc.vpc.id
}

resource "aws_internet_gateway" "igw"{
vpc_id = aws_vpc.vpc.id
tags = {Name = "IGW"}
}
resource "aws_eip" "eip"{
vpc = true
tags = {Name = "EIP"}
}
resource "aws_nat_gateway" "ngw"{
allocation_id = aws_eip.eip.id
subnet_id = aws_subnet.subs["sub1"].id 
tags = {Name = "NGW"}
}

resource "aws_route_table" "rbig"{
vpc_id = aws_vpc.vpc.id
route{
cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.igw.id
}
tags = {Name = "route_igw"}
}

resource "aws_route_table" "rbng"{
vpc_id = aws_vpc.vpc.id
route{
cidr_block = "0.0.0.0/0"
nat_gateway_id = aws_nat_gateway.ngw.id
}
tags = {Name = "route_ngw"}
}

resource "aws_route_table_association" "rtpbs"{
subnet_id = aws_subnet.subs["sub1"].id
route_table_id = aws_route_table.rbig.id
}

resource "aws_route_table_association" "rtpvs"{
subnet_id = aws_subnet.subs["sub2"].id
route_table_id = aws_route_table.rbng.id
}

locals{
port = [22,443,80]
}

resource "aws_security_group" "sgrp" {
vpc_id = aws_vpc.vpc.id
name = "sgrp"

dynamic ingress{
for_each = local.port
content {
from_port = ingress.value
to_port = ingress.value
cidr_blocks = ["0.0.0.0/0"] 
protocol = "tcp"
}
}
egress {
from_port = 0
to_port = 0
cidr_blocks = ["0.0.0.0/0"]
protocol = -1
}
tags = {Name = "securitygrp"}
}

resource "aws_key_pair" "key"{
key_name = "khasim"
public_key = file("/root/.ssh/id_rsa.pub")
}

data "aws_ami" "img"{
most_recent = true
owners = ["amazon"]
filter{
name = "name"
values = ["RHEL-9*_HVM-*"]
}
}

resource "aws_instance" "inst"{
ami = data.aws_ami.img.image_id
for_each = aws_subnet.subs
subnet_id = each.value.id
instance_type = "t2.micro"
key_name = aws_key_pair.key.key_name
security_groups = [aws_security_group.sgrp.id]
}
