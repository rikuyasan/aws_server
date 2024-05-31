


############################################
# S3
############################################
resource "aws_s3_bucket" "test" {
  bucket = "tf-rikuya-pipeline"
}


############################################
# codestarconnections
############################################
resource "aws_codestarconnections_connection" "test" {
  name          = "github-connection"
  provider_type = "GitHub"
}


############################################
# IAM role(codebuild)
############################################

# assume_roleポリシーの作成
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# ecsポリシーの作成
data "aws_iam_policy_document" "test1" {
  statement {

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetAuthorizationToken",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    resources = ["*"]
  }
}

# cloudwatchポリシーの作成
data "aws_iam_policy_document" "test2" {
  statement {

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    # 
    resources = [
      "arn:aws:logs:${local.region}:${local.id}:log-group:/aws/codebuild/${local.container_name}",
      "arn:aws:logs:${local.region}:${local.id}:log-group:/aws/codebuild/${local.container_name}:*"
    ]
  }
}

# S3ポリシーの作成
data "aws_iam_policy_document" "test3" {
  statement {

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation"
    ]

    # 
    resources = [
      "arn:aws:s3:::tf-rikuya-pipeline/*"
    ]
  }
}

# codebuildポリシーの作成
data "aws_iam_policy_document" "test4" {
  statement {

    actions = [
      "codebuild:CreateReportGroup",
      "codebuild:CreateReport",
      "codebuild:UpdateReport",
      "codebuild:BatchPutTestCases",
      "codebuild:BatchPutCodeCoverages"
    ]

    # 
    resources = [
      "arn:aws:codebuild:${local.region}:${local.id}:report-group/${local.container_name}-*"
    ]
  }
}

# IAMロールの作成
resource "aws_iam_role" "test" {
  name               = "CodeBuildBasePolicy-${local.container_name}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# ポリシーのアタッチ
resource "aws_iam_role_policy" "test1" {
  role   = aws_iam_role.test.name
  policy = data.aws_iam_policy_document.test1.json
}

resource "aws_iam_role_policy" "test2" {
  role   = aws_iam_role.test.name
  policy = data.aws_iam_policy_document.test2.json
}

resource "aws_iam_role_policy" "test3" {
  role   = aws_iam_role.test.name
  policy = data.aws_iam_policy_document.test3.json
}

resource "aws_iam_role_policy" "test4" {
  role   = aws_iam_role.test.name
  policy = data.aws_iam_policy_document.test4.json
}


############################################
# iam_role(CodeDeploy)
############################################
resource "aws_iam_role" "bg" {
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "codedeploy.amazonaws.com"
          }
          Sid = ""
        },
      ]
      Version = "2012-10-17"
    }
  )
  description           = "Allows CodeDeploy to read S3 objects, invoke Lambda functions, publish to SNS topics, and update ECS services on your behalf."
  force_detach_policies = false
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS",
  ]
  max_session_duration = 3600
  name                 = "CodeDeployRoleForECSBlueGreen"
  path                 = "/"
}


############################################
# IAM role(CodePipeline)
############################################
resource "aws_iam_policy" "backend-pipeline" {
  name        = "AWSCodePipelineServiceRole-${local.region}-tf-demo"
  description = "Policy used in trust relationship with CodePipeline"
  path        = "/service-role/"
  policy = jsonencode(
    {
      Statement = [
        {
          Action = [
            "iam:PassRole",
          ]
          Condition = {
            StringEqualsIfExists = {
              "iam:PassedToService" = [
                "cloudformation.amazonaws.com",
                "elasticbeanstalk.amazonaws.com",
                "ec2.amazonaws.com",
                "ecs-tasks.amazonaws.com",
              ]
            }
          }
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "codecommit:CancelUploadArchive",
            "codecommit:GetBranch",
            "codecommit:GetCommit",
            "codecommit:GetRepository",
            "codecommit:GetUploadArchiveStatus",
            "codecommit:UploadArchive",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "codedeploy:CreateDeployment",
            "codedeploy:GetApplication",
            "codedeploy:GetApplicationRevision",
            "codedeploy:GetDeployment",
            "codedeploy:GetDeploymentConfig",
            "codedeploy:RegisterApplicationRevision",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "codestar-connections:UseConnection",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "elasticbeanstalk:*",
            "ec2:*",
            "elasticloadbalancing:*",
            "autoscaling:*",
            "cloudwatch:*",
            "s3:*",
            "sns:*",
            "cloudformation:*",
            "rds:*",
            "sqs:*",
            "ecs:*",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "lambda:InvokeFunction",
            "lambda:ListFunctions",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "opsworks:CreateDeployment",
            "opsworks:DescribeApps",
            "opsworks:DescribeCommands",
            "opsworks:DescribeDeployments",
            "opsworks:DescribeInstances",
            "opsworks:DescribeStacks",
            "opsworks:UpdateApp",
            "opsworks:UpdateStack",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "cloudformation:CreateStack",
            "cloudformation:DeleteStack",
            "cloudformation:DescribeStacks",
            "cloudformation:UpdateStack",
            "cloudformation:CreateChangeSet",
            "cloudformation:DeleteChangeSet",
            "cloudformation:DescribeChangeSet",
            "cloudformation:ExecuteChangeSet",
            "cloudformation:SetStackPolicy",
            "cloudformation:ValidateTemplate",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "codebuild:BatchGetBuilds",
            "codebuild:StartBuild",
            "codebuild:BatchGetBuildBatches",
            "codebuild:StartBuildBatch",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "devicefarm:ListProjects",
            "devicefarm:ListDevicePools",
            "devicefarm:GetRun",
            "devicefarm:GetUpload",
            "devicefarm:CreateUpload",
            "devicefarm:ScheduleRun",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "servicecatalog:ListProvisioningArtifacts",
            "servicecatalog:CreateProvisioningArtifact",
            "servicecatalog:DescribeProvisioningArtifact",
            "servicecatalog:DeleteProvisioningArtifact",
            "servicecatalog:UpdateProduct",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "cloudformation:ValidateTemplate",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "ecr:DescribeImages",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "states:DescribeExecution",
            "states:DescribeStateMachine",
            "states:StartExecution",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "appconfig:StartDeployment",
            "appconfig:StopDeployment",
            "appconfig:GetDeployment",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
      Version = "2012-10-17"
    }
  )
}

resource "aws_iam_role" "backend-pipeline" {
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "codepipeline.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )
  managed_policy_arns  = [aws_iam_policy.backend-pipeline.arn]
  max_session_duration = 3600
  name                 = "AWSCodePipelineServiceRole-${local.region}-tf-demo"
  path                 = "/service-role/"
}

############################################
# codebuild
############################################
resource "aws_codebuild_project" "test" {

  # codebuildのステータス(codepipelineに組み込まれているので設定しても意味ない)
  badge_enabled = false

  # 進行中のビルドの時間制限(単位は分)
  build_timeout = 15

  # 同時でビルドする最大数(最低1以上)
  concurrent_build_limit = 1

  # codebuild名(必須)
  name = local.container_name

  # codebuildを一般公開するか否か
  project_visibility = "PRIVATE"

  # 実行待ちできる時間(単位は分)
  queued_timeout = 480

  # codebuildに渡すIAMロール(必須)
  service_role = aws_iam_role.test.arn

  # (必須)
  artifacts {

    # 作成するアーティファクトを暗号化するか否か
    encryption_disabled = false

    # 作成されるアーティファクト名をデフォルト名からcodebuild名に変更するか否か
    override_artifact_name = false

    # アーティファクトのタイプ(テストを実行するかDockerイメージをECRにプッシュする場合はNO_ARTIFACTSで)(必須)
    type = "NO_ARTIFACTS"
  }

  # 一時的にデータを保管しておくことで、頻繁に更新がある場合のやり取りの量を減らす
  cache {
    modes = [

      # ローカルでdockerレイヤーを一時的に保管しておく
      "LOCAL_DOCKER_LAYER_CACHE",

      # ローカルでgitデータを一時的に保管しておく
      "LOCAL_SOURCE_CACHE",
    ]
    # キャッシュタイプ
    type = "LOCAL"
  }

  # 環境設定(必須)
  environment {

    # 使用するメモリ、vCPU、ディスク容量の指定(必須)(https://docs.aws.amazon.com/ja_jp/codebuild/latest/userguide/build-env-ref-compute-types.html)
    compute_type = "BUILD_GENERAL1_SMALL"

    # 使用するAMI(キャッシュを行う場合に利用する)(必須)
    image = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"

    # dockerデーモンを使用するか否か
    privileged_mode = false

    # ビルドに使用するビルド環境のタイプ(必須)(linaxなのか、windowsなのか、lamda関数を使用するのか等々)
    type = "LINUX_CONTAINER"
  }

  # クラウドウォッチにログを出力する
  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
    s3_logs {
      encryption_disabled = false
      status              = "DISABLED"
    }
  }

  # (必須)
  source {

    # ビルド仕様の設定
    buildspec = "buildspec.yml"

    # 
    git_clone_depth = 1

    # gitに接続する際のssh警告を無視するか否か
    insecure_ssl = false

    # 利用するリポジトリの場所
    location = "https://github.com/rikuyasan/codepipeline.git"

    # githubにビルドの開始と終了のステータスを通知するか否か
    report_build_status = false

    # リポジトリのタイプ(必須)
    type = "GITHUB"

    # gitのサブモジュールを取得しない
    git_submodules_config {
      fetch_submodules = false
    }
  }
}


############################################
# codedeploy app
############################################
resource "aws_codedeploy_app" "test" {
  name             = "blue-green-final"
  compute_platform = "ECS"
}


############################################
# codedeploy deploygorup
############################################
resource "aws_codedeploy_deployment_group" "test" {
  app_name               = aws_codedeploy_app.test.name
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  deployment_group_name  = "blue-green-final"
  service_role_arn       = aws_iam_role.bg.arn

  # B/Gを行うなら必須？
  blue_green_deployment_config {
    deployment_ready_option {
      # 自動でLBに紐づけるか手動で紐づけるか
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      # 指定した時間後にBlue環境を削除するか残しておくか
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 1
    }
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.test.name
    service_name = aws_ecs_service.test.name
  }

  deployment_style {
    # LBに紐づけるか否か(多分)
    deployment_option = "WITH_TRAFFIC_CONTROL"
    # inplace方式かblue/green方式か
    deployment_type = "BLUE_GREEN"
  }

  auto_rollback_configuration {
    # 自動的にロールバックするか否か
    enabled = true

    # トリガーの選択
    events = [
      "DEPLOYMENT_FAILURE",
      "DEPLOYMENT_STOP_ON_REQUEST",
    ]
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [
          aws_lb_listener.test.arn,
        ]
      }
      target_group {
        name = aws_lb_target_group.blue.name
      }
      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }
}


############################################
# codepipeline
############################################
resource "aws_codepipeline" "test" {
  # パイプライン名(必須)
  name = local.container_name

  # パイプラインのタイプ
  pipeline_type = "V2"

  # 付与するiamロール(必須)
  role_arn = "arn:aws:iam::${local.id}:role/service-role/AWSCodePipelineServiceRole-${local.region}-tf-demo"

  # アーティファクトの保存先(必須)
  artifact_store {
    location = "tf-rikuya-pipeline"
    type     = "S3"
  }

  stage {

    # ステージ名(必須)
    name = "Source"

    # カテゴリ内容(必須)
    action {

      # カテゴリの種類(必須)
      category = "Source"

      # 使用するサービス名一覧(今回はgithub)
      configuration = {
        "BranchName"           = "main"
        "ConnectionArn"        = aws_codestarconnections_connection.test.arn
        "DetectChanges"        = "false"
        "FullRepositoryId"     = local.repository_id
        "OutputArtifactFormat" = "CODE_ZIP"
      }

      # カテゴリ名(必須)
      name = "Source"

      namespace = "SourceVariables"

      # 作成したアーティファクト
      output_artifacts = [
        "SourceArtifact",
      ]

      # 使用するのはAWSのサービスかそうじゃないか(そうでなければThirdParty)(必須)
      owner = "AWS"

      # 使用するAWSのサービス名(必須)
      provider = "CodeStarSourceConnection"

      # アーティファクトの保存先のリージョン(今回はs3のリージョン)
      region = local.region

      # 同ステージ内で実行されるアクションの順番
      run_order = 1

      # アクションのタイプ(基本1)(必須)
      version = "1"
    }
  }
  stage {

    # ステージ名(必須)
    name = "Build"

    # カテゴリ内容(必須)
    action {

      # カテゴリの種類(必須)
      category = "Build"

      # 使用するサービス名一覧(今回はcodebuild)
      configuration = {
        "ProjectName" = local.container_name
      }

      # 使用するアーティファクト
      input_artifacts = [
        "SourceArtifact",
      ]

      # カテゴリ名(必須)
      name      = "Build"
      namespace = "BuildVariables"

      # 作成したアーティファクト
      output_artifacts = [
        "BuildArtifact",
      ]

      # 使用するのはAWSのサービスかそうじゃないか(そうでなければThirdParty)(必須)
      owner = "AWS"

      # 使用するAWSのサービス名(必須)
      provider = "CodeBuild"

      # アーティファクトの保存先のリージョン(今回はs3のリージョン)
      region = local.region

      # 同ステージ内で実行されるアクションの順番
      run_order = 1

      # アクションのタイプ(基本1)(必須)
      version = "1"
    }
  }
  stage {

    # ステージ名(必須)
    name = "Deploy"

    # カテゴリ内容(必須)
    action {

      # カテゴリの種類(必須)
      category = "Deploy"

      # 使用するサービス名一覧(今回はECS)
      configuration = {
        "AppSpecTemplateArtifact"        = "BuildArtifact"
        "ApplicationName"                = aws_codedeploy_app.test.name
        "DeploymentGroupName"            = aws_codedeploy_deployment_group.test.deployment_group_name
        "Image1ArtifactName"             = "BuildArtifact"
        "Image1ContainerName"            = "IMAGE_NAME"
        "TaskDefinitionTemplateArtifact" = "BuildArtifact"
      }

      # 使用するアーティファクト
      input_artifacts = [
        "BuildArtifact",
      ]

      # カテゴリ名(必須)
      name = "Deploy"

      namespace = "DeployVariables"

      # 作成したアーティファクト
      output_artifacts = []

      # 使用するのはAWSのサービスかそうじゃないか(そうでなければThirdParty)(必須)
      owner = "AWS"

      # 使用するAWSのサービス名(必須)
      provider = "CodeDeployToECS"

      # アーティファクトの保存先のリージョン(今回はs3のリージョン)
      region = local.region

      # 同ステージ内で実行されるアクションの順番
      run_order = 1

      # アクションのタイプ(基本1)(必須)
      version = "1"
    }
  }
}
