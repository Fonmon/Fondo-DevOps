locals {
    env = "${terraform.workspace == "dev" ? "Dev" : "Prod"}"
    ssh_target = "${terraform.workspace == "dev" ? "dev-minagle" : "minagle"}"
    s_connection = {
        type = "ssh"
        agent = "false"
        user = "ubuntu"
        private_key = "${file("~/.ssh/${local.ssh_target}.pem")}"
    }
}

provider "aws" {
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
    region = "${var.region}"
}

resource "aws_instance" "server" {
    count = "${var.num_instances}"

    ami = "${data.aws_ami.latest_ubuntu.id}"
    instance_type = "${terraform.workspace == "dev" ? "t2.micro" : "t2.small"}"
    key_name = "${terraform.workspace == "dev" ? "develop-minagle" : "minagle"}"
    vpc_security_group_ids = ["${aws_security_group.s_sg_app.id}", "${aws_security_group.s_sg_ssh.id}"]

    root_block_device {
        delete_on_termination = true
        volume_type = "gp2"
        volume_size = "${terraform.workspace == "dev" ? "10" : "12"}"
    }

    provisioner "file" {
        source = "~/.ssh/git_fonmonbot/id_rsa"
        destination = "/home/ubuntu/.ssh/id_rsa"

        connection {
            type = "${local.s_connection["type"]}"
            agent = "${local.s_connection["agent"]}"
            host = "${self.public_dns}"
            user = "${local.s_connection["user"]}"
            private_key = "${local.s_connection["private_key"]}"
        }
    }

    provisioner "file" {
        source = "provisioners/config_git_ssh"
        destination = "/home/ubuntu/.ssh/config"

        connection {
            type = "${local.s_connection["type"]}"
            agent = "${local.s_connection["agent"]}"
            host = "${self.public_dns}"
            user = "${local.s_connection["user"]}"
            private_key = "${local.s_connection["private_key"]}"
        }
    }

    provisioner "remote-exec" {
        inline = [
            "cd ~",
            "chmod 400 .ssh/id_rsa .ssh/config",
            "sudo cp .ssh/id_rsa .ssh/config /root/.ssh/",
            "git clone https://github.com/Fonmon/Fondo-DevOps.git",
            "sudo ./Fondo-DevOps/environment/provisioners/build_env ubuntu ubuntu"
        ]

        connection {
            type = "${local.s_connection["type"]}"
            agent = "${local.s_connection["agent"]}"
            host = "${self.public_dns}"
            user = "${local.s_connection["user"]}"
            private_key = "${local.s_connection["private_key"]}"
        }
    }

    provisioner "remote-exec" {
        when = "destroy"
        inline = [
            "cd /home/ubuntu/Fondo-DevOps",
            "sudo git pull",
            "sudo ./environment/provisioners/make_recover_pkg ${local.env}"
        ]

        connection {
            type = "${local.s_connection["type"]}"
            agent = "${local.s_connection["agent"]}"
            host = "${self.public_dns}"
            user = "${local.s_connection["user"]}"
            private_key = "${local.s_connection["private_key"]}"
        }
    }

    provisioner "local-exec" {
        when = "destroy"
        command = "scp ${local.ssh_target}:~/recovery_files_* ."
    }

    tags {
        Name = "${local.env} Fonmon"
    }
}

resource "aws_eip" "s_eip" {
    instance = "${aws_instance.server.id}"
    tags {
        Name = "${local.env} Fonmon"
    }
}

resource "aws_security_group" "s_sg_app" {
    name = "fonmon-sg"
    description = "Security group for Fonmon application"
    vpc_id = "${data.aws_vpc.default.id}"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags {
        Name = "APP Fonmon"
    }
}

resource "aws_security_group" "s_sg_ssh" {
    name = "ssh-sg"
    description = "Security group for ssh connections"
    vpc_id = "${data.aws_vpc.default.id}"

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags {
        Name = "SSH Connections"
    }
}

data "aws_ami" "latest_ubuntu" {
    most_recent = true
    owners = ["099720109477"] # Canonical

    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
    }
    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}

data "aws_vpc" "default" {
    default = true
}
