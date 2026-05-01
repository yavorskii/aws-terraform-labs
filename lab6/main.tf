provider "aws" {
  region = "eu-north-1"
}

# --- 1. МЕРЕЖА (Автономна) ---
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "lab06-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "lab06-igw" }
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "lab06-subnet-a" }
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-north-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "lab06-subnet-b" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.public.id
}

# --- 2. БЕЗПЕКА ---
resource "aws_security_group" "lb_sg" {
  name   = "lb-sg"
  vpc_id = aws_vpc.main.id
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

# --- 3. ОБЧИСЛЕННЯ (Windows VM) ---
data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
}

resource "aws_instance" "vm" {
  count         = 3
  ami           = data.aws_ami.windows.id
  instance_type = "t3.micro"
  subnet_id     = count.index % 2 == 0 ? aws_subnet.subnet_a.id : aws_subnet.subnet_b.id
  tags          = { Name = "lab06-vm-${count.index}" }
}

# --- 4. NLB (Layer 4) ---
resource "aws_lb" "nlb" {
  name               = "lab06-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.subnet_a.id]
  
  # Очікуємо створення шлюзу
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_lb_target_group" "nlb_tg" {
  name     = "nlb-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_target_group_attachment" "nlb_attach" {
  count            = 2
  target_group_arn = aws_lb_target_group.nlb_tg.arn
  target_id        = aws_instance.vm[count.index].id
}

resource "aws_lb_listener" "nlb_listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "80"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_tg.arn
  }
}

# --- 5. ALB (Layer 7) ---
resource "aws_lb" "alb" {
  name               = "lab06-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]

  # Очікуємо створення шлюзу
  depends_on = [aws_internet_gateway.igw]
}

# Target Group для Images
resource "aws_lb_target_group" "img_tg" {
  name     = "img-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

# Target Group для Video
resource "aws_lb_target_group" "vid_tg" {
  name     = "vid-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_target_group_attachment" "img_attach" {
  target_group_arn = aws_lb_target_group.img_tg.arn
  target_id        = aws_instance.vm[1].id
}

resource "aws_lb_target_group_attachment" "vid_attach" {
  target_group_arn = aws_lb_target_group.vid_tg.arn
  target_id        = aws_instance.vm[2].id
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Access /image/ or /video/"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener_rule" "img_rule" {
  listener_arn = aws_lb_listener.alb_listener.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.img_tg.arn
  }
  condition {
    path_pattern { values = ["/image/*"] }
  }
}

resource "aws_lb_listener_rule" "vid_rule" {
  listener_arn = aws_lb_listener.alb_listener.arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vid_tg.arn
  }
  condition {
    path_pattern { values = ["/video/*"] }
  }
}