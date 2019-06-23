variable "access_key" {}

variable "secret_key" {}

variable "region" {}

variable "cidr_monitoring" {
  default = []
}

terraform {
  backend "local" {
    path = "security_group.tfstate"
  }
}

provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
  version    = "~> 2.13.0"
}

resource "aws_security_group" "s_sg_app" {
  name        = "fonmon-sg"
  description = "Security group for Fonmon application"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "APP Fonmon"
  }
}

resource "aws_security_group" "s_sg_ssh" {
  name        = "ssh-sg"
  description = "Security group for ssh connections"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SSH Connections"
  }
}

resource "aws_security_group" "s_sg_monitoring" {
  name          = "monitoring-sg"
  description   = "Security group for monitoring"
  vpc_id        = data.aws_vpc.default.id

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = "${var.cidr_monitoring}"
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = "${var.cidr_monitoring}"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Monitoring Fonmon"
  }
}

data "aws_vpc" "default" {
  default = true
}

output "sg_app" {
  value = "${aws_security_group.s_sg_app.id}"
}

output "sg_ssh" {
  value = "${aws_security_group.s_sg_ssh.id}"
}

output "sg_monitoring" {
  value = "${aws_security_group.s_sg_monitoring.id}"
}