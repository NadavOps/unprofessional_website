locals {
  security_groups = {
    website = {
      sg_name        = local.name_prefix
      sg_description = local.name_prefix
      cidr_block_rules = {
        http = {
          type        = "ingress", from_port = 80, to_port = 80, protocol = "TCP",
          cidr_blocks = ["0.0.0.0/0"], description = "Allow HTTP World"
        }
        https = {
          type        = "ingress", from_port = 443, to_port = 443, protocol = "TCP",
          cidr_blocks = ["0.0.0.0/0"], description = "Allow HTTPS World"
        }
        outbound = {
          type        = "egress", from_port = 0, to_port = 0, protocol = "-1",
          cidr_blocks = ["0.0.0.0/0"], description = "Outbound all allowed"
        }
      }
    }

  }
}

module "security_groups" {
  source           = "git@github.com:NadavOps/terraform.git//aws/security_groups"
  for_each         = local.security_groups
  sg_name          = each.value.sg_name
  sg_description   = each.value.sg_description
  vpc_id           = aws_vpc.vpc.id
  tags             = local.tags
  cidr_block_rules = contains(keys(each.value), "cidr_block_rules") ? each.value.cidr_block_rules : {}
  source_sg_rules  = contains(keys(each.value), "source_sg_rules") ? each.value.source_sg_rules : {}
  self_sg_rules    = contains(keys(each.value), "self_sg_rules") ? each.value.self_sg_rules : {}
}

resource "aws_security_group_rule" "website_ssh" {
  count             = length(var.ssh_allowed_ips) > 0 ? 1 : 0
  security_group_id = module.security_groups["website"].sg_id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "TCP"
  cidr_blocks       = var.ssh_allowed_ips
  description       = "SSH"
}