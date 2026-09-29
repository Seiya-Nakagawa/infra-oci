# 06 構築手順書 - OCI Bastion セットアップ

## 目次

- [1. 概要](#1-概要)
- [2. 前提条件](#2-前提条件)
- [3. 手順](#3-手順)
  - [3.1. CI/CD 専用 IAM ユーザーの作成](#31-cicd-専用-iam-ユーザーの作成)
  - [3.2. API 署名キーの発行](#32-api-署名キーの発行)
  - [3.3. GitHub Secrets への登録](#33-github-secrets-への登録)
  - [3.4. 動作確認](#34-動作確認)

## 1. 概要

Issue #135 の対応。GitHub Actions から Ansible を OCI Bastion の Managed SSH Session 経由で
適用するため、CI/CD 専用の IAM ユーザーを用意し、その API キーを GitHub Secrets へ登録する手順。
ワークフローの位置づけは
[8章 基盤制御 8.4節](../02.design/08.platform-control/8章_基本設計書_基盤制御.md#84-構成管理層の実行方式ansible)
を参照する。

IAM ユーザー本体の作成は本リポジトリのスコープ外（[7章 アカウント管理](../02.design/07.account/7章_基本設計書_アカウント管理.md)）
のため、管理者（OCI テナンシの管理者）が手動で行う。Terraform が管理するグループ・ポリシー
（`infra-oci-cicd-bastion-group` と `manage bastion-session` / `read bastion` のみを許可するポリシー）は
Issue #135 のインフラ層 PR で作成済みであることを前提とする。

## 2. 前提条件

- `terraform/bastion.tf`・`terraform/iam-bastion.tf` が適用済みであり、
  `infra-oci-cicd-bastion-group` グループと `infra-oci-cicd-bastion-policy` ポリシーが
  OCI テナンシに存在すること
- OCI テナンシの管理者権限を持つこと（IAM ユーザーの作成に必要）
- リポジトリの管理者権限を持つこと（GitHub Secrets の登録に必要）

## 3. 手順

### 3.1. CI/CD 専用 IAM ユーザーの作成

1. OCI コンソールの **Identity & Security > Users** から、CI/CD 専用のユーザーを新規作成する
   （例: `github-actions-ansible-bastion`）
2. 作成したユーザーを `infra-oci-cicd-bastion-group` グループへ追加する

### 3.2. API 署名キーの発行

1. 作成したユーザーの詳細画面から **API Keys > Add API Key** を開く
2. **Generate API Key Pair** を選択し、秘密鍵をダウンロードする
3. 表示される設定プレビューから、以下の値を控える
   - User OCID
   - Fingerprint
   - Tenancy OCID
   - Region

### 3.3. GitHub Secrets への登録

```bash
gh secret set BASTION_OCI_USER_OCID --repo Seiya-Nakagawa/infra-oci
gh secret set BASTION_OCI_FINGERPRINT --repo Seiya-Nakagawa/infra-oci
gh secret set BASTION_OCI_PRIVATE_KEY --repo Seiya-Nakagawa/infra-oci
gh secret set ANSIBLE_VAULT_PASSWORD --repo Seiya-Nakagawa/infra-oci
```

- 各コマンド実行後、標準入力で対応する値を貼り付けて登録する
  （`BASTION_OCI_PRIVATE_KEY` は 3.2 でダウンロードした秘密鍵ファイルの内容全体）
- `ANSIBLE_VAULT_PASSWORD` は、ローカルの `ansible/.vault_password` に設定済みの値と同一のものを登録する
- 値はチャットへ貼り付けず、上記コマンドの標準入力へ直接入力する

### 3.4. 動作確認

1. `ansible/` 配下に差分を含む Pull Request を作成し、
   `Ansible CI/CD` ワークフローの `check` ジョブ（`--check` ドライラン）が成功することを確認する
2. main へマージし、`apply` ジョブが成功することを確認する
