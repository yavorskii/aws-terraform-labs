provider "aws" {
  region = "eu-north-1"
}


variable "disk_name" {
  type    = string
  default = "az104-disk1"
}


resource "aws_ebs_volume" "example" {
  availability_zone = "eu-north-1a" 
  size              = 32             
  type              = "gp2"          

  tags = {
    Name = var.disk_name
  }
}


output "disk_id" {
  value = aws_ebs_volume.example.id
}