# aws_server
ローカル環境でAWSを用いたサーバを構築
 - alb.tf
   - セキュリティグループ、ALB、リスナー、ターゲットグループ(blue,green)
 - ecr.tf
   - ecr
 - ecs.tf
   - ECSクラスター、ECSサービス、ECSタスク定義、IAM(タスクロール)
 - network.tf
   - VPC、サブネット、インターネットゲートウェイ、NAT(インスタンス、セキュリティグループ、EIP等)
 - pipeline.tf
   - S3、CodeStarConnections(GitHubと提携)、CodePipeline、CodeDeploy、CodePipeline、CodeBuild、IAM(CodeBuildとCodePipeline用)
