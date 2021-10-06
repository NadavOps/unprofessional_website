output "website_ssh" {
  value = (var.ssh_allowed_ips != null && var.ssh_public_key_filename != null) ? (
  "ssh -i ~/.ssh/${split(".", var.ssh_public_key_filename)[0]} ubuntu@${module.website_instance.ec2_object.public_ip}") : null
}

output "website_public_ip" {
  value = module.website_instance.ec2_object.public_ip
}