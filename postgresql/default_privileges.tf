# GRANT は実行した時点で存在するオブジェクトにしか効かない。
# 今後作られるテーブルとシーケンスを賄うのがこのリソース。
#
# owner は「オブジェクトを作るロール」で、ここでは接続ユーザである
# RDS のマスターユーザを指す。provider はこのユーザで接続するので、
# マイグレーションがこの構成経由で流れる限りは覆える。
# app_rw もスキーマに CREATE を持っているので、app_rw 自身が作った
# オブジェクトはここでは覆えない。それを覆うにはマスターユーザが
# app_rw のメンバーである必要がある。
resource "postgresql_default_privileges" "app_ro_tables" {
  database    = postgresql_database.app.name
  schema      = postgresql_schema.app.name
  role        = postgresql_role.app_ro.name
  owner       = "postgres"
  object_type = "table"
  privileges  = ["SELECT"]
}

resource "postgresql_default_privileges" "app_ro_sequences" {
  database    = postgresql_database.app.name
  schema      = postgresql_schema.app.name
  role        = postgresql_role.app_ro.name
  owner       = "postgres"
  object_type = "sequence"
  privileges  = ["SELECT"]
}

resource "postgresql_default_privileges" "app_rw_tables" {
  database    = postgresql_database.app.name
  schema      = postgresql_schema.app.name
  role        = postgresql_role.app_rw.name
  owner       = "postgres"
  object_type = "table"
  privileges  = ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE"]
}

# serial 列が nextval を呼べるように USAGE も渡す
resource "postgresql_default_privileges" "app_rw_sequences" {
  database    = postgresql_database.app.name
  schema      = postgresql_schema.app.name
  role        = postgresql_role.app_rw.name
  owner       = "postgres"
  object_type = "sequence"
  privileges  = ["USAGE", "SELECT"]
}
