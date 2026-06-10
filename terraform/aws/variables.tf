variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "project_name" {
  type    = string
  default = "monitoring-stack"
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "Your public IP in CIDR format"
}

variable "key_name" {
  type        = string
  description = "Existing AWS EC2 key pair name"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "ami_id" {
  type        = string
  description = "AMI ID for the monitoring EC2 instance"
  default     = "ami-12345678"
}
