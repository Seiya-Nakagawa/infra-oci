# 08 構築手順書 - OAuth クライアント資格情報の Vault シークレット追加

## 目次

- [1. 概要](#1-概要)
- [2. 前提条件](#2-前提条件)
- [3. 手順](#3-手順)
  - [3.1. Terraform の変更内容を確認する](#31-terraform-の変更内容を確認する)
  - [3.2. 適用後にシークレットを確認する](#32-適用後にシークレットを確認する)
  - [3.3. 実際の値を登録する](#33-実際の値を登録する)
  - [3.4. 不要になった場合の削除](#34-不要になった場合の削除)

## 1. 概要

Issue #156 の対応。Portfolio（SkillSheet）の外部アカウント認証（Google・GitHub）で使う OAuth クライアントの
ID・シークレットを保持する Vault シークレットを、Terraform で作成する。設計は
[6章 セキュリティ設計](../02.design/06.security/6章_基本設計書_セキュリティ設計.md) の 6.5 節を参照する。

| Vault のシークレット名 | 内容 |
| ---------------------- | ---- |
| `portfolio-google-client-id` | Google の本番用 OAuth クライアントの ID |
| `portfolio-google-client-secret` | Google の本番用 OAuth クライアントのシークレット |
| `portfolio-github-client-id` | GitHub の本番用 OAuth App の Client ID |
| `portfolio-github-client-secret` | GitHub の本番用 OAuth App のシークレット |

Terraform が管理するのは入れ物のみで、値は管理しない。値を渡すと state に平文で残るため、
作成時はプレースホルダーを設定し、実際の値は運営者が OCI コンソールで登録する。
`secret_content` は `ignore_changes` としており、登録した値を Terraform が巻き戻すことはない。

## 2. 前提条件

- 変更は GitHub Actions（`Terraform CI/CD`）で適用する。PR では plan、`main` へのマージで apply が実行される
- Google・GitHub の本番用 OAuth クライアントが作成済みで、ID・シークレットを控えていること
  （Portfolio リポジトリの構築手順書 21 を参照）

## 3. 手順

### 3.1. Terraform の変更内容を確認する

PR 上の plan 結果で、次のとおりであることを確認する。

- `Plan: 4 to add, 0 to change, 0 to destroy.`
- 追加されるのが `oci_vault_secret.portfolio_oauth` の 4 件のみであること

### 3.2. 適用後にシークレットを確認する

マージ後の CD 完了後、OCI コンソールで確認する。

1. 「アイデンティティとセキュリティ」→「ボールト」を開き、`{project_name}-vault` を選ぶ
2. 「シークレット」に、上表の 4 つが「アクティブ」で表示されること
3. この時点の値はプレースホルダーである（実際の値の登録は 3.3 で行う）

### 3.3. 実際の値を登録する

3.2 の 4 つのシークレットそれぞれに、本番用の値を新しいバージョンとして登録する。

1. シークレットの名前をクリックし、左メニューの「バージョン」を開く
2. 「新規バージョンの作成」を押す
3. 「シークレット・タイプのテンプレート」で「プレーン・テキスト」を選び、「シークレットの内容」に値を貼る
   - 値の前後に空白・改行を入れない
4. 「新規バージョンの作成」を押し、最新のバージョンが「現行」になっていること

- 値はチャット・リポジトリに貼らない
- 新しいバージョンが現行になると、External Secrets Operator が次回の同期で取得する

### 3.4. 不要になった場合の削除

Terraform で管理しているため、`terraform/vault.tf` の `portfolio_oauth` のブロックと `locals` を削除する PR を
作成し、マージする。

- `prevent_destroy` は、ブロックが残ったまま削除・置換される plan を止めるための設定である。
  ブロック自体を削除する場合は、そのまま削除できる
- OCI のシークレットはスケジュール削除になる（最短 1 日）。削除予定の間は同じ名前で再作成できない
- Portfolio 側の `k8s/vault-sync.yaml` からの参照も、あわせて削除する
