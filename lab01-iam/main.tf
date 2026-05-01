provider "aws" {
  region = "eu-north-1"
}

resource "aws_iam_user" "user1" {
  name = "az104-user1"
  tags = {
    JobTitle   = "IT Lab Administrator"
    Department = "IT"
    Location   = "United States"
  }
}

resource "aws_iam_user" "user2_guest" {
  name = "yavorskii-guest"
  tags = {
    JobTitle   = "IT Lab Administrator"
    Department = "IT"
    Location   = "United States"
  }
}

resource "aws_iam_group" "it_lab_admins" {
  name = "IT-Lab-Administrators"
}

resource "aws_iam_group_membership" "team" {
  name = "it-lab-admins-membership"

  users = [
    aws_iam_user.user1.name,
    aws_iam_user.user2_guest.name,
  ]

  group = aws_iam_group.it_lab_admins.name
}