terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

resource "aws_ecrpublic_repository" "cicd" {
  repository_name = "cicd"
}

resource "aws_ecs_cluster" "cicd_cluster" {
  name = "cicd-cluster"
}

resource "aws_ecs_task_definition" "cicd_task" {
  family = "cicd-task"
  container_definitions = jsonencode([
    {
      "name" : "cicd-web"
      "image" : "${aws_ecrpublic_repository.cicd.repository_uri}"
      "essential" : true,
      "portMappings" : [
        {
          "containerPort" : 3000,
        }
      ],
      "memory" : 512,
      "cpu" : 256
    }
  ])

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  memory             = 512
  cpu                = 256
  execution_role_arn = aws_iam_role.ecsTaskExecutionRole.arn
  depends_on = [
    aws_iam_role.ecsTaskExecutionRole
  ]
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_ecs_service" "cicd_service" {
  name            = "cicd_service_web"
  cluster         = aws_ecs_cluster.cicd_cluster.id
  task_definition = aws_ecs_task_definition.cicd_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.allow_http.id]
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
  vpc_id            = aws_vpc.cicd_vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Public Subnet"
  }
}

resource "aws_internet_gateway" "cicd_vpc_igw" {
  vpc_id = aws_vpc.cicd_vpc.id

  tags = {
    Name = "CICD VPC - Internet Gateway"
  }
}

resource "aws_route_table" "cicd_vpc_us_east_1a_public" {
  vpc_id = aws_vpc.cicd_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cicd_vpc_igw.id
  }

  tags = {
    Name = "Public Subnet Route Table"
  }
}

resource "aws_route_table_association" "cicd_vpc_us_east_1a_public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.cicd_vpc_us_east_1a_public.id
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http_sg"
  description = "Allow HTTP inbound connections"
  vpc_id      = aws_vpc.cicd_vpc.id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_http_sg"
  }
}
