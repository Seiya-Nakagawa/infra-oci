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
| `scripts/` | このリポジトリ固有のスクリプト（`run_ansible.sh`） |
| `docs/` | 要件定義書・基本設計書・詳細設計書・構築手順書 |

インフラのライフサイクルは、`terraform/` でインスタンスを作成したうえで `ansible/` で
OS・ミドルウェアを構成する 2 段構成になっている。
本リポジトリにはステージング環境・CI/CD は無く、単一環境に対してローカルから適用する。

## 2. 固有コマンド

すべてリポジトリのルートディレクトリから実行する。

### 2.1. Terraform

- plan / apply / SSH 接続はグローバル共通スクリプト（`~/.claude/scripts/tf_plan.sh`・
  `tf_apply.sh`・`tf_ssh_connect.sh`）を既定値のまま使用する
- Terraform Cloud のセットアップ手順は
  [01_TerraformCloudセットアップ.md](docs/04.build/01_TerraformCloudセットアップ.md) を参照する

### 2.2. Ansible

- `./scripts/run_ansible.sh [ansible-playbook のオプション]`: `terraform output` から接続先
  （`instance_public_ip`・`instance_user`・`oci_vault_id`・`oci_region`・`oci_compartment_ocid`）を
  解決して `ansible-playbook` を実行する。引数はそのまま `ansible-playbook` へ渡る
- ロール単位で適用する場合は同名のタグ（`--tags os` など）を指定する
- MySQL のパスワード等は Ansible Vault で暗号化する。Vault パスワードは
  `ansible/.vault_password`（Git 管理外）に置き、`ansible/ansible.cfg` の `vault_password_file` で
  参照するため、実行時のオプション指定は不要
