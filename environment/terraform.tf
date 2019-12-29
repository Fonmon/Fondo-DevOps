locals {
  env        = terraform.workspace == "dev" ? "Dev" : "Prod"
  env_build  = terraform.workspace == "dev" ? "dev" : "prod"
  ssh_target = terraform.workspace == "dev" ? "dev-minagle" : "minagle"
  s_connection = {
    type        = "ssh"
    agent       = "false"
    user        = "ubuntu"
    private_key = file("~/.ssh/${local.ssh_target}.pem")
  }
}

provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
  version    = "~> 2.13.0"
}

resource "aws_instance" "server" {
  count = var.num_instances

  ami                    = data.aws_ami.latest_ubuntu.id
  instance_type          = terraform.workspace == "dev" ? "t2.micro" : "t2.small"
  key_name               = terraform.workspace == "dev" ? "develop-minagle" : "minagle"
  vpc_security_group_ids = [ 
                            data.terraform_remote_state.sg.outputs.sg_ssh,
                            data.terraform_remote_state.sg.outputs.sg_app,
                            data.terraform_remote_state.sg.outputs.sg_monitoring
                           ]
  iam_instance_profile   = data.aws_iam_instance_profile.s_ssm_role.name

  root_block_device {
    delete_on_termination = true
    volume_type           = "gp2"
    volume_size           = terraform.workspace == "dev" ? "10" : "12"
  }

  volume_tags = {
    Name = "${local.env} Fonmon"
  }

  provisioner "file" {
    source      = "~/.ssh/git_fonmonbot/id_rsa"
    destination = "/home/ubuntu/.ssh/id_rsa"
  }

  provisioner "file" {
    source      = "provisioners/config_git_ssh"
    destination = "/home/ubuntu/.ssh/config"
  }

  provisioner "remote-exec" {
    inline = [
      "cd ~",
      "chmod 400 .ssh/id_rsa .ssh/config",
      "sudo cp .ssh/id_rsa .ssh/config /root/.ssh/",
      "git clone https://github.com/Fonmon/Fondo-DevOps.git",
      "sudo ./Fondo-DevOps/environment/provisioners/build_env ubuntu ubuntu ${local.env_build}",
    ]
  }

  provisioner "remote-exec" {
    when = destroy
    inline = [
      "cd /home/ubuntu/Fondo-DevOps",
      "sudo git pull",
      "sudo ./environment/provisioners/make_recover_pkg ${local.env}",
    ]
  }

  provisioner "local-exec" {
    when    = destroy
    command = "scp ${local.ssh_target}:~/recovery_files_* ."
  }

  tags = {
    Name = "${local.env} Fonmon"
  }

  connection {
    type        = local.s_connection["type"]
    agent       = local.s_connection["agent"]
    host        = self.public_dns
    user        = local.s_connection["user"]
    private_key = local.s_connection["private_key"]
  }
}

resource "aws_eip" "s_eip" {
  instance = aws_instance.server[0].id
  tags = {
    Name = "${local.env} Fonmon"
  }
}

data "aws_ami" "latest_ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_iam_instance_profile" "s_ssm_role" {
  name = "SystemsManager"
}

data "terraform_remote_state" "sg" {
  backend = "local"
  config = {
    path = "backends/security_groups/security_group.tfstate"
  }
}