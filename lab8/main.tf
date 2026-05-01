provider "aws" {
  region = "eu-north-1"
}



resource "aws_instance" "vm1" {
  ami               = "ami-0a791b55bd315e2d7" 
  instance_type     = "t3.micro"
  availability_zone = "eu-north-1a"
  tags = { Name = "az104-vm1" }
}

resource "aws_instance" "vm2" {
  ami               = "ami-0a791b55bd315e2d7"
  instance_type     = "t3.micro"
  availability_zone = "eu-north-1b"
  tags = { Name = "az104-vm2" }
}


resource "aws_ebs_volume" "disk1" {
  availability_zone = "eu-north-1a"
  size              = 32
  type              = "gp3" 
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.disk1.id
  instance_id = aws_instance.vm1.id
}



resource "aws_launch_template" "vmss_template" {
  name_prefix   = "vmss-template"
  image_id      = "ami-0a791b55bd315e2d7"
  instance_type = "t3.micro"
}

resource "aws_autoscaling_group" "asg" {
  name                = "vmss1"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 10
  
 
  vpc_zone_identifier = [
    "subnet-009f157adbba2e5d5", 
    "subnet-0053ec5cb50104762"  
  ] 

  launch_template {
    id      = aws_launch_template.vmss_template.id
    version = "$Latest"
  }
}


resource "aws_autoscaling_policy" "scale_out" {
  name                   = "ScaleOut-CPU-70"
  scaling_adjustment     = 50 
  adjustment_type        = "PercentChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.asg.name
}


resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "high-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "70"

  alarm_actions = [aws_autoscaling_policy.scale_out.arn]
}