# digger on CodeBuild

[![Digger Workflow](https://github.com/winebarrel/digger-codebuild-example/actions/workflows/digger_workflow.yml/badge.svg)](https://github.com/winebarrel/digger-codebuild-example/actions/workflows/digger_workflow.yml)

[digger](https://github.com/diggerhq/digger) (2025-11-07 に OpenTaco へリブランド) を
backendless モードで動かす例。ジョブは GitHub がホストするランナーではなく
[CodeBuild がホストする GitHub Actions ランナー](https://docs.aws.amazon.com/codebuild/latest/userguide/action-runner.html)
で走るので、VPC の中に入り、プライベートサブネットの RDS に届く。

管理対象は [cyrilgdn/postgresql](https://github.com/cyrilgdn/terraform-provider-postgresql)
provider で書いた PostgreSQL のロール、データベース、スキーマ、権限。

## 構成

```
digger.yml                              digger のプロジェクト定義
.github/workflows/digger_workflow.yml
aws/                                    土台。人間が手元から apply する
  tofu.tf     vpc.tf     s3.tf     dynamodb.tf
  iam.tf      codebuild.tf          rds.tf    outputs.tf
postgresql/                             digger が PR で plan / apply する
  tofu.tf                               backend, provider (空)
  role.tf     database.tf  schema.tf
  grant.tf    default_privileges.tf
```

## 仕組み

| イベント | 動くジョブ | 内容 |
| --- | --- | --- |
| `main` への PR | `digger` | `postgresql/` の plan を PR にコメント |
| `digger plan` / `digger apply` のコメント | `ack` と `digger` | `ack` がリアクションを付け、`digger` が plan か apply を実行 |

apply は人間が `digger apply` とコメントして起動する。RDS は
`publicly_accessible = false` なので、手元から `tofu apply` は打てない。
apply が成功すると `auto_merge: true` で PR がマージされる。

`ack` ジョブだけ `ubuntu-latest` で動く。リアクションと開始投稿は `gh` の
API 呼び出しだけで VPC も RDS も要らないのに、CodeBuild ランナーだと build の
プロビジョニングを待つことになり、すぐ知らせるという目的に反するため。
ラベルが CodeBuild プロジェクト名と一致しないジョブは webhook が処理されない
ので、このジョブで余計な build は起きない。

`concurrency` は `digger` ジョブに掛けている。ワークフロー全体に掛けると、
前の実行を待っている間 `ack` も止まる。

## ランナー

キューに入ったワークフロージョブが `WORKFLOW_JOB_QUEUED` の webhook を発火し、
CodeBuild がそれ1つにつき build を1つ起動して、その build が ephemeral runner
として自分を登録する。ジョブはラベルで拾う。

```yaml
runs-on: codebuild-digger-runner-${{ github.run_id }}-${{ github.run_attempt }}
```

`codebuild-` の後ろは CodeBuild プロジェクト名で、完全に一致する必要がある。
一致しないとジョブは失敗せずに永久にランナーを待つ。

ジョブは CodeBuild のサービスロールを assumed した状態で動く。OIDC も
`aws-actions/configure-aws-credentials` も要らないので、ワークフローに
`setup-aws` を書いていない。裏返しとして、ワークフローが動かすものは
全部そのロールの権限を持つ。

## provider の接続設定

`postgresql/tofu.tf` の provider ブロックは空。

```hcl
provider "postgresql" {}
```

接続設定は CodeBuild プロジェクトの環境変数から来る。provider は
`PGHOST` `PGPORT` `PGDATABASE` `PGUSER` `PGPASSWORD` `PGSSLMODE` `PGSUPERUSER`
を読む。パスワードは RDS の `manage_master_user_password` が置いた
Secrets Manager の値で、`type = "SECRETS_MANAGER"` の環境変数として渡すので
state にも GitHub の secret にも載らない。

`PGSUPERUSER` は `false`。RDS のマスターユーザは `rds_superuser` で、
本当の superuser ではない。provider のデフォルトは `true` なので明示が要る。

## state と plan

どちらも digger-example と同じ S3 バケットに置いていて、キーで分けている。

| 用途 | 置き場 |
| --- | --- |
| `aws/` の state | `digger-codebuild-example/aws/terraform.tfstate` |
| `postgresql/` の state | `digger-codebuild-example/postgresql/terraform.tfstate` |
| tfplan | バケット直下の `<owner>-<repo>-<PR番号>-<プロジェクト名>.tfplan` |
| PR ロック | DynamoDB の `DiggerDynamoDBLockTable` |

tfplan の置き場は変えられない。digger のアクションの入力はバケット名だけで、
プレフィックスを指定する口がない。リポジトリ名がキーに入るので
digger-example とは自然に分かれる。

plan ファイルの保存は必須。設定しないと apply が plan を取り直すので、
レビューした内容と違うものが適用されうる。

## 土台

`aws/` は変数を持たない。値は直接書き換える。

| ファイル | 内容 |
| --- | --- |
| `tofu.tf` | backend、provider。リージョンは `ap-northeast-1` |
| `vpc.tf` | 既存の `sandbox` VPC とプライベートサブネットの data source |
| `s3.tf` | state と tfplan のバケット。digger-example から import |
| `dynamodb.tf` | PR ロックのテーブル。digger が作ったものを import |
| `iam.tf` | ランナーのサービスロール |
| `codebuild.tf` | CodeConnections、source credential、プロジェクト、webhook、ロググループ、SG |
| `rds.tf` | PostgreSQL、サブネットグループ、SG |
| `outputs.tf` | `runs-on` のラベル、接続ステータスなど |

2つ意図的に管理外にしている。

- **NAT ゲートウェイ**。プライベートサブネットが向けている先で、手で作った。
  CodeBuild を VPC に置くと GitHub 向けの通信も VPC を通るので、NAT が
  生きていないとランナーが登録できない。
- **GitHub App の認可**。`aws_codeconnections_connection` は `PENDING` で
  作られ、OAuth のハンドシェイクはコンソールでしか終わらせられない。

### 立ち上げ

state を置くバケットは既にあるので、いきなりこの backend で init できる。

```sh
cd aws
tofu init
tofu apply -target aws_codeconnections_connection.github
```

[Developer Tools > Settings > Connections](https://ap-northeast-1.console.aws.amazon.com/codesuite/settings/connections?region=ap-northeast-1)
で接続を選び **Update pending connection**。AWS Connector for GitHub を認可し、
入れるアカウントと見せるリポジトリを選ぶ。

個人アカウントより organization に入れたほうがよい。接続がクリックした人ではなく
installation に依存するようになる。installation token の接続である点がここでは
効いてくる。user token の接続は2つの build が同時にトークンを更新すると自分の
トークンを無効化するが、このランナーはジョブごとに build を1つ起動する。

```sh
tofu output connection_status   # AVAILABLE になること
tofu apply
```

`aws_codebuild_source_credential` はアカウント、リージョン、サーバタイプごとに
1つだけ。既に GitHub のクレデンシャルがあるリージョンなら、このリソースを
外して既存を使う。
