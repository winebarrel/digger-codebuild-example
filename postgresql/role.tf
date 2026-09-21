# 権限をまとめるためのグループロール。ログインしないのでパスワードを持たない。
# 実際のユーザにはこのロールを GRANT して権限を渡す。
# ログインするロールを作る場合、password は state に平文で載るので
# password_wo と password_wo_version を使う。
resource "postgresql_role" "app_ro" {
  name  = "app_ro"
  login = false
}

resource "postgresql_role" "app_rw" {
  name  = "app_rw"
  login = false
}
