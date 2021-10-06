# unprofessional_website
terraform.tfvars example: \
```
aws_provider_main_region     = "us-east-1"
aws_credentials_profile      = "example"
environment                  = "example"
instance_type                = "t3.micro"
ssh_allowed_ips              = [ "0.0.0.0/0" ]
ssh_public_key_filename      = "example.pub"
fqdn                         = "example.com"
copy_website_content_enabled = true
```

* Before running terraform apply, copy or link the site files into the folder ./assets/ignored_website_content

* After running terraform apply, point fqdn to the public ip