# WordPress マルチテナント環境構築ブログシリーズ

GCP上でWordPress マルチテナント環境（10サイト）を構築する過程で得た知見を、失敗談を含めて包み隠さず共有する技術ブログシリーズです。

## 📚 記事一覧

### Phase 1: 失敗から学ぶシリーズ（最優先）

これらの記事は、実際に遭遇した問題と判断ミスを詳細に分析し、同じ過ちを繰り返さないための教訓をまとめています。

#### [記事4: 【失敗から学ぶ】Cloud SQL SSL設定で2時間ハマった話](04_cloud_sql_ssl_failure_analysis.md)
**想定読了時間**: 50分

**内容**:
- なぜカスタムdb.phpという間違ったアプローチを取ったのか
- 判断ミスの根本原因分析（4つの原因を特定）
- 同様の事象が起きた時のチェックリスト
- 時系列でみる判断の分岐点（145分の無駄を検証）

**キーポイント**:
- 「とりあえず動けばいい」は技術的負債の始まり
- IaC原則を守ることが結果的に時間短縮
- エラーメッセージの真意を読み取る重要性

---

#### [記事5: WordPress環境構築で遭遇した5つのハマりポイントと解決策](05_wordpress_troubleshooting_guide.md)
**想定読了時間**: 60分

**内容**:
1. Ansibleのメタデータ取得で404エラー（HTMLが変数に埋め込まれる）
2. Terraform applyでインスタンス再作成（Instance Template変更の影響）
3. データベースパスワード不一致（Secret Managerとの同期）
4. WP-CLIの権限エラー（rootユーザー実行の問題）
5. カスタムdb.phpの残骸（NFSマウントされたファイルの罠）

**キーポイント**:
- HTTPステータスコードの確認は必須
- パスワード同期スクリプトの必要性
- WordPress Drop-in Fileの危険性

---

### Phase 2: 技術深掘りシリーズ

#### [記事3: Cloud SQL接続の落とし穴 - プライベートIP、SSL設定、パスワード管理の完全ガイド](03_cloud_sql_connection_deep_dive.md)
**想定読了時間**: 45分

**内容**:
- プライベートIP vs パブリックIP接続の選択基準
- SSL/TLS設定の理解と選択（require_ssl設定）
- Secret Managerを使ったパスワード管理のベストプラクティス
- 接続エラーのデバッグ手法（ネットワーク→認証→SSL→アプリケーション）
- Terraformでの適切な設定方法

**キーポイント**:
- プライベートIP接続ならSSL不要
- Secret Managerが単一真実の情報源(SSOT)
- 段階的なデバッグフロー

---

#### [記事2: Terraform + Ansibleで実現する完全IaC運用](02_terraform_ansible_iac_best_practices.md)
**想定読了時間**: 50分

**内容**:
- TerraformとAnsibleの責任分離（何をどちらで管理するか）
- モジュール設計とディレクトリ構造
- 変数管理とシークレット管理
- 冪等性の担保と検証
- 運用フェーズでの変更管理

**キーポイント**:
- Terraformはインフラリソース、Ansibleは構成管理
- 明確な責任分離が保守性を高める
- 冪等性テストの重要性

---

#### [記事1: GCP上でWordPress マルチテナント環境を構築 - アーキテクチャ設計編](01_wordpress_multitenancy_architecture.md)
**想定読了時間**: 40分

**内容**:
- 要件定義と技術要件
- 3つのアーキテクチャパターンの比較検討
- コンポーネント選定理由（なぜCompute Engine、Cloud SQL、Cloud Filestoreか）
- コスト試算と最適化（月額$120で10サイト運用）
- セキュリティ設計（多層防御）
- スケーラビリティと可用性

**キーポイント**:
- マルチテナント + オートスケーリング構成の選択
- マネージドサービスと自前VMのバランス
- コスト効率重視の設計

---

## 📖 推奨読書順序

### パターンA: 失敗から学びたい方
1. [記事4: Cloud SQL SSL設定の失敗分析](04_cloud_sql_ssl_failure_analysis.md) ← **最重要**
2. [記事5: WordPress構築のハマりポイント](05_wordpress_troubleshooting_guide.md)
3. [記事3: Cloud SQL接続のトラブルシューティング](03_cloud_sql_connection_deep_dive.md)

### パターンB: 体系的に理解したい方
1. [記事1: アーキテクチャ設計編](01_wordpress_multitenancy_architecture.md)
2. [記事2: Terraform + Ansible IaC運用編](02_terraform_ansible_iac_best_practices.md)
3. [記事3: Cloud SQL接続のトラブルシューティング](03_cloud_sql_connection_deep_dive.md)
4. [記事4: Cloud SQL SSL設定の失敗分析](04_cloud_sql_ssl_failure_analysis.md)
5. [記事5: WordPress構築のハマりポイント](05_wordpress_troubleshooting_guide.md)

### パターンC: トラブルシューティング目的
1. [記事5: WordPress構築のハマりポイント](05_wordpress_troubleshooting_guide.md) ← 即効性重視
2. [記事3: Cloud SQL接続のトラブルシューティング](03_cloud_sql_connection_deep_dive.md)
3. [記事4: Cloud SQL SSL設定の失敗分析](04_cloud_sql_ssl_failure_analysis.md)

---

## 🎯 各記事の対象読者

| 記事 | 初心者 | 中級者 | 上級者 | 用途 |
|-----|-------|-------|-------|------|
| 記事1 | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | 設計思想理解 |
| 記事2 | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | IaC実践 |
| 記事3 | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | 技術深掘り |
| 記事4 | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | 失敗分析 |
| 記事5 | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | トラブル対応 |

---

## 🔗 関連リソース

### GitHubリポジトリ
- [infra-ai-agent](https://github.com/0xchoux1/infra-ai-agent)

### 実装コード
- [Terraformモジュール](https://github.com/0xchoux1/infra-ai-agent/tree/main/terraform/modules)
- [Ansible Playbook](https://github.com/0xchoux1/infra-ai-agent/tree/main/ansible)

### 設計ドキュメント
- [全体構成案](00_series_outline.md)
- [要件定義](../design/requirements.md)

---

## 📊 シリーズの特徴

### なぜこのシリーズが役立つか

1. **失敗を包み隠さず公開**
   - 「うまくいった」話だけでなく、「なぜ失敗したか」を詳細に分析
   - 同じミスを防ぐためのチェックリスト

2. **判断の背景を説明**
   - 「なぜその技術を選んだか」
   - 「他の選択肢とどう比較したか」

3. **再現可能な実装例**
   - すべてのコードをGitHubで公開
   - Terraform + Ansibleで完全にIaC化

4. **コスト意識**
   - 月額$120で10サイト運用
   - コスト最適化のポイントを明示

5. **実践的なトラブルシューティング**
   - 実際に遭遇したエラーと解決策
   - デバッグ手法のフロー化

---

## 💡 このシリーズから得られること

### 技術スキル
- GCPサービスの実践的な使い方
- Terraform + AnsibleによるIaC運用
- WordPressのマルチサイト運用ノウハウ

### 問題解決力
- エラーの根本原因分析
- 判断ミスの振り返り方
- トラブルシューティングのフレームワーク

### アーキテクチャ設計力
- 要件に応じた技術選定
- コストとパフォーマンスのバランス
- セキュリティとスケーラビリティの両立

---

## 📝 フィードバック

このシリーズについてのフィードバックは、以下の方法で受け付けています：

- GitHub Issues: [infra-ai-agent/issues](https://github.com/0xchoux1/infra-ai-agent/issues)
- Twitter: [@0xchoux1](https://twitter.com/0xchoux1)

---

## 📄 ライセンス

このドキュメントシリーズはMITライセンスの下で公開されています。

---

**役に立ったら**: GitHub Starをいただけると嬉しいです！ [infra-ai-agent](https://github.com/0xchoux1/infra-ai-agent)
