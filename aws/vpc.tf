# 既存の sandbox VPC。
# プライベートサブネットは 0.0.0.0/0 を手作りの NAT ゲートウェイ
# (nat-071270b976e84730a) に向けている。この tf の管理外。
# CodeBuild を VPC に置くと GitHub 向けの通信も VPC を通るので、
# NAT が生きていないとランナーが登録できない。
data "aws_vpc" "sandbox" {
  filter {
    name   = "tag:Name"
    values = ["sandbox"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.sandbox.id]
  }

  filter {
    name   = "tag:Name"
    values = ["Private subnet-*"]
  }
}
