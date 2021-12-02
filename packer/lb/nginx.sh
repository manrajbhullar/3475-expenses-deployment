#!/bin/bash

sleep 30

# Updates linux packages
sudo yum update -y

# Configures CloudWatch
sudo yum install -y awslogs
sudo mv /tmp/awslogs.conf /etc/awslogs/awslogs.conf
sudo systemctl start awslogsd
sudo systemctl enable awslogsd.service

# install nginx
sudo amazon-linux-extras install nginx1 -y

# Updates nginx file locations. Replaces default config file with the preconfigured one.
sudo mv /tmp/upstream.conf /etc/nginx/upstream.conf
sudo mv /tmp/nginx.conf /etc/nginx/nginx.conf

# Updates the nginx file owner
sudo chown root /etc/nginx/upstream.conf
sudo chgrp root /etc/nginx/upstream.conf
sudo chown root /etc/nginx/nginx.conf
sudo chgrp root /etc/nginx/nginx.conf

# Sets up SSL certificates for HTTPS
sudo yum install git -y
cd /etc/nginx
sudo git clone https://github.com/manrajbhullar/ssl.git
sudo chmod 700 ssl

# Starts Nginx
sudo systemctl enable nginx
sudo systemctl start nginx