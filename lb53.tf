terraform{
required_providers{
aws = {
source = "hashicorp/aws"
version = "~>5.6"
}
}
}

provider "aws"{
region = "us-east-1"
}

##vpc
resource "aws_vpc" "vpc"{
cidr_block = "10.0.0.0/16"
tags = {Name = "vpc"}
}

resource "aws_subnet" "subs"{
for_each = var.subnets
cidr_block = each.value.cidr
availability_zone = each.value.zone
map_public_ip_on_launch = each.value.pbip
vpc_id = aws_vpc.vpc.id
tags = {Name = each.value.tags}
}

##internet gateway
resource "aws_internet_gateway" "igw"{
vpc_id = aws_vpc.vpc.id
tags = {Name = "VPC"}
}

##elastic ip
resource "aws_eip" "eip"{
vpc = true
tags = {Name = "elasticip"}
}

##nat gateway
resource "aws_nat_gateway" "ngw"{
allocation_id = aws_eip.eip.id
subnet_id = aws_subnet.subs["pusub1"].id
tags = {Name = "Natgateway"}
}

##route table
resource "aws_route_table" "rbig"{
vpc_id = aws_vpc.vpc.id
route{
cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.igw.id
}
tags = {Name = "routetable"}
}

resource "aws_route_table" "rbng"{
vpc_id = aws_vpc.vpc.id
route{
cidr_block = "0.0.0.0/0"
nat_gateway_id = aws_nat_gateway.ngw.id
}
tags = {Name = "routetablenw"}
}

resource "aws_route_table_association" "rbas"{
subnet_id = aws_subnet.subs["pusub1"].id
route_table_id = aws_route_table.rbig.id
}

resource "aws_route_table_association" "rbas2"{
subnet_id = aws_subnet.subs["pusub2"].id
route_table_id = aws_route_table.rbig.id
}

resource "aws_route_table_association" "rvas"{
subnet_id = aws_subnet.subs["pvsub1"].id
route_table_id = aws_route_table.rbng.id
}

resource "aws_route_table_association" "rvas2"{
subnet_id = aws_subnet.subs["pvsub2"].id
route_table_id = aws_route_table.rbng.id
}



##securitygroup
resource "aws_security_group" "sgrp" {
vpc_id = aws_vpc.vpc.id
name = "securitygrp"
dynamic ingress{
for_each = var.port
content{
from_port = ingress.value
to_port = ingress.value
cidr_blocks = ["0.0.0.0/0"]
protocol = "tcp"
}
}
egress{
from_port = 0
to_port = 0
cidr_blocks = ["0.0.0.0/0"]
protocol = -1
}
tags = {Name = "securitygrp"}
}


##keypair
resource "aws_key_pair" "key"{
key_name = "hameed"
public_key = file("/root/.ssh/id_rsa.pub")
}

data "aws_ami" "img"{
most_recent = true
owners = ["amazon"]
filter{
name = "name"
values = ["RHEL-9.4.0_HVM*"]
}
}
resource "aws_instance" "inst"{
key_name = aws_key_pair.key.key_name
instance_type = "t2.micro"
ami = data.aws_ami.img.image_id
for_each = aws_subnet.subs
subnet_id = each.value.id
security_groups = [aws_security_group.sgrp.id]

connection{
user = "ec2-user"
type = "ssh"
private_key = file("/root/.ssh/id_rsa")
host = self.public_ip
}

}

##load balancer
resource "aws_lb_target_group" "tgrp"{
port = 80
name = "targetgrop"
protocol = "HTTP"
vpc_id = aws_vpc.vpc.id
 health_check {
    path     = "/"
    port     = 80
    protocol = "HTTP"
  }
}

resource "aws_lb_target_group_attachment" "att1"{
target_group_arn = aws_lb_target_group.tgrp.arn
target_id = aws_instance.inst["pvsub1"].id
port = 80
}

resource "aws_lb_target_group_attachment" "att2"{
target_group_arn = aws_lb_target_group.tgrp.arn
target_id = aws_instance.inst["pvsub2"].id
port = 80
}

resource "aws_lb" "loadbl"{
name = "weblb"
subnets = [aws_subnet.subs["pusub1"].id,aws_subnet.subs["pusub2"].id]
security_groups = [aws_security_group.sgrp.id]
load_balancer_type = "application"
internal = false
}

resource "aws_lb_listener" "list1" {
port = 80
load_balancer_arn = aws_lb.loadbl.arn
protocol = "HTTP"
default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tgrp.arn
  }
}
resource "aws_lb_listener" "list2" {
port = 443
load_balancer_arn = aws_lb.loadbl.arn
protocol = "HTTPS"
certificate_arn = "arn:aws:acm:us-east-1:023775272889:certificate/57f47885-1d68-4494-aef8-4b94b81766a0"
default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tgrp.arn
  }
}

##route 53
resource "aws_route53_zone" "zone"{
name = "sharief.world"
}

resource "aws_route53_record" "record"{
name = "web.sharief.world"
type = "CNAME"
zone_id = aws_route53_zone.zone.zone_id
ttl = 300
records = [ aws_lb.loadbl.dns_name]
}
