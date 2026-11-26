# 09 構築手順書 - Renovate セットアップ

## 目次

- [1. 概要](#1-概要)
- [2. 前提条件](#2-前提条件)
- [3. 手順](#3-手順)
  - [3.1. Renovate GitHub App のインストール](#31-renovate-github-app-のインストール)
  - [3.2. 動作確認](#32-動作確認)

## 1. 概要

Issue #176 に対応する。アドオンのパッチバージョンを Renovate が自動で更新する仕組みを有効化する。
方針は [12章 12.7節](../02.design/12.lifecycle/12章_基本設計書_ライフサイクル管理方式.md#127-アドオンのパッチ自動更新) に従う。
設定は、リポジトリ直下の `renovate.json` と、`ansible/group_vars/all.yml` の `# renovate:` コメントで管理する。

## 2. 前提条件

- 本リポジトリの管理者権限を持つ GitHub アカウントでログインしていること

## 3. 手順

### 3.1. Renovate GitHub App のインストール

1. [Renovate の GitHub App](https://github.com/apps/renovate) を開き、「Configure」を選ぶ
2. インストール先に自分のアカウントを選び、「Only select repositories」で `infra-oci` のみを選択する
3. 「Save」でインストールを確定する

### 3.2. 動作確認

1. `renovate.json` を含む PR が `main` へマージされると、Renovate が「Configure Renovate」の PR を作らずに
   設定を読み込む。`infra-oci` の Issue 一覧に「Dependency Dashboard」が作成されることを確認する
2. ダッシュボードに、`ansible/group_vars/all.yml` の 6 件（Flannel・local-path-provisioner・metrics-server・
   cert-manager・OCI CLI・External Secrets Operator）が検出されていることを確認する
3. 更新がある場合は、パッチバージョンの PR が作成され、Ansible CI/CD のドライラン成功後に自動でマージされることを確認する
