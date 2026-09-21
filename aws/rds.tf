resource "aws_db_subnet_group" "postgres" {
  name       = "digger-codebuild-example"
  subnet_ids = data.aws_subnets.private.ids
}

resource "aws_security_group" "postgres" {
  name        = "digger-codebuild-example-postgres"
  description = "digger codebuild example PostgreSQL"
  vpc_id      = data.aws_vpc.sandbox.id
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_runner" {
  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = aws_security_group.runner.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL from the CodeBuild runner"
}

resource "aws_db_instance" "postgres" {
  identifier = "digger-codebuild-example"

  engine = "postgres"
  # マイナーバージョンは AWS に選ばせる (auto_minor_version_upgrade)
  engine_version = "18"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "example"
  username = "postgres"

  # RDS がパスワードを生成して Secrets Manager で管理するので、
  # state には載らない。
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres.id]
  publicly_accessible    = false

  # デモ用なので最小限
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true
}
