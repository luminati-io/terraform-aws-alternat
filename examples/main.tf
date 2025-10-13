data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4"

  name                  = var.vpc_name
  cidr                  = var.vpc_cidr
  secondary_cidr_blocks = [var.vpc_secondary_cidr]
  private_subnets       = var.private_subnets
  public_subnets        = var.public_subnets
  azs                   = local.azs
  enable_nat_gateway    = var.enable_nat_gateway
}

resource "aws_subnet" "secondary_subnets" {
  count             = length(var.vpc_secondary_subnets)
  vpc_id            = module.vpc.vpc_id
  cidr_block        = var.vpc_secondary_subnets[count.index]
  availability_zone = local.azs[count.index]
}

resource "aws_route_table_association" "secondary_subnets" {
  count          = length(var.vpc_secondary_subnets)
  subnet_id      = aws_subnet.secondary_subnets[count.index].id
  route_table_id = module.vpc.private_route_table_ids[count.index]
}

data "aws_subnet" "subnet" {
  count = length(module.vpc.private_subnets)
  id    = module.vpc.private_subnets[count.index]
}

# Example: NAT Gateway IDs must be provided externally
# You should create NAT Gateways separately and reference their IDs here
locals {
  vpc_az_maps = [
    {
      az                 = local.azs[0]
      route_table_ids    = [module.vpc.private_route_table_ids[0]]
      public_subnet_id   = module.vpc.public_subnets[0]
      nat_gateway_id     = "nat-12345abcde"  # Replace with your actual NAT Gateway ID
      private_subnet_ids = [module.vpc.private_subnets[0]]
    },
    {
      az                 = local.azs[1]
      route_table_ids    = [module.vpc.private_route_table_ids[1]]
      public_subnet_id   = module.vpc.public_subnets[1]
      nat_gateway_id     = "nat-67890fghij"  # Replace with your actual NAT Gateway ID
      private_subnet_ids = [module.vpc.private_subnets[1]]
    }
    # Add more AZs as needed, each with its own nat_gateway_id
  ]
}

module "alternat" {
  # To use Alternat from the Terraform Registry:
  # source = "chime/alternat/aws"
  source = "./.."

  create_nat_gateways                = false  # We create NAT Gateways externally
  ingress_security_group_cidr_blocks = var.private_subnets
  vpc_az_maps                        = local.vpc_az_maps
  vpc_id                             = module.vpc.vpc_id

  lambda_package_type = "Zip"

  nat_instance_type       = var.alternat_instance_type
  nat_instance_key_name   = var.nat_instance_key_name
  enable_nat_restore      = var.enable_nat_restore
  enable_ssm              = var.enable_ssm
  enable_cloudwatch_agent = var.enable_cloudwatch_agent
}
