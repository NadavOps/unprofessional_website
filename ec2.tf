data "aws_ami" "ubuntu_18_04" {
  owners      = ["099720109477"]
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-20210907"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "website_instance" {
  source                              = "git@github.com:NadavOps/terraform.git//aws/ec2"
  ami                                 = data.aws_ami.ubuntu_18_04.id
  instance_type                       = var.instance_type
  key_name                            = null
  subnet_id                           = element(concat(local.subnet_ids.public), 0)
  vpc_security_group_ids              = [module.security_groups["website"].sg_id]
  iam_instance_profile                = module.iam_roles["website"].aws_iam_instance_profile_id
  associate_public_ip_address_enabled = true
  tags                                = merge(local.tags, { Name = "${local.name_prefix}" })
  user_data                           = "${local.assets_path.user_data}/website.sh"
  user_data_variables = {
    tf_name_prefix = local.name_prefix
    tf_public_key  = var.ssh_public_key_filename != null ? file("~/.ssh/${var.ssh_public_key_filename}") : null
    tf_fqdn        = var.fqdn
  }
}

resource "null_resource" "copy_website_content" {
  depends_on = [
    module.website_instance
  ]

  triggers = {
    trigger = var.copy_website_content_enabled ? timestamp() : var.copy_website_content_enabled
  }

  provisioner "local-exec" {
    command     = <<-EOT
    ## evaluate if this code snippet should run
    if $copy_website_content_enabled; then 
      echo "Running null_resource.copy_website_content"
    else
      echo "Not Running null_resource.copy_website_content. Exit"
      exit 0
    fi
    ## waiter
    for interval in {1..120}; do
      website_status_code=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
      -i $private_key root@$website_public_ip "curl -s -o /dev/null -I -w "%%{http_code}" localhost")
      if [[ $website_status_code -eq 301 || $website_status_code -eq 200 ]]; then break; fi
      sleep 5
    done
    ## initial configuration
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
    -i $private_key root@$website_public_ip "rm -rf /var/www/html/*"
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
    -i $private_key -r $website_content_folder/* root@$website_public_ip:/var/www/html
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
    -i $private_key root@$website_public_ip "rm -rf /var/www/html/.git"
  EOT
    interpreter = ["/bin/bash", "-c"]
    environment = {
      private_key                  = "~/.ssh/${split(".", var.ssh_public_key_filename)[0]}"
      website_public_ip            = module.website_instance.ec2_object.public_ip
      website_content_folder       = local.assets_path.ignored_website_content
      copy_website_content_enabled = var.copy_website_content_enabled
    }
  }
}