provider "aws" {
  region = "eu-north-1"
}

provider "aws" {
  alias  = "backup_region"
  region = "eu-central-1"
}

data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

resource "aws_instance" "monitor_vm" {
  ami           = data.aws_ami.latest_amazon_linux.id
  instance_type = "t3.micro"

  tags = {
    Name = "az104-11-vm0"
  }
}

resource "aws_cloudwatch_log_group" "lab11_logs" {
  name              = "/az104/11/logs/vladyslav"
  retention_in_days = 7
}

resource "aws_sns_topic" "operations_alerts" {
  name = "Alert_the_operations_team"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.operations_alerts.arn
  protocol  = "email"
  endpoint  = "твій_email@example.com"
}

resource "aws_cloudwatch_metric_alarm" "vm_cpu_alarm" {
  alarm_name          = "az104-11-cpu-alarm-vladyslav"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This alarm triggers if CPU utilization exceeds 80% for 4 minutes"
  alarm_actions       = [aws_sns_topic.operations_alerts.arn]

  dimensions = {
    InstanceId = aws_instance.monitor_vm.id
  }
}