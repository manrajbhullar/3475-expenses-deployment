terraform {
    required_providers {
        aws = {
        source  = "hashicorp/aws"
        version = "~> 3.27"
        }
    }
    
    required_version = ">= 0.14.9"
}

provider "aws" {
    region = var.region
}

resource "aws_iam_role" "app_iam_role" {
    name = "expenses-app"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Sid    = ""
            Principal = {
            Service = "ec2.amazonaws.com"
            }
        },
        ]
    })
}


# Creates IAM role for all instances and gives them permission to use CloudWatch
resource "aws_iam_role_policy_attachment" "app_iam_policy_attachment" {
    role       = aws_iam_role.app_iam_role.name
    policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "app_instance_profile" {
    name = "expenses-app"
    role = aws_iam_role.app_iam_role.name
}


# Creates three security groups. One for each type of instance (application, database, load balancer)
resource "aws_security_group" "db_sg" {
    name        = "expenses-db"
    description = "Allows access on port 27017"

    ingress {
        from_port   = 27017
        to_port     = 27017
        protocol    = "tcp"
        cidr_blocks = ["172.31.0.0/16"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = -1
        cidr_blocks = ["0.0.0.0/0"]
    }

}

resource "aws_security_group" "app_sg" {
    name        = "expenses-app"
    description = "Allows access on port 5000 and port 80 for the reverse proxy"


    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["172.31.0.0/16"]
    }

    egress {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
}

resource "aws_security_group" "lb_sg" {
    name        = "expenses-lb"
    description = "Allows access on port 80"

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
        protocol    = -1
        cidr_blocks = ["0.0.0.0/0"]
    }

}

# Creates database instance using its latest AMI
data "aws_ami" "db_ami" {
    most_recent      = true
    name_regex       = "expenses-db-*"
    owners           = ["self"]
}

resource "aws_instance" "db_instance" {
    instance_type          = "t2.micro"
    ami                    = data.aws_ami.db_ami.id
    availability_zone      = var.availability_zones[0]
    vpc_security_group_ids = [aws_security_group.db_sg.id]
    iam_instance_profile   = aws_iam_instance_profile.app_instance_profile.name

    tags = {
        Name = "expenses-db"
    }
}


# Creates 3 application instances in seperate availability zones using the latest AMI
## Uses cloud-init to plug in database's endpoint into each application instance's envronment variables
data "aws_ami" "app_ami" {
    most_recent      = true
    name_regex       = "expenses-app-*"
    owners           = ["self"]
}

data "cloudinit_config" "app_config" {
    gzip          = true
    base64_encode = true
    part {
        content_type = "text/cloud-config"
        content = templatefile("${path.module}/app.yml", {
        mongodb_host : aws_instance.db_instance.private_ip
        mongodb_user : var.mongodb_user
        mongodb_password : var.mongodb_password
        })
    }
}

resource "aws_instance" "app_instances" {
    count                  = 3
    instance_type          = "t2.micro"
    ami                    = data.aws_ami.app_ami.id
    availability_zone      = var.availability_zones[count.index]
    vpc_security_group_ids = [aws_security_group.app_sg.id]
    iam_instance_profile   = aws_iam_instance_profile.app_instance_profile.name
    user_data              = data.cloudinit_config.app_config.rendered

    tags = {
        Name = "expenses-app"
    }
}


# Creates load balancer instance using latest AMI
## Uses cloud-init to plug in the ip addresses of the app servers created in the last step into the nginx config file
data "aws_ami" "lb_ami" {
    most_recent      = true
    name_regex       = "expenses-lb-*"
    owners           = ["self"]
}

data "cloudinit_config" "lb_config" {
    gzip          = true
    base64_encode = true
    part {
        content_type = "text/cloud-config"
        content = templatefile("${path.module}/lb.yml", {
        ips : join("\n", [for i in aws_instance.app_instances : "server ${i.private_ip};"])
        })
    }
}

resource "aws_instance" "lb_instance" {

    instance_type          = "t2.micro"
    ami                    = data.aws_ami.lb_ami.id
    availability_zone      = var.availability_zones[0]
    vpc_security_group_ids = [aws_security_group.lb_sg.id]
    iam_instance_profile   = aws_iam_instance_profile.app_instance_profile.name
    user_data              = data.cloudinit_config.lb_config.rendered

    tags = {
        Name = "expenses-lb"
    }
}


# Creates Route53 records so the domain works. Points it at the load balancer's ip address.
data "aws_route53_zone" "primary" {
    name = "manrajcloudcomputing.com"
}

resource "aws_route53_record" "domain" {
    zone_id = data.aws_route53_zone.primary.zone_id
    name    = "manrajcloudcomputing.com"
    type    = "A"
    ttl     = "300"
    records = [aws_instance.lb_instance.public_ip]
}

resource "aws_route53_record" "subdomains" {
    zone_id = data.aws_route53_zone.primary.zone_id
    name    = "*.manrajcloudcomputing.com"
    type    = "A"
    ttl     = "300"
    records = [aws_instance.lb_instance.public_ip]
}
