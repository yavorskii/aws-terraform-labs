provider "aws" {
  region = "eu-north-1"
}


resource "aws_iam_policy" "location_policy" {
  name        = "az104-02-location-policy"
  description = "Deny EC2 creation outside Stockholm"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "ec2:RunInstances"
        Effect   = "Deny"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = "eu-north-1"
          }
        }
      }
    ]
  })
}


resource "aws_iam_group_policy_attachment" "attach_location" {
  group      = "IT-Lab-Administrators" 
  policy_arn = aws_iam_policy.location_policy.arn
}