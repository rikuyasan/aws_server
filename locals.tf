locals {
  cidr_block = "10.0.0.0/16"
  availability_zones = [
    "ap-northeast-1a",
    "ap-northeast-1c"
  ]
  pj_name        = "demo-bg"
  container_name = "pipelinetest"
  region         = "ap-northeast-1"
  id             = "730335258866"
}

# ECS
locals {
  min_capacity     = 0
  platform_version = "1.4.0"
  cpu              = "256"
  memory           = "512"
  to_port          = 80
  from_port        = 80
}

# Pipeline
locals {
  repository_id = "rikuyasan/codepipeline"
}

# security_group
locals {
  security_groups = [
    aws_security_group.public.id,
    aws_security_group.private.id
  ]
}

# NATinstance
locals {
  ami            = "ami-0a8282e9d415eb1db"
  instance_type  = "t2.micro"
  instance_name  = "nat-instance"
  nat_cidr_block = "10.0.0.225"
}