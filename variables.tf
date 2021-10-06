variable "aws_provider_main_region" {
  description = "Region of deployment"
  type        = string
}

variable "aws_credentials_profile" {
  description = "Profile name with the credentials to run. profiles usually are found at ~/.aws/credentials"
  type        = string
}

variable "environment" {
  description = "one word describing the webiste"
  type        = string
  default     = "env"
}

variable "ssh_public_key_filename" {
  description = "The ssh public key filename in ~/.ssh path. changing this will recycle the EC2- careful"
  type        = string
  default     = null
}

variable "fqdn" {
  description = "The FQDN to get a certificate for"
  type        = string
  default     = null
}

variable "instance_type" {
  description = "The website instance family type. defaults to free tier t3.micro"
  type        = string
  default     = "t3.micro"
}

variable "ssh_allowed_ips" {
  description = "The IPs allowed to ssh into the website EC2. Defaults to all"
  type        = list(string)
  default     = null
}

variable "copy_website_content_enabled" {
  description = "both true and false may trigger the null resource, but only true will actually copy the content"
  type        = bool
  default     = true
}