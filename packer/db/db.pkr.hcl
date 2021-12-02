packer {
    required_plugins {
        amazon = {
            version = ">= 1.0.0"
            source = "github.com/hashicorp/amazon"
        }
    }
}

locals {
    timestamp = regex_replace(timestamp(), "[- TZ:]", "")
    region = "us-east-1"
}

source "amazon-ebs" "expenses-db" {
    ami_name = "expenses-db-${local.timestamp}"

    source_ami_filter {
        filters = {
            virtualization-type = "hvm"
            name = "amzn2-ami-hvm-2.*.1-x86_64-gp2"
            root-device-type = "ebs"
        }
        owners = ["amazon"]
        most_recent = true
    }
    
    instance_type = "t2.micro"
    region = local.region
    ssh_username = "ec2-user"
}

build {
    sources =  [
        "source.amazon-ebs.expenses-db"
    ]

    provisioner "file" {
        source = "./mongodb-org-5.0.repo"
        destination = "/tmp/mongodb-org-5.0.repo"
    }

    provisioner "file" {
        source = "./mongod.conf"
        destination = "/tmp/mongod.conf"
    }

    provisioner "file" {
        source = "./awslogs.conf"
        destination = "/tmp/awslogs.conf"
    }

    provisioner "shell" {
        script = "./db.sh"
    }
}