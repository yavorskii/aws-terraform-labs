provider "aws" {
  region = "eu-north-1"
}

data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
}



resource "aws_instance" "core_vm" {
  ami           = data.aws_ami.windows.id
  instance_type = "t3.micro"
  subnet_id     = "subnet-02d5afd7fe88d558d" 
  tags          = { Name = "CoreServicesVM" }
}

resource "aws_instance" "mfg_vm" {
  ami           = data.aws_ami.windows.id
  instance_type = "t3.micro"
  subnet_id     = "subnet-0e6ad20876fe72aa3" 
  tags          = { Name = "ManufacturingVM" }
}


resource "aws_vpc_peering_connection" "core_to_mfg" {
  vpc_id        = "vpc-021773e06df131272" 
  peer_vpc_id   = "vpc-03ea3e33c05a7fc56" 
  auto_accept   = true
  tags          = { Name = "CoreToMfgPeering" }
}


resource "aws_route" "core_to_mfg_route" {
  route_table_id            = "rtb-03c793433a40ff8bc"
  destination_cidr_block    = "10.30.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.core_to_mfg.id
}

resource "aws_route" "mfg_to_core_route" {
  route_table_id            = "rtb-08d80fa8c8cc35f5f"
  destination_cidr_block    = "10.20.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.core_to_mfg.id
}


resource "aws_subnet" "perimeter" {
  vpc_id            = "vpc-021773e06df131272"
  cidr_block        = "10.20.30.0/24"
  availability_zone = "eu-north-1a"
  tags              = { Name = "PerimeterSubnet" }
}

resource "aws_route_table" "rt_perimeter" {
  vpc_id = "vpc-021773e06df131272"
  tags   = { Name = "rt-CoreServices" }
}
