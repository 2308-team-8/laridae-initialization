terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.23.1"
    }
  }
}

provider "aws" {
  region = "${var.REGION}"
  shared_credentials_files = ["~/.aws/credentials"]
}

resource "aws_ecs_cluster" "laridae_cluster" {
  name = "${var.LARIDAE_CLUSTER}"
}

resource "aws_ecs_cluster_capacity_providers" "laridae_cluster_capacity_provider" {
  cluster_name = aws_ecs_cluster.laridae_cluster.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "laridae_ecs_task_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role      = aws_iam_role.ecs_task_execution_role.name
}

# todo: remove this and logging after testing
resource "aws_iam_role_policy_attachment" "ecs_cloudwatch_role" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
  role      = aws_iam_role.ecs_task_execution_role.name
}

resource "aws_ecs_task_definition" "laridae_task_definition" {
  family                   = "${var.LARIDAE_TASK_DEFINITION}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions    = <<TASK_DEFINITION
    [
      {
        "name": "laridae_migration_task",
        "image": "closetsolipsist/laridae",
        "cpu": 1024,
        "memory": 2048,
        "essential": true,
        "environment": [
          {"name": "DATABASE_URL", "value": "${var.DATABASE_URL}"}
        ],
        "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-create-group": "true",
                    "awslogs-group": "/ecs/",
                    "awslogs-region": "${var.REGION}",
                    "awslogs-stream-prefix": "laridae"
                },
                "secretOptions": []
            }
      }
    ]
  TASK_DEFINITION
}

resource "aws_security_group" "github_runner" {
  name_prefix        = "github-runner-sg-"
  description        = "Security group for GitHub Runner with ECS permissions"
  vpc_id             = var.VPC_ID

  ingress {
    from_port   = 22  
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  ingress {
    from_port   = 0
    to_port     = 65535
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

output "security_group_id" {
  value = aws_security_group.github_runner.id
}

resource "aws_iam_role" "laridae_full_ecs_role" {
  name = "laridae_full_ecs_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "full_ecs_policy" {
  name = "full_ecs_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "ecs:*",
      Resource = "*"
    }]
  })
}

resource "aws_iam_user" "laridae_ecs_user" {
  name = "laridae_ecs_user"
}

resource "aws_iam_user_policy_attachment" "laridae_user_full_ecs_policy_attachment" {
  user       = aws_iam_user.laridae_ecs_user.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}

resource "aws_iam_user_policy_attachment" "laridae_user_full_ecr_policy_attachment" {
  user       = aws_iam_user.laridae_ecs_user.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticContainerRegistryPublicFullAccess"
}

resource "aws_iam_access_key" "laridae_ecs_access_key" {
  
  user = aws_iam_user.laridae_ecs_user.name
}

output "ecs_access_key_id" {
  value = aws_iam_access_key.laridae_ecs_access_key.id
}

output "ecs_secret_access_key" {
  sensitive = true
  value = aws_iam_access_key.laridae_ecs_access_key.secret
}

variable "REGION" {
  type        = string
}

variable "LARIDAE_CLUSTER" {
  type        = string
}

variable "DATABASE_URL" {
  type        = string
}

variable "VPC_ID" {
  type        = string
}

variable "LARIDAE_TASK_DEFINITION" {
  type        = string
}