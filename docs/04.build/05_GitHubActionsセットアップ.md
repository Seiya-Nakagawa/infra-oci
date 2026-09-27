# 05 構築手順書 - GitHub Actions セットアップ

## 目次

- [1. 概要](#1-概要)
- [2. 前提条件](#2-前提条件)
- [3. 手順](#3-手順)
  - [3.1. Terraform Cloud API トークンの発行](#31-terraform-cloud-api-トークンの発行)
  - [3.2. GitHub Secrets への登録](#32-github-secrets-への登録)
  - [3.3. 動作確認](#33-動作確認)

## 1. 概要

Terraform の plan（Pull Request）・apply（main マージ）を GitHub Actions から実行するため、
Terraform Cloud の API トークンを発行し、GitHub Secrets へ登録する手順。ワークフローの位置づけは
[8章 基盤制御 8.3節](../02.design/08.platform-control/8章_基本設計書_基盤制御.md#83-インフラ層の実行方式terraform)
を参照する。

Terraform Cloud の Team management は有料機能であり、Free の Organization では
`owners` チーム以外の Team・Team API Token を作成できない。そのため、
Organization の Owner が自身のアカウントで発行する User API Token を使用する。
権限範囲は、現状ローカルの `terraform login` で使用している認証情報と同じ
（Organization 内の操作が可能な Owner 権限）であり、ローカルから GitHub Actions へ
実行主体が変わるだけで、権限範囲が広がるわけではない。

## 2. 前提条件

- Terraform Cloud の Workspace `infra-oci` が作成済みであること
  （[Terraform Cloud セットアップ](01_TerraformCloudセットアップ.md)）
- リポジトリの管理者権限を持つこと（GitHub Secrets の登録に必要）

## 3. 手順

### 3.1. Terraform Cloud API トークンの発行

1. Terraform Cloud 右上のアバターアイコンから **Account settings** を開く
2. 左メニューの **Tokens** を開く
3. **Create an API token** から、Description に `github-actions` と入力してトークンを発行する
4. 表示されたトークンを控える（再表示できないため必ず控える）

### 3.2. GitHub Secrets への登録

```bash
gh secret set TFC_API_TOKEN --repo Seiya-Nakagawa/infra-oci
```

- コマンド実行後、標準入力で控えたトークンを貼り付けて登録する
- トークンの値はチャットへ貼り付けず、上記コマンドの標準入力へ直接入力する

### 3.3. 動作確認

1. `terraform/` 配下に差分を含む Pull Request を作成し、
   `Terraform CI/CD` ワークフローの `plan` ジョブが成功することを確認する
2. main へマージし、`apply` ジョブが成功することを確認する
