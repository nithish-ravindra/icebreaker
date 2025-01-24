variable "aws_region" {
    description = "The AWS region to deploy resources."
    default     = "us-east-1" 
}

variable "release_version" {
    description = "The release version of the deployment"
    type        = string
}

variable "env" {
    description = "The environment for the resources"
    type        = string
}