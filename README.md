# Herdr Agile Team Skill

Herdr の現在の Tab に、Codex エージェントによる4役の Agile チームを2×2の Pane 構成で初期化する Skill です。Tab ごとに独立したチームを作れるよう、Herdr の agent 名には workspace ID と tab ID から生成した一意キーを付け、Pane の表示名には役割名を使います。

チームの役割と連携ルールを各エージェントの初期コンテキストへ渡します。初期化時は全員が読み取り専用で待機し、案件の分解・実装・レビューは明示的な作業指示を受けてから開始します。

## チーム構成

| Pane 表示名 | Herdr agent 名 | 役割 | モデル / reasoning | 主な責務 |
| --- | --- | --- | --- | --- |
| `POA` | 起動元の Codex セッション | Orchestrator | 起動元の既存設定 | 要件、全体設計、実装計画、タスク割当、進捗、最終判断 |
| `tech-lead` | `tech-lead-<team-key>` | Technical Lead | `gpt-6-sol` / `medium` | 高度な設計・実装・レビューへの助言。ソースは変更しない |
| `dev-implement` | `dev-implement-<team-key>` | Development / Implementation | `gpt-6-luna` / `max` | POAから割り当てられた実装、検証、Draft PR、レビュー対応 |
| `dev-review` | `dev-review-<team-key>` | Development / Review | `gpt-6-luna` / `max` | POAから割り当てられたPRの独立レビューと個別コメント |

`team-key` は現在 Pane の `workspace_id` と `tab_id` を連結し、英数字以外をハイフンに正規化して作ります。たとえば workspace `w7`、tab `t4` なら `tech-lead-w7-t4` のようになります。Pane 表示名はタブ内で役割名のままです。

POAだけが実装・レビュー・修正の作業を割り当てます。`dev-implement`と`dev-review`は互いを直接呼び出さず、Pull Requestを証跡としてPOAへ結果を返します。各役割は技術的な助言が必要なときに`tech-lead`へ相談できます。

## GitHubコメントの言語

GitHub上のPR会話コメント、返信、インラインレビューコメント、レビュー要約は日本語で記載します。`blocker`、`major`、`minor`などのseverity、`Approve` / `Request changes`の判定ラベル、コード識別子は原表記を保ち、指摘の説明、根拠、対応依頼、判断理由を日本語で書きます。

## 前提条件

- Herdr がインストールされていること
- Codex CLI が利用できること
- Skillを起動するCodexがHerdr管理下のPaneにあり、`HERDR_ENV=1`であること
- `gpt-6-sol`と`gpt-6-luna`を利用できること

Skillはインストール済みの`herdr` CLIを構文の正とし、現在の作業ディレクトリを物理絶対パスへ解決して全Paneで共有します。

## インストール

`npx skills`を利用する場合:

```bash
npx skills add h-yoshinori-tamagami/herdr-agile-team-skill --skill herdr-agile-team -g
```

手動でCodexのユーザーSkillとして配置する場合:

```bash
git clone https://github.com/h-yoshinori-tamagami/herdr-agile-team-skill.git
cd herdr-agile-team-skill
mkdir -p ~/.codex/skills
cp -R herdr-agile-team ~/.codex/skills/
```

## 使い方

対象プロジェクトのディレクトリからHerdrを起動し、POAとして使用するCodexセッションでSkillを呼び出します。

```text
$herdr-agile-team を使って、現在のHerdr TabにAgileチームを作成してください。
案件依頼: <依頼内容>
```

案件依頼を省略した場合は`案件依頼未指定`としてチームだけを初期化します。要件を推測して作業を開始することはありません。

## Pane配置

```text
┌─────────────────┬─────────────────┐
│ POA             │ tech-lead       │
├─────────────────┼─────────────────┤
│ dev-implement   │ dev-review      │
└─────────────────┴─────────────────┘
```

現在のPaneを`POA`として維持し、同じTabと作業ディレクトリに3つのSibling Paneを作成します。新しいWorkspace、Tab、Worktree、リモートマシンは作成しません。

サイドバーでは4つのPaneすべてに表示専用 metadata `display-agent=codex` を設定します。Tab 固有の Herdr agent 名は制御用として維持し、見える agent 名は Codex に揃えます。

## 初期化時の安全境界

- プロジェクトコマンドを実行しない
- ファイルを変更しない
- commit、push、Pull Request作成を行わない
- 外部システムを変更しない
- 既存Paneを閉じたり移動したりしない
- Agentが承認・質問画面で停止した場合は、代わりに回答せずユーザーへ報告する

PaneやAgentの一部だけが作成された場合も、破壊的な自動クリーンアップは行わず、成功した範囲と失敗状態を報告します。

## リポジトリ構成

```text
.
├── README.md
└── herdr-agile-team/
    ├── SKILL.md
    └── agents/
        └── openai.yaml
```

`SKILL.md`がAgent向けの実行ルール、`agents/openai.yaml`が表示名や既定プロンプトなどのCodex向けUIメタデータです。

## 関連資料

- [OpenAI Developers: Build skills](https://developers.openai.com/plugins/build/skills)
- [Herdr: Agent skill file](https://herdr.dev/docs/agent-skill/)
