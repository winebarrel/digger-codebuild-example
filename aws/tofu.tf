terraform {
  required_version = "~> 1.12"

  # digger-example と同じバケットを使い、キーだけ分ける。
  # バケットは既にあるので、いきなりこの backend で init できる。
  # そのバケット自身は import.tf でこの state に取り込む。
  backend "s3" {
    bucket = "winebarrel-digger-example"
    key    = "digger-codebuild-example/aws/terraform.tfstate"
    region = "ap-northeast-1"

    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
