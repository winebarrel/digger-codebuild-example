output "runs_on_label" {
  description = "ワークフローの runs-on に書く値"
  value       = "codebuild-${aws_codebuild_project.runner.name}-$${{ github.run_id }}-$${{ github.run_attempt }}"
}

output "connection_arn" {
  description = "GitHub App の接続の ARN。apply 直後は PENDING なのでコンソールで認可する"
  value       = aws_codeconnections_connection.github.arn
}

output "connection_status" {
  description = "接続のステータス。AVAILABLE でないと build が失敗する"
  value       = aws_codeconnections_connection.github.connection_status
}

output "log_group_name" {
  description = "ランナーが書き込む CloudWatch Logs のロググループ"
  value       = aws_cloudwatch_log_group.runner.name
}

output "db_endpoint" {
  description = "RDS のエンドポイント"
  value       = aws_db_instance.postgres.endpoint
}

output "db_master_user_secret_arn" {
  description = "RDS が管理するマスターパスワードの Secrets Manager ARN"
  value       = aws_db_instance.postgres.master_user_secret[0].secret_arn
}
