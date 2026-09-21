resource "aws_security_group" "runner" {
  name        = "digger-runner-codebuild"
  description = "digger CodeBuild GitHub Actions runner"
  vpc_id      = data.aws_vpc.sandbox.id
}

# outbound は NAT 経由で開けておく。ランナーは GitHub に登録しに行き、
# S3 の state と tfplan を読み書きし、OpenTofu と provider を取ってくる。
resource "aws_vpc_security_group_egress_rule" "runner" {
  security_group_id = aws_security_group.runner.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound"
}

resource "aws_cloudwatch_log_group" "runner" {
  name              = "/aws/codebuild/digger-runner"
  retention_in_days = 14
}

# GitHub App (AWS Connector for GitHub) の接続。
# apply 直後は PENDING のまま。コンソールの
# Developer Tools > Settings > Connections から
# "Update pending connection" で認可して完成させる。
resource "aws_codeconnections_connection" "github" {
  name          = "digger-runner"
  provider_type = "GitHub"
}

# アカウントレベルの GitHub クレデンシャルとして登録する。
# 注意: アカウント、リージョン、サーバタイプごとに1つだけ。
resource "aws_codebuild_source_credential" "github" {
  auth_type   = "CODECONNECTIONS"
  server_type = "GITHUB"
  token       = aws_codeconnections_connection.github.arn
}

resource "aws_codebuild_project" "runner" {
  name          = "digger-runner"
  description   = "GitHub Actions self-hosted runner on AWS CodeBuild for digger"
  service_role  = aws_iam_role.runner.arn
  build_timeout = 60

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:8.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false

    # postgresql provider の接続設定。provider ブロックを空にできる。
    # ここで渡した値はランナーのジョブに素の環境変数として入るので、
    # ワークフローが動かすものは何でも読める。
    environment_variable {
      name  = "PGHOST"
      value = aws_db_instance.postgres.address
    }

    environment_variable {
      name  = "PGPORT"
      value = aws_db_instance.postgres.port
    }

    environment_variable {
      name  = "PGDATABASE"
      value = aws_db_instance.postgres.db_name
    }

    environment_variable {
      name  = "PGUSER"
      value = aws_db_instance.postgres.username
    }

    # RDS が Secrets Manager に置いたマスターパスワード
    environment_variable {
      name  = "PGPASSWORD"
      value = "${aws_db_instance.postgres.master_user_secret[0].secret_arn}:password"
      type  = "SECRETS_MANAGER"
    }

    # RDS のマスターユーザは本当の superuser ではない (rds_superuser)。
    # provider のデフォルトは true なので明示的に落とす。
    environment_variable {
      name  = "PGSUPERUSER"
      value = "false"
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/winebarrel/digger-codebuild-example.git"
    git_clone_depth = 1

    # GitHub Actions ランナーとして起動するときに CodeBuild が
    # buildspec を差し替えるので、これは実行されない。
    # プロジェクトに1つ必要なだけ。
    buildspec = yamlencode({
      version = "0.2"
      phases = {
        build = {
          commands = ["echo 'This buildspec is replaced by the GitHub Actions runner.'"]
        }
      }
    })
  }

  # RDS に届くよう VPC に入れる。GitHub 向けの通信も VPC を通るので
  # プライベートサブネットに NAT が必要。
  vpc_config {
    vpc_id             = data.aws_vpc.sandbox.id
    subnets            = data.aws_subnets.private.ids
    security_group_ids = [aws_security_group.runner.id]
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.runner.name
    }
  }

  depends_on = [aws_codebuild_source_credential.github]
}

# キューに入ったワークフロージョブ1つごとに build を、つまりランナーを1つ起動する
resource "aws_codebuild_webhook" "runner" {
  project_name = aws_codebuild_project.runner.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "WORKFLOW_JOB_QUEUED"
    }
  }
}
