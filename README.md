# infra-oci - OCI Infrastructure

Oracle Cloud Infrastructure (OCI) 上の個人開発基盤を、インフラのプロビジョニング（Terraform）から
サーバの構成管理（Ansible）まで一元管理するリポジトリです。

## 📁 リポジトリ構成

| ディレクトリ | 内容 |
| ------------ | ---- |
| `terraform/` | VCN・サブネット・Compute インスタンスなどの OCI リソース定義 |
| `ansible/` | OS・Kubernetes・MySQL の構成管理を行う Playbook と Role |
| `scripts/` | このリポジトリ固有のスクリプト（Ansible 実行） |
| `docs/` | 要件定義書・基本設計書・詳細設計書・構築手順書 |

インフラのライフサイクルは、`terraform/` でインスタンスを作成したうえで `ansible/` で
OS・ミドルウェアを構成する 2 段構成になっています。

## 📋 ドキュメント

* **[要件定義書](docs/01.requirements/REQUIREMENTS.md)**: システムの目的、管理対象範囲、機能要件・非機能要件
* **[基本設計書](docs/02.design/DESIGN.md)**: システム構成、リソース設計、技術スタック
* **[OS詳細設計書](docs/03.detailed-design/OS詳細設計書.md)** / **[Kubernetes詳細設計書](docs/03.detailed-design/Kubernetes詳細設計書.md)** / **[MySQL詳細設計書](docs/03.detailed-design/MySQL詳細設計書.md)**: 各レイヤーの詳細設計
* **[Terraform Cloud セットアップ](docs/04.build/01_TerraformCloudセットアップ.md)**: Workspace の設定手順
* **[SSH接続手順](docs/04.build/02_SSH接続手順.md)**: パブリックIPを経由した直接 SSH 接続手順
* **[Ansibleによるサーバ構成管理](docs/04.build/03_Ansibleによるサーバ構成管理.md)**: OS / Kubernetes / MySQL の構築手順

---

## 🚀 Terraform（インフラのプロビジョニング）

Terraform Cloud をリモートバックエンドとして利用し、ローカルから `terraform` コマンドを実行する
**CLI-driven workflow** を採用しています。
詳細なセットアップ・実行手順は **[Terraform Cloud セットアップ](docs/04.build/01_TerraformCloudセットアップ.md)** を参照してください。

### メリット

✅ **Stateのセキュアな管理**: tfstate が Terraform Cloud 上で暗号化・管理され、ローカルに保持する必要がない
✅ **チーム開発**: Stateのロックと共有が自動管理される
✅ **監査ログ**: Plan/Applyの実行履歴が Terraform Cloud に記録される
✅ **セキュアな環境変数管理**: OCIの認証情報などを Terraform Cloud 側に保持可能
✅ **無料枠**: 個人利用は無料

### 1. Terraform Cloud へのログイン

```bash
terraform login
```

※ブラウザが開く（またはURLが表示される）ので、トークンを発行してターミナルに貼り付けます。

### 2. 環境変数の設定 (Terraform Cloud)

Terraform Cloud の GUI にアクセスし、該当 Workspace の Variables に OCI の認証情報（`tenancy_ocid`, `user_ocid`, `fingerprint`, `private_key` など）を登録してください。

### 3. 実行

```bash
# fmt → init → validate → plan を実行し、実行計画を terraform/tfplan に保存する
~/.claude/scripts/tf_plan.sh

# terraform/tfplan を適用する
~/.claude/scripts/tf_apply.sh
```

### 4. 出力の確認

```bash
cd terraform
terraform output
```

---

## 🔧 Ansible（サーバの構成管理）

`ansible/site.yml` は `os` → `kubernetes` → `mysql` の順に 3 つのロールを適用します。

```bash
# ドライラン（影響範囲の確認）
./scripts/run_ansible.sh --check

# 適用
./scripts/run_ansible.sh

# ロール単位で適用する場合
./scripts/run_ansible.sh --tags os
```

接続情報は `terraform output` から自動取得します。
MySQL のパスワード等の機密情報は Ansible Vault で暗号化しています。
Vault パスワードは `ansible/.vault_password`（Git 管理外）に配置してください。
`ansible/ansible.cfg` の `vault_password_file` から参照されるため、
`--vault-password-file` オプションの指定は不要です。

```bash
echo "{Vault のパスワード}" > ansible/.vault_password
chmod 600 ansible/.vault_password
```

### SSH 接続

```bash
~/.claude/scripts/tf_ssh_connect.sh          # ~/.ssh/id_rsa を使用
~/.claude/scripts/tf_ssh_connect.sh -i <key> # 秘密鍵を指定
```

---

## 🔐 セキュリティ

* **機密情報の管理**: `terraform.tfvars` と `ansible/.vault_password` は `.gitignore` に含まれており、Gitにコミットされません
* **SSH制限**: `allowed_client_cidr` を自分のIPアドレスに制限することを推奨
* **API鍵の管理**: 秘密鍵ファイルは適切なパーミッション (600) で保護してください

## 📝 リソースの削除

```bash
cd terraform
terraform destroy
```

## 🔍 トラブルシューティング

### エラー: "Service error:NotAuthorizedOrNotFound"

* Compartment OCIDが正しいか確認
* ユーザーに適切な権限が付与されているか確認

### エラー: "Out of host capacity"

* 別のAvailability Domainを試す
* 別のリージョンを試す
* 時間を空けて再試行

### インスタンスにSSH接続できない

* Security Listのルールを確認
* SSH公開鍵が正しく設定されているか確認
* インスタンスの起動が完了しているか確認 (cloud-initの実行完了まで数分かかる場合があります)

## 📚 参考リンク

* [OCI Provider Documentation](https://registry.terraform.io/providers/oracle/oci/latest/docs)
* [OCI Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
* [Terraform Best Practices](https://www.terraform-best-practices.com/)
* [Ansible Documentation](https://docs.ansible.com/)
