# 05 構築手順書 - GitHub Actions セットアップ

## 目次

- [1. 概要](#1-概要)
- [2. 前提条件](#2-前提条件)
- [3. 手順](#3-手順)
  - [3.1. Terraform Cloud Team の作成](#31-terraform-cloud-team-の作成)
  - [3.2. Team API トークンの発行](#32-team-api-トークンの発行)
  - [3.3. GitHub Secrets への登録](#33-github-secrets-への登録)
  - [3.4. 動作確認](#34-動作確認)

## 1. 概要

Terraform の plan（Pull Request）・apply（main マージ）を GitHub Actions から実行するため、
Terraform Cloud 側に GitHub Actions 専用の Team を作成し、その API トークンを GitHub Secrets へ
登録する手順。ワークフローの位置づけは
[8章 基盤制御 8.3節](../02.design/08.platform-control/8章_基本設計書_基盤制御.md#83-インフラ層の実行方式terraform)
を参照する。

## 2. 前提条件

- Terraform Cloud の Workspace `infra-oci` が作成済みであること
  （[Terraform Cloud セットアップ](01_TerraformCloudセットアップ.md)）
- リポジトリの管理者権限を持つこと（GitHub Secrets の登録に必要）

## 3. 手順

### 3.1. Terraform Cloud Team の作成

1. Terraform Cloud の Organization Settings → **Teams** を開く
2. **Create a team** から `github-actions` を作成する
3. Workspace `infra-oci` の **Team Access** に `github-actions` を追加し、
   権限を **Plan** と **Apply**（Write）に設定する

### 3.2. Team API トークンの発行

1. 作成した `github-actions` Team の **Team API Token** から **Create an API token** を選択する
2. 表示されたトークンを控える（再表示できないため必ず控える）

### 3.3. GitHub Secrets への登録

```bash
gh secret set TFC_API_TOKEN --repo Seiya-Nakagawa/infra-oci
```

- コマンド実行後、標準入力で控えたトークンを貼り付けて登録する
- トークンの値はチャットへ貼り付けず、上記コマンドの標準入力へ直接入力する

### 3.4. 動作確認

1. `terraform/` 配下に差分を含む Pull Request を作成し、
   `Terraform CI/CD` ワークフローの `plan` ジョブが成功することを確認する
2. main へマージし、`apply` ジョブが成功することを確認する
