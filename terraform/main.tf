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
  family = "cicd-web"
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
  desired_count   = 3
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = aws_ecs_task_definition.cicd_task.family
    container_port   = 3000
  }

  network_configuration {
    subnets          = data.aws_subnet_ids.public.ids
    assign_public_ip = true
    security_groups  = ["${aws_security_group.service_security_group.id}"]
  }

  depends_on = [
    aws_subnet.public
  ]
}

resource "aws_security_group" "service_security_group" {
  vpc_id = aws_vpc.cicd_vpc.id
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = ["${aws_security_group.alb_security_group.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_vpc" "cicd_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "CICD VPC"
  }
}

data "aws_subnet_ids" "public" {
  vpc_id = aws_vpc.cicd_vpc.id
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.cicd_vpc.id
  for_each = {
    0 = "10.0.0.0/24"
    1 = "10.0.1.0/24"
    2 = "10.0.2.0/24"
  }
  cidr_block        = each.value
  availability_zone = ["us-east-1a", "us-east-1b", "us-east-1c"][each.key]

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

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.cicd_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cicd_vpc_igw.id
  }

  tags = {
    Name = "Public Subnet Route Table"
  }
}

resource "aws_route_table_association" "cicd_vpc_table_public" {

  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_route_table.id

  depends_on = [
    aws_subnet.public
  ]
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

resource "aws_alb" "application_load_balancer" {
  name               = "cicd-web-alb"
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.public.ids
  security_groups    = ["${aws_security_group.alb_security_group.id}"]
}

resource "aws_security_group" "alb_security_group" {
  vpc_id = aws_vpc.cicd_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "target_group" {
  name        = "target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.cicd_vpc.id
  health_check {
    matcher = "200,301,302"
    path    = "/"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_alb.application_load_balancer.arn # Referencing our load balancer
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn # Referencing our tagrte group
  }
}
