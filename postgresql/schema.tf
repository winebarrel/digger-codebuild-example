resource "postgresql_schema" "app" {
  name     = "app"
  database = postgresql_database.app.name
}
