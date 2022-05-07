
locals {
  azs_config = [
    {
      availability_zone  = "us-east-1a"
      public_cidr_block  = "10.0.0.0/24"
      private_cidr_block = "10.0.3.0/24"
    },
    {
      availability_zone  = "us-east-1b"
      public_cidr_block  = "10.0.1.0/24"
      private_cidr_block = "10.0.4.0/24"
    },
    {
      availability_zone  = "us-east-1c"
      public_cidr_block  = "10.0.2.0/24"
      private_cidr_block = "10.0.5.0/24"
    },
  ]
}

data "aws_subnet_ids" "public" {
  vpc_id = aws_vpc.cicd_vpc.id

  depends_on = [
    aws_subnet.public
  ]

  filter {
    name   = "tag:Name"
    values = ["Public Subnet"]
  }
}


data "aws_subnet_ids" "private" {
  vpc_id = aws_vpc.cicd_vpc.id

  depends_on = [
    aws_subnet.private
  ]

  filter {
    name   = "tag:Name"
    values = ["Private Subnet"]
  }
}

resource "aws_vpc" "cicd_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "CICD VPC"
  }
}


resource "aws_subnet" "public" {
  vpc_id = aws_vpc.cicd_vpc.id

  for_each = {
    for index, az_config in local.azs_config :
    index => az_config
  }

  cidr_block        = each.value.public_cidr_block
  availability_zone = each.value.availability_zone

  tags = {
    Name = "Public Subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id = aws_vpc.cicd_vpc.id

  for_each = {
    for index, az_config in local.azs_config :
    index => az_config
  }

  cidr_block        = each.value.private_cidr_block
  availability_zone = each.value.availability_zone

  tags = {
    Name = "Private Subnet"
  }
}

resource "aws_internet_gateway" "cicd_vpc_igw" {
  vpc_id = aws_vpc.cicd_vpc.id

  tags = {
    Name = "CICD VPC - Internet Gateway"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.cicd_vpc.id

  tags = {
    Name = "Public Subnet Route Table"
  }
}

resource "aws_route" "public_zone_gateway_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.cicd_vpc_igw.id
}

resource "aws_route_table_association" "cicd_vpc_table_public" {

  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_route_table.id

  depends_on = [
    aws_subnet.public
  ]
}

resource "aws_eip" "nat_eip" {
  for_each   = aws_subnet.public
  vpc        = true
  depends_on = [aws_internet_gateway.cicd_vpc_igw, aws_subnet.public]
}

resource "aws_nat_gateway" "nat" {
  for_each = aws_eip.nat_eip

  allocation_id = each.value.id
  subnet_id     = aws_subnet.public[each.key].id
  depends_on    = [aws_internet_gateway.cicd_vpc_igw, aws_eip.nat_eip]
}

resource "aws_route_table" "private_route_table" {
  for_each = aws_nat_gateway.nat

  vpc_id = aws_vpc.cicd_vpc.id

  tags = {
    Name = "Private Subnet Route Table"
  }

  depends_on = [
    aws_nat_gateway.nat
  ]
}

resource "aws_route" "private_zone_nat_gateway_route" {
  for_each = aws_route_table.private_route_table

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[each.key].id
}

resource "aws_route_table_association" "cicd_vpc_table_private" {

  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_route_table[each.key].id

  depends_on = [
    aws_subnet.private,
    aws_route_table.private_route_table
  ]
}
