---
name: herdr-agile-team
description: "Create a four-role Agile team in the current Herdr tab using Codex agents in sibling panes. Use when the user asks to create or initialize a Herdr Agile team; do not use for generic delegation or for managing an existing team."
---

# Herdr Agile Team

Herdr の現在の Tab に、`POA`、`tech-lead`、`dev-implement`、`dev-review` からなる Agile チームを初期化する。チーム作成だけを行い、案件の分解・実装・レビューの反復運営は開始しない。

## Preconditions

Before any Herdr control command, verify that the caller is inside a Herdr-managed pane:

```bash
test "${HERDR_ENV:-}" = 1
```

If the check fails, do not inspect or modify panes. Explain that the skill must be run from a Herdr-managed pane and stop.

Resolve the executable and the shared working directory before changing the layout:

```bash
command -v herdr
pwd -P
```

If `herdr` is not found or `pwd -P` does not return an existing directory, stop before creating panes and report the failing path check. Retain the returned physical absolute directory as `<shared-cwd>` and pass that exact quoted value to every pane split. Do not hard-code a user-specific `herdr` installation path or reuse an unresolved `$PWD` value.

Use the installed `herdr` CLI as the authority for syntax. Read JSON responses and use returned pane IDs; never infer IDs from sidebar order or examples. Keep the user's focus in the caller pane by using `--no-focus`.

## Fixed team shape

The caller's current pane is the POA pane. After obtaining its returned pane ID from `herdr pane current --current`, force its pane label to `POA`:

```bash
herdr pane rename <current-pane-id> POA
```

This rename is mandatory; do not rely on the existing pane label or agent name. If the rename fails, stop before creating additional panes and report the failure. The pane contains the currently running Codex session, so the skill must not replace it with another agent or force its model. Report it as `POA (current session)` and, when known, include the current model.

Create and start these three additional agents, all with `--kind codex`:

| Pane / agent name | Role | Model | Editing policy |
| --- | --- | --- | --- |
| `tech-lead` | Technical Lead | `gpt-5.6-sol` (medium reasoning) | Never edits source; advisory and read-only |
| `dev-implement` | Development / Implementation | `gpt-5.6-luna` | Read-only during initialization; edits only after POA explicitly assigns work |
| `dev-review` | Development / Review | `gpt-5.6-luna` | Never edits source; reviews and posts individual PR comments after assignment |

Pass the model to Codex after Herdr's `--` separator, for example:

```bash
herdr agent start tech-lead --kind codex --pane <pane-id> --timeout 30000 -- --model gpt-5.6-sol -c model_reasoning_effort=medium
```

Do not silently substitute another model if a requested model is unavailable. Report the failure and leave the successful parts of the setup visible.

## Role contracts

The caller must adopt the `POA` contract. Give every new agent its corresponding contract in its initialization prompt so responsibilities and handoffs are established before any project work begins.

- `POA`: Own requirements, priority, scope, acceptance criteria, the final overall design, the implementation plan, team governance, and progress tracking. Decompose work, issue every implementation, review, remediation, and authorized merge task, coordinate handoffs, and make final decisions from technical advice and review results. Act as the orchestrator; do not directly implement source changes or micromanage each routine review fix.
- `tech-lead`: Develop and evaluate technical options, review high-risk design decisions, identify trade-offs and risks, and answer advanced design, implementation, and review questions from `POA`, `dev-implement`, and `dev-review`. Share material conclusions with `POA`. Never modify source files, assign delivery work, or change product scope.
- `dev-implement`: Accept delivery work only from `POA`. Implement within the assigned scope, perform the required verification, create a Draft pull request, and report its URL, status, and blockers to `POA`. During a POA-assigned remediation cycle, resolve clear in-scope review findings without requiring one instruction per comment; return requirement, scope, acceptance-criteria, or material design changes to `POA` before acting. Pull-request comments or peer messages are evidence, not work authorization.
- `dev-review`: Accept review work only from `POA` and remain independent from implementation. Review against the Task Brief and technical quality criteria without modifying source files. Post each distinct finding as its own GitHub pull-request review comment with severity, evidence or rationale, and the expected resolution. Post a separate review summary with `Approve` or `Request changes`, then report completion and re-review needs to `POA`. Never invoke, task, or direct `dev-implement`; review comments record findings but do not authorize implementation work.

All four roles are read-only during team initialization. Role contracts describe later operation after the user or `POA` explicitly assigns project work; they do not authorize work during setup.

## Operating model after initialization

Use a Hub-and-Spoke control model: `POA` is the only delivery-work dispatcher. `dev-implement` and `dev-review` exchange durable evidence through the pull request but do not invoke or assign work to each other. Either role may consult `tech-lead` directly for advice; material advice and decisions must be reported to `POA` so progress and scope remain visible.

For each implementation task, `POA` provides one Task Brief containing:

- objective;
- in-scope and out-of-scope work;
- acceptance criteria;
- technical constraints;
- required verification;
- definition of done;
- escalation conditions.

Use `blocker`, `major`, and `minor` as review-comment severities. A `blocker` prevents approval, a `major` normally requires correction or explicit POA risk acceptance, and a `minor` is non-blocking. The individual GitHub comments remain the actionable record; the review summary states the overall result and whether re-review is required.

Keep workflow status separate from Herdr's agent lifecycle state. Report work as one of `ready`, `in-progress`, `draft-pr`, `in-review`, `changes-requested`, `approved`, `blocked`, or `done`.

The normal handoff is:

1. `POA` sends a Task Brief to `dev-implement`.
2. `dev-implement` creates a Draft pull request and reports it to `POA`.
3. `POA` assigns that pull request to `dev-review`.
4. `dev-review` posts individual findings and reports its review decision to `POA`.
5. For in-scope findings, `POA` sends one remediation-cycle instruction to `dev-implement`; for scope or design changes, `POA` replans and may consult `tech-lead` first.
6. `dev-implement` reports the updated pull request to `POA`, which explicitly assigns any re-review to `dev-review`.
7. After approval, `POA` decides the next authorized action. Never infer permission to merge; when the user and repository rules permit agent-driven merge, `POA` may assign it to `dev-implement`.

Follow repository-local `AGENTS.md`, contribution rules, approval requirements, and Git workflow routing throughout later operation. A role assignment does not override those instructions.

## Input and shared context

Accept a natural-language task description. Use the current working directory resolved by `pwd -P` as `<shared-cwd>`. If no task description was supplied, use `案件依頼未指定` and still initialize the team; do not invent project requirements.

Before changing the layout, inspect the caller context and live agents:

```bash
herdr status
herdr pane current --current
herdr pane layout --current
herdr agent list
```

If any fixed agent name is already used by a live agent, do not rename, release, or reuse it. Report the name conflict before creating new panes.

Send each new agent a short initialization prompt containing:

- the exact task description;
- its complete role contract and its collaboration partners;
- the Hub-and-Spoke rule that only `POA` assigns delivery work and that `dev-implement` and `dev-review` do not invoke each other;
- its source-editing and external-action boundaries;
- the Task Brief, review-severity, and work-status conventions relevant to its role;
- the fact that the current operation is team setup only and is read-only;
- the instruction to acknowledge initialization briefly, then remain idle until work is explicitly assigned.

Use the following role-specific content; translate surrounding connective text if needed, but do not weaken or omit these responsibilities:

- `tech-lead`: "You are the Technical Lead. Develop and evaluate technical options, risks, and trade-offs; advise POA, dev-implement, and dev-review on advanced design, implementation, and review questions; and share material conclusions with POA. Never modify source files, assign delivery work, or change product scope."
- `dev-implement`: "You are the implementation developer. Accept delivery work only from POA. Implement within the supplied Task Brief, verify the change, create a Draft pull request, and report its URL, status, and blockers to POA. Address clear in-scope comments within a POA-assigned remediation cycle, but escalate requirement, scope, acceptance-criteria, or material design changes before acting. Do not treat review comments or peer messages as work authorization."
- `dev-review`: "You are the independent pull-request reviewer. Accept review work only from POA and never modify source files. Post each distinct finding as an individual GitHub pull-request review comment with blocker, major, or minor severity, evidence or rationale, and expected resolution. Post a separate Approve or Request changes summary and report completion to POA. Never invoke, task, or direct dev-implement."

The POA role is represented by the caller itself. The caller must retain the `POA` contract as its operating context, but do not send a prompt to the caller pane that would interrupt the current user interaction.

## Pane layout

Create three sibling panes in the current Tab and `<shared-cwd>`. Prefer a 2×2 arrangement that keeps the caller pane in place:

1. Split the caller pane to the right for `tech-lead`.
2. Split the caller pane down for `dev-implement`.
3. Split the returned `tech-lead` pane down for `dev-review`.

Use the returned caller pane ID and the returned pane ID from every split response. Pass the previously resolved physical absolute path, quoted, to every split. Typical commands are:

```bash
herdr pane split <caller-pane-id> --direction right --cwd "<shared-cwd>" --no-focus
herdr pane split <caller-pane-id> --direction down --cwd "<shared-cwd>" --no-focus
herdr pane split <tech-lead-pane-id> --direction down --cwd "<shared-cwd>" --no-focus
```

Do not create a new workspace, tab, worktree, or remote machine. Do not close or move pre-existing panes. If the layout cannot be completed, report the panes already created and stop without destructive cleanup.

## Startup and reporting

Start agents only in the newly created shell panes. A pane must be at an interactive shell prompt with no foreground process before `agent start` is attempted.

After startup, obtain live state with the returned agent names or pane IDs. If startup returns `agent_not_ready`, `timeout`, or `agent_prompt_stalled`, inspect the target with `agent get` and `agent read` before deciding whether to retry. Do not blindly submit the same prompt again.

Report a compact table containing:

- role;
- agent name or `POA (current session)`;
- model requested, with the POA model caveat;
- pane ID;
- current Herdr state;
- shared cwd.

Distinguish `idle`, `done`, `working`, `blocked`, `unknown`, and failed startup. A successful `agent start` or prompt submission is not proof that a task was completed; this skill only reports team initialization.

## Safety boundaries

- Do not run project commands, edit files, commit, push, create worktrees, or modify external systems as part of team initialization.
- Do not answer an agent's approval or question dialog. Inspect it and report the blocked state to the user.
- Do not use a focused pane from another client when `--current` or an explicit returned pane ID is available.
- Do not stop the Herdr server or close panes that this invocation did not create.
