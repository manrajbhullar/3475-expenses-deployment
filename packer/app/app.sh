#!/bin/bash

sleep 30

# Updates Linux packages
sudo yum update -y

# Configures CloudWatch
sudo yum install -y awslogs
sudo mv /tmp/awslogs.conf /etc/awslogs/awslogs.conf
sudo systemctl start awslogsd
sudo systemctl enable awslogsd.service

# Downloads app source code and sets up virtual environment
sudo yum install git -y
git clone https://github.com/manrajbhullar/3475-expenses.git
cd ~/3475-expenses
python3 -m venv venv
source venv/bin/activate
pip install flask
pip install flask_mongoengine

# Enables expenses app as a service
sudo mv /tmp/app.service /etc/systemd/system/app.service
sudo systemctl daemon-reload
sudo systemctl enable app.service
sudo systemctl start app.service

# Enables access tot he flask server through different port
sudo amazon-linux-extras install nginx1 -y
sudo mv /tmp/nginx.conf /etc/nginx/nginx.conf
sudo chown root /etc/nginx/nginx.conf
sudo chgrp root /etc/nginx/nginx.conf
sudo systemctl enable nginx
sudo systemctl start nginx