variable "subnets"{
default = {
pusub1 = {
cidr = "10.0.0.0/24"
zone = "us-east-1a"
pbip = true
tags = "pusub1"
}
pusub2 = {
cidr = "10.0.1.0/24"
zone = "us-east-1b"
pbip = true
tags = "pusub2"
}
pvsub1 = {
cidr = "10.0.2.0/24"
zone = "us-east-1a"
pbip = false
tags = "pvsub1"
}

pvsub2 = {
cidr = "10.0.3.0/24"
zone = "us-east-1b"
pbip = false
tags = "pvsub2"
}
}
}
variable "port"{
default = [22,443,80] 
}
