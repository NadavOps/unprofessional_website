locals {
  assets_path = {
    iam                     = "./assets/iam"
    user_data               = "./assets/user_data_scripts"
    ignored_website_content = "./assets/ignored_website_content"
  }

  tags = {
    Name             = "${var.environment}-ChangeTag"
    DeploymentMethod = "Terraform"
    Environment      = var.environment
  }

  name_prefix = "website-${var.environment}"
}