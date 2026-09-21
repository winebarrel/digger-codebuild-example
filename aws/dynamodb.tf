# digger の PR ロック。digger が初回実行時に自分で作ったものを
# インポートして管理下に置く。テーブル名は digger 側の固定値。
resource "aws_dynamodb_table" "digger_lock" {
  name         = "DiggerDynamoDBLockTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }
}
