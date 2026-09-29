# CLAUDE.md

このファイルは、本リポジトリ固有の事情を記録したものです。

基本方針・機密情報の取り扱い・Git 運用・コーディング規約・Markdown 記法などの共通規約は
グローバル規約（`~/.claude/`、`~/.gemini/`）に従います。
**本ファイルに共通規約を重複定義しないこと。**

## 1. リポジトリ構成

| ディレクトリ | 責務 |
| ---- | ---- |
| `terraform/` | OCI インフラ定義（VCN・サブネット・Compute・Vault 等）。state は Terraform Cloud（CLI-driven workflow）で管理する |
| `ansible/` | Compute インスタンスの構成管理。`site.yml` が `os` → `kubernetes` → `mysql` → `backup` の順に 4 つのロールを適用する |
| `scripts/` | このリポジトリ固有のスクリプト（`run_ansible.sh`・`run_ansible_bastion.sh`） |
| `docs/` | 要件定義書・基本設計書・詳細設計書・構築手順書 |

インフラのライフサイクルは、`terraform/` でインスタンスを作成したうえで `ansible/` で
OS・ミドルウェアを構成する 2 段構成になっている。
本リポジトリはステージング環境を持たない単一環境の構成である。
Terraform・Ansible とも GitHub Actions による CI/CD（PR でドライラン、main マージで実適用）を経由する。
Ansible は OCI Bastion の Managed SSH Session 経由で接続し、セキュリティ・リストへ
新たな SSH ポートを開放しない
（[8章 基本設計書_基盤制御](docs/02.design/08.platform-control/8章_基本設計書_基盤制御.md) 参照）。

## 2. 固有コマンド

すべてリポジトリのルートディレクトリから実行する。

### 2.1. Terraform

- **本番適用（apply）は GitHub Actions 経由のみ**とする。ローカルから `apply` は行わない
- ローカルでは `~/.claude/scripts/tf_plan.sh` で `plan` の内容確認のみ行う。
  `tf_apply.sh` による本番適用は行わない。`tf_ssh_connect.sh` は引き続きインスタンスへの
  SSH 接続確認に使用する
- Terraform Cloud のセットアップ手順は
  [01_TerraformCloudセットアップ.md](docs/04.build/01_TerraformCloudセットアップ.md)、
  GitHub Actions のセットアップ手順は
  [05_GitHubActionsセットアップ.md](docs/04.build/05_GitHubActionsセットアップ.md) を参照する

### 2.2. Ansible

- **本番適用（実適用）は GitHub Actions 経由のみ**とする。ローカルからの実適用は行わない
- `./scripts/run_ansible.sh [ansible-playbook のオプション]`: 作業端末から直接 SSH で接続する
  ローカル実行用。`terraform output` から接続先
  （`instance_public_ip`・`instance_user`・`oci_vault_id`・`oci_region`・`oci_compartment_ocid`）を
  解決して `ansible-playbook` を実行する。引数はそのまま `ansible-playbook` へ渡る。
  内容確認（`--check`）または障害調査時の直接 SSH 接続にのみ使用する
- `./scripts/run_ansible_bastion.sh [ansible-playbook のオプション]`: GitHub Actions から
  OCI Bastion の Managed SSH Session を経由して接続する CI/CD 用。`Ansible CI/CD` ワークフロー
  （`.github/workflows/ansible.yml`）が使用する。ローカルから手動実行する場合は、
  CI/CD 専用 IAM ユーザーの API キーで OCI CLI が認証済みであることが前提
- ロール単位で適用する場合は同名のタグ（`--tags os` など）を指定する
- MySQL のパスワード等は Ansible Vault で暗号化する。Vault パスワードは
  `ansible/.vault_password`（Git 管理外）に置き、`ansible/ansible.cfg` の `vault_password_file` で
  参照するため、実行時のオプション指定は不要
- OCI Bastion のセットアップ手順は
  [06_OCIBastionセットアップ.md](docs/04.build/06_OCIBastionセットアップ.md) を参照する
