resource "aws_ecr_repository" "backend" {
  image_tag_mutability = "MUTABLE"
  name                 = local.container_name

  image_scanning_configuration {
    scan_on_push = false
  }
}


resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = <<EOF
    {
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire images older than 90 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 90
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}