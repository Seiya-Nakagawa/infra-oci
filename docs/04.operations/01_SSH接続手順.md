# 01 運用手順書 - SSH 接続手順

## 目次

- [1. 概要](#1-概要)
- [2. 前提条件](#2-前提条件)
- [3. 手順](#3-手順)
  - [3.1. 接続スクリプトによる接続](#31-接続スクリプトによる接続)
  - [3.2. 手動での接続](#32-手動での接続)
  - [3.3. トラブルシューティング](#33-トラブルシューティング)

## 1. 概要

Terraform で構築した Compute インスタンスへ、許可された IP から直接 SSH 接続（TCP 22 ポート）する手順。
接続構成は [基本設計書 3.1節](../02.design/DESIGN.md#31-ネットワーク-vcn) を参照する。

## 2. 前提条件

- Compute インスタンスに登録した SSH 秘密鍵がローカル端末にあること
- ローカル端末に SSH クライアントおよび `jq` がインストールされていること
- `terraform` コマンドが実行可能で、`terraform output` が取得できる状態であること

## 3. 手順

### 3.1. 接続スクリプトによる接続

```bash
~/.claude/scripts/tf_ssh_connect.sh
```

- `terraform output` からインスタンスのパブリック IP と接続ユーザーを取得し、SSH 接続を開始する

デフォルトの秘密鍵（`~/.ssh/id_rsa`）以外を使用する場合は `-i` で指定する。

```bash
~/.claude/scripts/tf_ssh_connect.sh -i ~/.ssh/my_oci_key
```

- `-i` で SSH 秘密鍵のパスを指定して接続する

### 3.2. 手動での接続

```bash
cd terraform
terraform output instance_public_ip
```

- インスタンスのパブリック IP アドレスを表示する

```bash
ssh -i ~/.ssh/id_rsa seiya@<INSTANCE_PUBLIC_IP>
```

- 取得したパブリック IP と管理ユーザー名（デフォルト: `seiya`）で SSH 接続する

### 3.3. トラブルシューティング

SSH 接続がタイムアウトする場合は、以下を確認する。

- OCI のセキュリティ・リスト（`terraform/network.tf`）で、接続元 IP アドレスが `allowed_client_cidr` として許可されているか
- インスタンスの起動が完了しているか（起動直後は SSH 接続ができるまで数分かかる場合がある）
