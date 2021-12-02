variable "region" {
    description = "The AWS region where the infrastructure will be deployed"
    type        = string
}

variable "availability_zones" {
    description = "The availability zones the AWS resources will be in"
    type        = list(string)
}

variable "mongodb_user" {
    description = "The MongoDB user the app will use"
    type        = string
}

variable "mongodb_password" {
    description = "The MongoDB password the app will use"
    type        = string
}