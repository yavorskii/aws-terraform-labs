provider "aws" {
  region = "eu-north-1"
}

resource "aws_security_group" "container_sg" {
  name   = "allow_http_container_final_fix"
  vpc_id = "vpc-07b5ec3440fc0958e" 

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_cluster" "main" {
  name = "lab09b-cluster"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "hello-world-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "az104-c1"
      image     = "nginxdemos/hello"
      essential = true
      portMappings = [
        {
          container_Port = 80
          host_Port      = 80
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "main" {
  name            = "lab09b-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = ["subnet-009f157adbba2e5d5", "subnet-0053ec5cb50104762"]
    security_groups  = [aws_security_group.container_sg.id]
    assign_public_ip = true
  }
}