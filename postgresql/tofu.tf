terraform {
  required_version = "~> 1.12"

  # aws/ と同じバケット。キーだけ分けている。
  backend "s3" {
    bucket = "winebarrel-digger-example"
    key    = "digger-codebuild-example/postgresql/terraform.tfstate"
    region = "ap-northeast-1"

    use_lockfile = true
  }

  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.27"
    }
  }
}

# 接続設定は全て CodeBuild プロジェクトの環境変数から来る。
#
#   PGHOST PGPORT PGDATABASE PGUSER PGPASSWORD PGSUPERUSER
#
# PGPASSWORD は RDS が Secrets Manager に置いたマスターパスワードで、
# CodeBuild が解決してからジョブに渡す。PGSUPERUSER は false。
# RDS のマスターユーザは rds_superuser で、本当の superuser ではない。
provider "postgresql" {}
