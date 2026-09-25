# MySQL詳細設計書

## 1. 概要

本ドキュメントは、OCI上の Ubuntu 24.04 LTS インスタンスにおいて、ホストOSに直接導入する MySQL サーバの詳細設計を定める。Laravel 等のアプリケーションのデータストアとして利用し、パフォーマンスとセキュリティを両立させた設定を行う。

## 2. 構成・インストール

### 2.1. インストール方針

- **取得元**: Ubuntu 標準リポジトリ（APT）を使用。
- **パッケージ名**:
  - `mysql-server`: データベースサーバ
  - `mysql-client`: クライアントツール
  - `python3-pymysql`: Ansible からの操作用ライブラリ

### 2.2. サービス管理

- **ユニット名**: `mysql.service`
- **自動起動**: 有効 (`enabled`)

## 3. 詳細設計

### 3.1. ディレクトリ構成

| パス | 内容 | 備考 |
| :--- | :--- | :--- |
| `/etc/mysql/my.cnf` | メイン設定ファイル | 基本的に `conf.d` を読み込む。 |
| `/etc/mysql/mysql.conf.d/` | 詳細設定ディレクトリ | `mysqld.cnf` 等を配置。 |
| `/var/lib/mysql/` | データディレクトリ | データベースの実体。 |
| `/var/log/mysql/` | ログディレクトリ | エラーログ、スロークエリログ等。 |

### 3.2. 主要パラメータ設定 (`mysqld.cnf`)

- **接続設定**:
  - `bind-address`: `127.0.0.1` (外部からの直接接続は原則禁止)
  - `mysqlx-bind-address`: `127.0.0.1`
- **文字コード設定**:
  - `character-set-server`: `utf8mb4`
  - `collation-server`: `utf8mb4_0900_ai_ci`
- **パフォーマンス設定**:
  - `innodb_buffer_pool_size`: インスタンスメモリの 50-70% を目安に調整。
  - `max_connections`: `151` (デフォルト、必要に応じて拡張)
- **ログ設定**:
  - `slow_query_log`: `ON`
  - `long_query_time`: `2.0` (2秒以上のクエリを記録)

### 3.3. データベース・ユーザー管理

- **認証方式**: `caching_sha2_password` (MySQL 8.0 標準)
- **ユーザー設計**:
  - `root`: `auth_socket` プラグインにより、OS の特権ユーザーからパスワードなしでアクセス可能とする。
  - `app_user`: アプリケーション専用ユーザー。特定データベースへの権限のみ付与。

## 4. セキュリティ・運用

- **初期セキュリティ設定**: `mysql_secure_installation` に相当する設定を Ansible で実施。
  - 匿名ユーザーの削除。
  - リモートからの root ログイン禁止。
  - テストデータベースの削除。
- **ログローテーション**: `logrotate` により `/var/log/mysql/*.log` を 14世代管理。
- **バックアップ**: `mysqldump` による日次のダンプを取得する（[4.2. バックアップ](#42-バックアップ)）。

### 4.1. 権限モデル（管理者権限 / 運用権限）

| 区分 | ユーザー | 認証方式 | 実行主体 | 用途 |
| :--- | :--- | :--- | :--- | :--- |
| 管理者権限 | `root@localhost` | `auth_socket`（パスワードなし、OS 特権ユーザーのみ） | 人間のみ（SSH + sudo 経由で手動実行） | ユーザー作成・GRANT 変更・DB 作成等、影響範囲の大きい操作 |
| 運用権限 | `app-dbuser@localhost` | `caching_sha2_password` | AI が Ansible 経由で運用 | 個人開発プロジェクトのアプリケーションが共有する DB 接続用アカウント |

`app-dbuser` のパスワードは OCI Vault の Secret `app-dbuser-password` を真実源として管理する。
Ansible はサーバ設定時に OCI CLI（ユーザープリンシパル）経由で Secret を取得して MySQL ユーザーへ
反映し、Kubernetes 上で稼働する各プロジェクトは External Secrets Operator の
ClusterSecretStore（Instance Principal）経由で Kubernetes Secret へ同期する。
`.env` への平文の書き写しは行わない。

パスワードを変更する場合は、MySQL 側（`ALTER USER`）を先に変更し、成功を確認してから
OCI Vault に新しい Secret バージョンを登録する。この順序により、Vault の値が
MySQL の実態と乖離した状態を作らない。Vault の Secret は Terraform で初回作成のみを行い、
以降の値の更新は Terraform の管理外とする。
管理者権限（`root`）の認証情報は本リポジトリのいかなる場所にも保存しない。

### 4.2. バックアップ

| 項目 | 内容 |
| :--- | :--- |
| 実行契機 | systemd timer による日次実行 |
| 対象 | ホスト上の全データベース（ユーザー定義のデータベースを列挙して取得する） |
| ダンプ方式 | データベース単位で `mysqldump`（`--single-transaction`・ルーチン・トリガー・イベントを含む）を実行し、gzip で圧縮する |
| 実行ユーザー | `backup-dbuser@localhost`（読み取り専用。ダンプに必要な権限のみを付与する） |
| パスワード | OCI Vault の Secret `backup-dbuser-password` を真実源とし、実行時にインスタンスプリンシパルで取得する |
| 保管先 | OCI Object Storage のバケット。日次用と月次用でオブジェクトのプレフィックスを分ける |
| 認証 | インスタンスプリンシパル（Dynamic Group とポリシーで、対象バケットへの書き込みと通知の発行のみを許可する） |
| 世代 | 日次 30 世代、月次 12 世代。バケットのライフサイクルルールで自動削除する |
| 失敗時 | OCI Notifications のトピックへ発行し、メールで通知する |

## 5. 確認コマンド

- **サービス状態**: `systemctl status mysql`
- **ログイン確認**: `sudo mysql -u root`
- **設定値確認**: `mysql -u root -e "SHOW VARIABLES LIKE 'character_set_server';"`
- **データベース一覧**: `mysql -u root -e "SHOW DATABASES;"`
