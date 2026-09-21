# provider が接続するのは CodeBuild が渡す PGDATABASE (example) で、
# このデータベースはそこから作られる。
# owner は省略して接続ユーザ (RDS のマスターユーザ) のままにする。
# RDS では本当の superuser になれないので、他のロールを owner にすると
# そのロールのメンバーである必要がある。
resource "postgresql_database" "app" {
  name = "app"
}
