#----------------------------------------------------------
# Made by Valerii Holubiuk
#-----------------------------------------------------------

provider "aws" {
  region = "eu-west-2"
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
  load_balancers       = [aws_elb.web.name]
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

resource "aws_elb" "web" {
  name               = "WebServer-HA-ELB"
  availability_zones = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  security_groups    = [aws_security_group.web.id]
  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = 80
    instance_protocol = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }
  tags = {
    Name = "WebServer-Highly-Available-ELB"
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
  value = aws_elb.web.dns_name
}
output "web_loadbalancer_ip" {
  value = data.aws_availability_zones.available.names
}
