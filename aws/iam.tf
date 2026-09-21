#
# CodeBuild ランナーのサービスロール。
# ジョブはこのロールを assumed した状態で動くので、OIDC は不要。
# 裏返しとして、ワークフローが動かすものは全部この権限を持つ。
#
data "aws_iam_policy_document" "runner_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    # confused deputy 対策。プロジェクトがこのロールを参照するので、
    # ここから参照し返すと循環するため ARN を直接書いている。
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:codebuild:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:project/digger-runner"]
    }
  }
}

resource "aws_iam_role" "runner" {
  name               = "digger-runner-codebuild"
  assume_role_policy = data.aws_iam_policy_document.runner_assume_role.json
}

data "aws_iam_policy_document" "runner" {
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      aws_cloudwatch_log_group.runner.arn,
      "${aws_cloudwatch_log_group.runner.arn}:*",
    ]
  }

  # GitHub App の接続からトークンを取るのに必要
  statement {
    sid    = "CodeConnections"
    effect = "Allow"

    actions = [
      "codeconnections:GetConnection",
      "codeconnections:GetConnectionToken",
    ]

    resources = [aws_codeconnections_connection.github.arn]
  }

  # VPC 内で build するための ENI 操作。Describe 系はリソースを絞れない。
  statement {
    sid    = "VpcNetworkInterface"
    effect = "Allow"

    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "VpcNetworkInterfacePermission"
    effect = "Allow"

    actions = ["ec2:CreateNetworkInterfacePermission"]

    resources = ["arn:aws:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:network-interface/*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:AuthorizedService"
      values   = ["codebuild.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "ec2:Subnet"
      values   = [for id in data.aws_subnets.private.ids : "arn:aws:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:subnet/${id}"]
    }
  }

  # PGPASSWORD を Secrets Manager から解決するのに必要
  statement {
    sid    = "ReadMasterUserSecret"
    effect = "Allow"

    actions = ["secretsmanager:GetSecretValue"]

    resources = [aws_db_instance.postgres.master_user_secret[0].secret_arn]
  }

  statement {
    sid    = "CodeBuildReports"
    effect = "Allow"

    actions = [
      "codebuild:CreateReportGroup",
      "codebuild:CreateReport",
      "codebuild:UpdateReport",
      "codebuild:BatchPutTestCases",
      "codebuild:BatchPutCodeCoverages",
    ]

    resources = [
      "arn:aws:codebuild:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:report-group/digger-runner-*",
    ]
  }

  # state、そのロックファイル、tfplan の読み書き。
  # digger に許す書き込みはここと下の PR ロックだけ。
  statement {
    sid    = "StateObjects"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = ["${aws_s3_bucket.digger.arn}/*"]
  }

  statement {
    sid       = "StateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.digger.arn]
  }

  # digger の PR ロック
  statement {
    sid    = "PrLock"
    effect = "Allow"

    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
    ]

    resources = [aws_dynamodb_table.digger_lock.arn]
  }
}

resource "aws_iam_role_policy" "runner" {
  name   = "digger-runner-codebuild"
  role   = aws_iam_role.runner.id
  policy = data.aws_iam_policy_document.runner.json
}
