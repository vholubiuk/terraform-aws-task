#----------------------------------------------------------
# Made by Valerii Holubiuk
#-----------------------------------------------------------

provider "aws" {
  region = "eu-west-2"
}


data "aws_vpc" "default" {
  default = true
}
data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}
data "aws_availability_zones" "available" {}
data "aws_ami" "latest_amazon_windows_2019" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }
}

#--------------------------------------------------------------
resource "aws_security_group" "web" {
  name = "Dynamic Security Group"

  dynamic "ingress" {
    for_each = ["80", "443", "5985", "5985", "3389"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "Dynamic Security Group"
    Owner = "Valerii Holubiuk"
  }
}

resource "aws_launch_configuration" "web" {
  name_prefix     = "IIS-WebServer"
  image_id        = data.aws_ami.latest_amazon_windows_2019.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.web.id]
  user_data       = file("user_data.ps1")
  key_name        = aws_key_pair.devops.key_name

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web" {
  name                 = "ASG-${aws_launch_configuration.web.name}"
  launch_configuration = aws_launch_configuration.web.name
  min_size             = 2
  max_size             = 4
  min_elb_capacity     = 2
  health_check_type    = "ELB"
  vpc_zone_identifier  = [aws_default_subnet.default_az1.id, aws_default_subnet.default_az2.id]
  target_group_arns    = [aws_lb_target_group.nlb_target_group.arn]
  dynamic "tag" {
    for_each = {
      Name   = "WebServer in ASG"
      Owner  = "Valerii Holubiuk"
      TAGKEY = "TAGVALUE"
    }

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "nlb" {
  name                       = "nlb-lb-tf"
  internal                   = false
  load_balancer_type         = "network"
  subnets                    = data.aws_subnet_ids.default.ids
  enable_deletion_protection = true
  tags = {
    Environment = "production"
  }
}

resource "aws_lb_listener" "nlb" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.nlb_target_group.id
    type             = "forward"
  }
  depends_on = [aws_lb.nlb, aws_lb_target_group.nlb_target_group]
}

resource "aws_lb_target_group" "nlb_target_group" {
  name     = "tf-tg-lb"
  port     = 80
  protocol = "TCP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    interval            = 30
    port                = 80
    healthy_threshold   = 5
    unhealthy_threshold = 5
    protocol            = "TCP"
  }
}


resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available.names[0]
}

resource "aws_default_subnet" "default_az2" {
  availability_zone = data.aws_availability_zones.available.names[1]
}

resource "aws_key_pair" "devops" {
  key_name   = "devops-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC+CNMIaV1N9Bx/mVEwBF3MC3ay0AvR4GhbJ/s8S4KjqDxfa+vhsRkeym59w0esAaAvUp4XcXKlRcevmeAazsGJegAOm2/8pLgm0NQaxJhlKDpa0spOYIa7jHjODfkN4kgD6DMxdho/0+Z5uy4a49sR0pNrp2iVMmA3DqAuxfp8gLj2X4YLcePpnLjivwHDf42lsl7WRFsiB3rs3IAL4UU3fdLszqGeK5tiJPjudFdyHP9GttpNajvkCbGZvSOcHNyzNeQsGImd4TZp8GWmHNs093AT9NACmrK/lyGPjPiZL9tWLF1U0vyGeidRWOtlFFFT5WPOMMhsW4mbKxufTlqH user-pc@DESKTOP-4BRHUHM"
}

#--------------------------------------------------
output "web_loadbalancer_url" {
  value = aws_lb.nlb.dns_name
}
output "web_loadbalancer_ip" {
  value = data.aws_availability_zones.available.names
}
