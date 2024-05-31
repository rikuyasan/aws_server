# terraformに関する情報の設定
terraform {
  # terraformのバージョン指定(使用しているバージョン以降であれば問題なさそう)
  required_version = ">=1.7.4"

  # terraformで使用するプロバイダーの設定
  required_providers {
    aws = {
      # awsのバージョン指定(使用しているバージョンに固定する)
      source  = "hashicorp/aws"
      version = "~>5.37.0"
    }
  }
}


# リージョンの指定
provider "aws" {
  region     = "ap-northeast-1"
}


# tfstateファイルをs3に配置する
terraform {
  backend "s3" {
    bucket  = "tf-rikuya-ssan-demo"
    region  = "ap-northeast-1"
    profile = "cloud9_work"
    key     = "handmade.tfstate"
  }
}