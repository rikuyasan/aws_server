############################################
# IAM role(task definition)
############################################
# roleの作成
resource "aws_iam_role" "demo" {
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "ecs-tasks.amazonaws.com"
          }
          Sid = ""
        },
      ]
      Version = "2008-10-17"
    }
  )
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchFullAccessV2",
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
  ]
  max_session_duration = 3600
  name                 = "ecsTaskExecutionRole"
  path                 = "/"
}


############################################
# ECS cluster
############################################
resource "aws_ecs_cluster" "test" {
  name = "codepipeline"

  # ECS Exeに関する設定？(多分いらない)
  configuration {
    execute_command_configuration {
      logging = "DEFAULT"
    }
  }

  # メトリクス収集の有効化
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "test" {
  capacity_providers = [
    "FARGATE",
    "FARGATE_SPOT",
  ]
  cluster_name = aws_ecs_cluster.test.name
}



############################################
# task definition
############################################
resource "aws_ecs_task_definition" "test" {
  container_definitions = jsonencode(
    [
      {
        cpu = 0
        # コンテナが失敗した場合にその他のコンテナを停止させるか否か
        essential = true
        image     = "aws_ecr_repository.backend.repository_url:latest"
        # タスク起動時などのログ収集
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-create-group  = "true"
            awslogs-group         = "/ecs/${local.container_name}"
            awslogs-region        = local.region
            awslogs-stream-prefix = "ecs"
          }
        }
        name = local.container_name
        portMappings = [
          {
            appProtocol   = "http"
            containerPort = local.to_port
            hostPort      = local.from_port
            name          = "${local.container_name}-${local.to_port}-tcp"
            protocol      = "tcp"
          },
        ]
      },
    ]
  )
  cpu                      = local.cpu
  execution_role_arn       = aws_iam_role.demo.arn
  family                   = local.container_name
  memory                   = local.memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = aws_iam_role.demo.arn
  track_latest             = false

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
}


############################################
# ECS services
############################################
resource "aws_ecs_service" "test" {
  cluster                 = aws_ecs_cluster.test.id
  desired_count           = local.min_capacity
  enable_ecs_managed_tags = true
  launch_type             = "FARGATE"
  name                    = "${local.container_name}-bluegreen"
  platform_version        = local.platform_version
  propagate_tags          = "NONE"
  task_definition         = data.aws_ecs_task_definition.test.arn

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  load_balancer {
    container_name   = local.container_name
    container_port   = local.to_port
    target_group_arn = aws_lb_target_group.blue.arn
  }


  network_configuration {
    assign_public_ip = false
    security_groups  = [aws_security_group.private.id]
    subnets          = values(aws_subnet.private)[*].id
  }

  # pipeline使用による更新対策
  lifecycle {
    ignore_changes = [task_definition, load_balancer]
  }
}

# codepipelineによるリビジョン更新対策
data "aws_ecs_task_definition" "test" {
  task_definition = aws_ecs_task_definition.test.family
}
