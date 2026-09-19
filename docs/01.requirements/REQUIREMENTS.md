# 要件定義書 - OCI 個人開発基盤

## 1. プロジェクト概要

### 1.1. 目的

個人開発における複数のサービスを公開・稼働させるための共通基盤を OCI（Oracle Cloud Infrastructure）上に構築する。
インフラのプロビジョニングからサーバの OS・ミドルウェア構成までをコード化し、再現性の高い環境を実現する。

### 1.2. 背景

複数の個人開発サービスを個別のサーバで運用するとコストと運用負荷が増大するため、
1 台の共通サーバ上に Kubernetes 基盤を構築し、サービスを集約して稼働させる。
将来的な機能拡張やコンテナの稼働も見据え、十分なリソースを確保しつつ運用コストを最適化する。

### 1.3. 方針

インフラのライフサイクルを以下の 2 層に分けて管理する。

| 層 | 管理ツール | 管理対象 |
| -- | ---------- | -------- |
| インフラ層 | Terraform | VCN、サブネット、セキュリティ・リスト、Compute インスタンス |
| 構成管理層 | Ansible | OS 設定、Kubernetes、MySQL |

Terraform（cloud-init）による初期化は OS レベルの最小限の設定（タイムゾーン、管理ユーザーの作成と
SSH 鍵登録）に留め、ミドルウェアやアプリケーションの詳細な構成管理は Ansible へ委譲する。

## 2. 対象範囲

### 2.1. スコープ内

- OCI 上のネットワーク（VCN、サブネット、ルーティング、セキュリティ・リスト）の構築
- Compute インスタンスの構築
- OS 設定（システム共通設定、パッケージ管理、ユーザー・権限管理、セキュリティ基盤）
- Kubernetes 基盤（シングルノードクラスター、CNI、Ingress Controller、cert-manager）の構築
- MySQL の導入・設定（ホスト OS 直接インストール）
- 各サービスで共通して利用するライブラリ・ランタイムの導入

### 2.2. スコープ外

- アプリケーションレイヤー（コンテナイメージ、Kubernetes マニフェスト等）。各アプリケーションのリポジトリで管理する
- OCI テナンシ自体の管理（IAM ユーザー、コンパートメント設計等）

### 2.3. 現行機能との差分

該当なし。

## 3. 用語定義

| 用語 | 説明 |
| ---- | ---- |
| OCI | Oracle Cloud Infrastructure |
| Always Free | OCI が提供する無期限無料利用枠 |
| VCN | Virtual Cloud Network。OCI 上の仮想ネットワーク |
| Role | Ansible における構成管理単位。本プロジェクトでは `os` / `kubernetes` / `mysql` の 3 つ |

## 4. 機能要件

### 4.1. インフラのプロビジョニング

- ネットワーク（VCN、Public Subnet、Internet Gateway、セキュリティ・リスト）を構築する
- Compute インスタンスを構築し、パブリック IP を割り当てる
- cloud-init により、タイムゾーン設定・管理ユーザー作成・SSH 公開鍵登録を行う

### 4.2. OS 全般設定

- システム共通設定（タイムゾーン、ロケール、ホスト名管理）
- パッケージマネージャーの最適化とパッケージの最新化
- ユーザー・グループ管理および権限設定（sudo 等）
- セキュリティ基盤（SSH の堅牢化、ファイアウォール設定等）
- 共通で利用するシステムユーティリティの導入

### 4.3. Kubernetes 環境構築

- シングルノード構成の Kubernetes クラスター導入
- 必要なアドオン（CNI、Ingress Controller `ingress-nginx`、cert-manager）のセットアップ
- Ingress Controller は外部から直接 HTTP/HTTPS（80/443）トラフィックを受信する構成とする
- cert-manager の ClusterIssuer により Let's Encrypt の証明書を自動発行する

### 4.4. データベース管理

- MySQL サーバーの導入と初期設定（文字コード、接続制限等）
- スキーマ単位でのデータベース作成およびユーザー権限管理
- Kubernetes 上のアプリケーションからの安全な接続許可設定

## 5. 管理対象データ

MySQL 上に、各個人開発サービスのデータをスキーマ単位で分離して保持する。

### 5.1. データに関する業務ルール

- サービスごとにスキーマを分離し、相互のデータへ直接アクセスしない
- データベース接続情報は OCI Vault（Secrets Management）を真実源として一元管理し、
  各個人開発プロジェクトの `.env` へ平文で書き写す運用は行わない

## 6. 非機能要件

### 6.1. 可用性

単一インスタンス構成のため冗長化は行わない。障害時は Terraform / Ansible による再構築で復旧する。

### 6.2. 性能

ARM アーキテクチャの `VM.Standard.A1.Flex` シェイプを利用し、4 OCPU / 24 GB RAM を確保する。

### 6.3. セキュリティ

- インターネット経由での Web アクセス（HTTP:80、HTTPS:443）を許可する
- 運用管理のため、許可された IP からの直接の SSH 接続（TCP:22）を許可する
- SSH は公開鍵認証のみとし、パスワード認証を無効化する
- 機密情報（パスワード、API キー等）は Ansible Vault、Terraform Cloud の Variable（Sensitive）、
  または OCI Vault（Secrets Management）で管理する
- Kubernetes 上で稼働する各プロジェクトは、OCI Vault の Secret を External Secrets Operator
  経由で Kubernetes Secret へ同期して参照する

### 6.4. バックアップ・リストア

構成情報は本リポジトリのコードを正とし、環境の再構築によってリストアする。

### 6.5. 運用・保守

- インフラの構成管理は Terraform、サーバの構成管理は Ansible を用いてコード化し、再現性を担保する
- Terraform は CLI-driven workflow を前提とし、ローカルから `terraform login` を経由して実行する
- Ansible は役割ごとに Role を分割し、見通しの良いディレクトリ構成とする
- サーバ作業の実行コマンドと出力は証跡として記録する

### 6.6. コスト

ランニングコストを最小限に抑えるため、OCI の Always Free 枠（`VM.Standard.A1.Flex`、200 GB Boot Volume など）を最大限に活用する。

### 6.7. 移植性・保守性

全ての構成を Terraform / Ansible のコードとして管理し、環境の再構築を容易にする。

## 7. 制約・前提条件

### 7.1. 採用が決定済みの技術

| 分類 | 技術 |
| ---- | ---- |
| プラットフォーム | OCI (Oracle Cloud Infrastructure) |
| インフラ構成管理 | Terraform（バックエンドは Terraform Cloud） |
| サーバ構成管理 | Ansible |
| OS | Ubuntu 24.04 LTS (ARM64) |
| コンテナオーケストレーション | Kubernetes |
| Web サーバ / リバースプロキシ | Kubernetes Ingress (`ingress-nginx`) |
| データベース | MySQL（ホスト OS 直接インストール） |
| ソース管理 | GitHub |

### 7.2. その他の前提

- OCI Always Free 枠の制限事項（コンピュートリソース、ブロックボリューム容量など）に依存する
- 作業端末には SSH クライアント、`terraform`、`ansible-playbook`、`jq` がインストールされていること
