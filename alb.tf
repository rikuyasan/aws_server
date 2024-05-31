############################################
# security group
############################################

# セキュリティグループ(public)
resource "aws_security_group" "public" {
  description = "only pubric"
  name        = "ecs-pubric-security"
  vpc_id      = aws_vpc.demo.id
}

# セキュリティグループ(private)
resource "aws_security_group" "private" {
  description = "only private"
  name        = "ecs-private-security"
  vpc_id      = aws_vpc.demo.id
}

# パブリックののアウトバウンドルール
resource "aws_security_group_rule" "egress" {
  for_each          = { for k, v in local.security_groups : k => v }
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  protocol          = "-1"
  security_group_id = each.value
  to_port           = 0
  type              = "egress"
}

# プライベートからのインバウンドルール
resource "aws_security_group_rule" "private" {
  for_each                 = { for k, v in local.security_groups : k => v }
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = each.value
  source_security_group_id = aws_security_group.private.id
  to_port                  = 0
  type                     = "ingress"
}

# パブリックからのインバウンドルール
resource "aws_security_group_rule" "public" {
  for_each                 = { for k, v in local.security_groups : k => v }
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = each.value
  source_security_group_id = aws_security_group.public.id
  to_port                  = 0
  type                     = "ingress"
}

# VPC外からのアクセス
resource "aws_security_group_rule" "out" {
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.public.id
  to_port           = 80
  type              = "ingress"
}
############################################
# application load balancer
############################################
# アプリケーションロードバランサの作成
resource "aws_lb" "test" {
  load_balancer_type = "application"
  name               = "blue-green-alb"
  security_groups = [
    aws_security_group.public.id,
  ]
  subnets = values(aws_subnet.public)[*].id
}

# ターゲットグループの設定(blue)
resource "aws_lb_target_group" "blue" {
  name        = "ecs-blue"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.demo.id

  health_check {
    enabled             = true
    healthy_threshold   = 5
    matcher             = "200"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
}

# ターゲットグループの設定(green)
resource "aws_lb_target_group" "green" {
  name        = "ecs-green"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.demo.id

  health_check {
    enabled             = true
    healthy_threshold   = 5
    matcher             = "200"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
}

# リスナーの設定
resource "aws_lb_listener" "test" {
  load_balancer_arn = aws_lb.test.arn
  port              = 80
  protocol          = "HTTP"


  default_action {
    target_group_arn = aws_lb_target_group.blue.arn
    type             = "forward"
  }
  lifecycle {
    ignore_changes = [
      default_action[0].target_group_arn
    ]
  }
}