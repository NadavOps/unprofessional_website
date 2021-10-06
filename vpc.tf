locals {
  vpc_cidr_block = {
    default = "172.16.0.0/16"
  }

  subnet_ids = {
    public = [for subnet in aws_subnet.public : subnet.id]
  }
}

## VPC
resource "aws_vpc" "vpc" {
  cidr_block           = lookup(local.vpc_cidr_block, var.environment, local.vpc_cidr_block.default)
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, { Name = local.name_prefix })
}

## IG (internet gateway)
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(local.tags, { Name = local.name_prefix })
}

#### Public Networking ####
## Subnets
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  for_each = {
    for index in range(0, length(data.aws_availability_zones.available.zone_ids)) : index => cidrsubnet(aws_vpc.vpc.cidr_block, 8, index)
  }
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.value
  availability_zone_id    = element(data.aws_availability_zones.available.zone_ids, each.key)
  map_public_ip_on_launch = true

  tags = merge(local.tags, { Name = "${local.name_prefix}-public-${each.key}" })
}

## Route tables and routes
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(local.tags, { Name = "${local.name_prefix}-public" })
}

resource "aws_route" "public_default_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}