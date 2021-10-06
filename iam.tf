locals {
  iam_policies = {
    website = {
      name        = local.name_prefix
      description = local.name_prefix
      policy = templatefile("${local.assets_path.iam}/policy.website.json", {
        tf_bucket_name = "changethis"
      })
    }
  }

  iam_roles = {
    website = {
      name               = local.name_prefix
      description        = local.name_prefix
      assume_role_policy = file("${local.assets_path.iam}/trust_relationship.ec2.json")
      create_profile     = true
      attach_policies = {
        custom = {
          "website" = local.iam_policies.website.name
        }
      }
    }
  }

}

resource "aws_iam_policy" "policy" {
  for_each    = local.iam_policies
  name        = each.value.name
  description = each.value.description
  policy      = each.value.policy
}

module "iam_roles" {
  source                    = "git@github.com:NadavOps/terraform.git//aws/iam_role"
  for_each                  = local.iam_roles
  role_name                 = each.value.name
  role_description          = each.value.description
  force_detach_policies     = true
  create_profile            = each.value.create_profile
  trust_relationship_policy = each.value.assume_role_policy
  path                      = "/"
  tags                      = local.tags

  aws_managed_policies    = contains(keys(each.value.attach_policies), "managed") ? each.value.attach_policies.managed : {}
  custom_managed_policies = contains(keys(each.value.attach_policies), "custom") ? each.value.attach_policies.custom : {}

  depends_on = [aws_iam_policy.policy]
}