# 01 構築手順書 - Terraform Cloud セットアップ

## 目次

- [1. 概要](#1-概要)
- [2. 前提条件](#2-前提条件)
- [3. 手順](#3-手順)
  - [3.1. OCI API 鍵の生成](#31-oci-api-鍵の生成)
  - [3.2. OCI コンソールでの API 鍵登録](#32-oci-コンソールでの-api-鍵登録)
  - [3.3. Terraform Cloud の Workspace 作成](#33-terraform-cloud-の-workspace-作成)
  - [3.4. Workspace Variables の設定](#34-workspace-variables-の設定)
  - [3.5. cloud ブロックの確認](#35-cloud-ブロックの確認)
  - [3.6. Terraform Cloud へのログイン](#36-terraform-cloud-へのログイン)
  - [3.7. 初期化と動作確認](#37-初期化と動作確認)

## 1. 概要

Terraform Cloud をリモートバックエンドとし、ローカルから `terraform` コマンドを実行して OCI 上に
インフラを構築する CLI-driven workflow のセットアップ手順。Terraform Cloud の位置づけは
[基本設計書 8.3節](../02.design/08.platform-control/8章_基本設計書_基盤制御.md#83-インフラ層の実行方式terraform)
を参照する。

## 2. 前提条件

- Terraform Cloud のアカウントを作成済みであること
- OCI のアカウントを作成済みであること
- `terraform` コマンドがローカルにインストール済みであること

## 3. 手順

### 3.1. OCI API 鍵の生成

Terraform が OCI へ接続する際に使用する API 鍵を生成する。

```bash
mkdir -p ~/.oci
```

```bash
openssl genrsa -out ~/.oci/oci_api_key.pem 2048
```

```bash
openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem
```

```bash
chmod 600 ~/.oci/oci_api_key.pem
```

- 2 番目のコマンドは、RSA 2048 bit の秘密鍵を生成する
- 3 番目のコマンドは、秘密鍵から公開鍵を生成する
- 4 番目のコマンドは、秘密鍵を所有者のみ読み書き可能にする

### 3.2. OCI コンソールでの API 鍵登録

1. [OCI Console](https://cloud.oracle.com/) にログインする
2. 右上のプロファイルアイコンから **User Settings** を開く
3. 左メニューの **API Keys** から **Add API Key** を選択する
4. `~/.oci/oci_api_key_public.pem` の内容を貼り付けて登録する
5. 表示された **Fingerprint** を控える
6. 次の値を OCI コンソールから控える
   - **Tenancy OCID**: プロファイル → Tenancy → OCID
   - **User OCID**: プロファイル → User Settings → OCID
   - **Compartment OCID**: Identity → Compartments → 使用する Compartment → OCID

### 3.3. Terraform Cloud の Workspace 作成

1. [Terraform Cloud](https://app.terraform.io/) にログインする
2. Organization が無ければ **Create Organization** から作成する
3. **New Workspace** から **CLI-driven workflow** を選択する
4. Workspace 名に `infra-oci` を入力し、**Create workspace** で作成する

### 3.4. Workspace Variables の設定

Workspace の **Variables** タブで、以下の Terraform Variables を登録する。

| 変数名 | 内容 | Sensitive |
| ------ | ---- | --------- |
| `tenancy_ocid` | Tenancy OCID | 有効 |
| `user_ocid` | User OCID | 有効 |
| `fingerprint` | API 鍵の Fingerprint | 有効 |
| `private_key` | 秘密鍵の内容（改行を含めたそのままの文字列） | 有効 |
| `compartment_ocid` | Compartment OCID | 有効 |
| `ssh_public_key` | インスタンスに登録する SSH 公開鍵 | 無効 |

`private_key` には、秘密鍵ファイルの内容をそのまま貼り付ける。

```bash
cat ~/.oci/oci_api_key.pem
```

- 秘密鍵ファイルの内容を表示する。出力全体をコピーして `private_key` に貼り付ける

上記以外の変数（`region`、`allowed_ssh_cidr` 等）は既定値を持つため、変更が必要な場合のみ登録する。
複数の Workspace で OCI 認証情報を共有する場合は、Organization Settings の **Variable sets** に
共通変数（`tenancy_ocid`、`user_ocid`、`fingerprint`、`private_key`）をまとめ、対象 Workspace へ適用する。

### 3.5. cloud ブロックの確認

`terraform/versions.tf` の `cloud` ブロックが、作成した Organization 名と Workspace 名に一致することを
確認する。

```hcl
terraform {
  cloud {
    organization = "{Organization 名}"
    workspaces {
      name = "infra-oci"
    }
  }
}
```

### 3.6. Terraform Cloud へのログイン

```bash
terraform login
```

- ブラウザが開く（または URL が表示される）ので、Terraform Cloud のトークンを発行し、
  ターミナルに貼り付ける

### 3.7. 初期化と動作確認

リポジトリのルートディレクトリで、グローバル共通スクリプトを実行する。

```bash
~/.claude/scripts/tf_plan.sh
```

- `terraform fmt`、`init`、`validate`、`plan` を順に実行し、実行計画を `terraform/tfplan` に保存する
- Plan の結果が意図どおりであることを確認したうえで、次のコマンドで適用する

```bash
~/.claude/scripts/tf_apply.sh
```

- `terraform/tfplan` を適用する。適用後は実行計画ファイルを削除する

適用後、`terraform output` で `instance_public_ip` 等の出力値が取得できることを確認する。

```bash
terraform -chdir=terraform output
```
