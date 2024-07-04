variable "instance_type" {
  description = "Type of instance to create."
  type        = string
  default     = "t2.micro"
}

variable "aws_region" {
  description = "AWS region where resources will be created."
  default     = "us-east-1"
}

variable "vpc_cidr_block" {
  description = "AWS vpc cidr."
  default     = "172.16.0.0/16"
}

variable "subnet_cidr_block" {
  description = "AWS subnet cidr."
  default     = "172.16.10.0/24"
}

variable "key_name" {
  description = "AWS key_name."
  default     = "vockey"
}

variable "ami" {
  description = "AWS ami."
  default     = "ami-08a0d1e16fc3f61ea"
}

variable "subscription_email" {
  description = "Email address to subscribe to the SNS topic."
  type        = string
}

/*variable "subscription_emails" {
  description = "List of email addresses to subscribe to the SNS topic."
  type        = list(string)
}*/