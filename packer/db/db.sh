#!/bin/bash

sleep 30

# Updates Linux packages
sudo yum update -y

# Configures CloudWatch
sudo yum install -y awslogs
sudo mv /tmp/awslogs.conf /etc/awslogs/awslogs.conf
sudo systemctl start awslogsd
sudo systemctl enable awslogsd.service

# Installs MongoDB and replaces its default configuraation file with preconfigured one
sudo mv /tmp/mongodb-org-5.0.repo /etc/yum.repos.d/mongodb-org-5.0.repo
sudo yum install -y mongodb-org
sudo systemctl enable mongod
sudo systemctl start mongod
sudo mv /tmp/mongod.conf /etc/mongod.conf
sudo chown root /etc/mongod.conf
sudo chgrp root /etc/mongod.conf
sudo systemctl restart mongod