resource "postgresql_grant" "app_ro_database" {
  database    = postgresql_database.app.name
  role        = postgresql_role.app_ro.name
  object_type = "database"
  privileges  = ["CONNECT"]
}

resource "postgresql_grant" "app_ro_schema" {
  database    = postgresql_database.app.name
  role        = postgresql_role.app_ro.name
  schema      = postgresql_schema.app.name
  object_type = "schema"
  privileges  = ["USAGE"]
}

# objects を空にすると、そのスキーマの既存のテーブル全部が対象になる。
# 今後作られるテーブルには効かない。それは default_privileges.tf で賄う。
resource "postgresql_grant" "app_ro_tables" {
  database    = postgresql_database.app.name
  role        = postgresql_role.app_ro.name
  schema      = postgresql_schema.app.name
  object_type = "table"
  privileges  = ["SELECT"]
}

resource "postgresql_grant" "app_rw_database" {
  database    = postgresql_database.app.name
  role        = postgresql_role.app_rw.name
  object_type = "database"
  privileges  = ["CONNECT"]
}

resource "postgresql_grant" "app_rw_schema" {
  database    = postgresql_database.app.name
  role        = postgresql_role.app_rw.name
  schema      = postgresql_schema.app.name
  object_type = "schema"
  privileges  = ["USAGE", "CREATE"]
}

resource "postgresql_grant" "app_rw_tables" {
  database    = postgresql_database.app.name
  role        = postgresql_role.app_rw.name
  schema      = postgresql_schema.app.name
  object_type = "table"
  privileges  = ["SELECT", "INSERT", "UPDATE", "DELETE"]
}
