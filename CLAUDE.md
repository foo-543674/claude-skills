# claude-skills Repository

Repository for defining and managing foo-543674's design philosophy, code review perspectives, and implementation policies as Claude Skills.

## Core Philosophy

**Development is creative work.**

The skills defined in this repository support foo-543674's creative activities. When creating skills, you must not simply implement surface-level instructions, but deeply understand:

- **Creative Intent**: Why adopt that policy (Why)
- **Decision Process**: How to judge and choose (How)
- **Exceptions and Context**: In what situations judgments change (Context)
- **Implicit Criteria**: Judgment axes and values not verbalized

Skills are not mere "procedure manuals" but **systematizations of the creator's thought processes and judgment criteria**.

## Repository Structure

```
claude-skills/
├── .claude-plugin/
│   └── plugin.json # プラグインマニフェスト
├── README.md       # For humans (setup procedures, etc.)
├── CLAUDE.md       # This file
└── skills/         # Skill implementations
    └── <skill-name>/
        ├── SKILL.md        # Entry point (YAML frontmatter + instructions)
        └── resources/      # Detailed references, checklists, etc.
# claude-skills プラグイン

ソフトウェア開発の各フェーズ（要件定義・設計・実装・レビュー・環境構築）を支援するスキルとエージェント。

## 開発ライフサイクルとの対応

```
要件定義 ─→ 設計 ─→ 実装 ─→ レビュー
                              ↓
requirements-*   design-*   implement-*   code-reviewer (agent)
                                           ↑
環境構築（実装より先に整備する）           commit-message
setup-*                                    development-report
```

### スキル一覧

### SKILL.md Format

```yaml
---
name: skill-name
description: What this skill does and when to use it
---

# Skill Name

Write instructions here.
```

- `name`: Skill name
- `description`: Explanation used by Claude to automatically determine relevance

### Rules to Follow

- Keep SKILL.md within 500 lines. Separate details into `resources/`
- 1 skill per folder. Create separate skills for different purposes
- Update the skill list in README.md when adding or changing skills

## Feedback Reflection

When receiving feedback or corrections about skill writing or content from foo-543674, always do the following to prevent the same issues from recurring:

1. **Fix the target skill**: Reflect the feedback in the skill
2. **Update CLAUDE.md**: If the feedback is a general rule applicable to other skills, add it as a rule to the "Rules to Follow" or relevant section of this file
3. **Horizontal deployment to existing skills**: If existing skills violate the added rule, fix them as well

## Tacit Knowledge Elicitation Protocol for Skill Creation

When receiving a skill creation request, do not simply implement surface-level instructions. Follow this protocol to systematically elicit the user's tacit knowledge.

### Basic Principles

**❌ Prohibited Actions:**
- Implementing instructions as-is
- Asking abstract or vague questions ("What criteria?", etc.)
- Filling gaps with general best practices
- Guessing decision processes

**✅ Required Actions:**
- Elicit tacit knowledge through a 7-stage structured process and optimize for AI
- Prioritize deep-diving into Why (purpose/reason)
- Verbalize decision processes
- Identify decision branch points through comparison and examples
- Convert to AI-executable form and optimize

### 7-Stage Skill Creation Process

```
【Overall Process】
Phase 1-5: Elicit tacit knowledge from user
  Phase 1: Organize surface requirements
  Phase 2: Deep-dive into Why (purpose/reason)
  Phase 3: Verbalize decision processes
  Phase 4: Identify decision branch points through comparison
  Phase 5: Discover edge cases and exceptions through examples

Phase 6: Convert to AI-optimal form (AI optimization analysis)
  6.1: Structure decision flows
  6.2: Supplement and clarify conditional branches
  6.3: Optimize implementation means
  6.4: Propose skill splitting
  6.5: Optimize pattern recognition
  6.6: Cross-cutting quality aspects

Phase 7: Present final design and obtain user confirmation
```

#### Phase 1: Organize Surface Requirements
```
【Content】
1. Receive user instructions
2. Structure surface-level elements of instructions
   - What to create (What)
   - What functionality (Function)
   - What constraints (Constraint)

【Output Example】
"I received a request to create a skill with the following content:
- Target: commit-message skill
- Functionality: Add prefix, separate granularity
- Constraints: (Not specified)

I will confirm step-by-step to elicit tacit knowledge."
```

#### Phase 2: Deep-Dive into Why (Purpose/Reason) [Top Priority]
```
【Question Design】
Identify why that policy is adopted and the deepest purpose.
Dig deeper with Why-Because chains, not just surface reasons.

【Question Examples】
❌ Bad question: "Why add prefixes?"
   → Only gets surface answers

✅ Good question:
"What is the purpose of adding prefixes?
- Improve commit history searchability?
- Visualize change impact?
- Automatic determination in CI/CD?
- Team communication?

Why is that important? (dig deeper)"

【Important】
Understanding Why naturally derives judgment criteria.
Do not implement without clear purpose.
```

#### Phase 3: Verbalize Decision Processes [Second Priority]
```
【Question Design】
Verbalize the decision flow in the user's mind.
Follow specific steps, not abstract questions.

【Question Examples】
❌ Bad question: "What criteria do you use to choose prefixes?"
   → Too vague to answer

✅ Good question:
"When you see a commit with new files added,
what do you check first to decide the prefix?

→ User answer: "I look at the file's role"

How do you determine the file's role?
What specific information do you look at?

→ User answer: "I look at the path, if it's CI/CD related..."

What do you check next?"

【Goal】
Completely verbalize decision flow:
1. Check file path
2. Determine if CI/CD-related directory
3. Yes → chore, No → next step
4. ...
```

#### Phase 4: Identify Decision Branch Points through Comparison [Second Priority]
```
【Question Design】
Compare similar cases to identify decision branch points.

【Question Examples】
❌ Bad question: "Are there exception cases?"
   → User may not think of them

✅ Good question:
"For these two cases, is the prefix determination the same?
If different, what's the deciding factor?

Case A: `src/features/login.ts` added
Case B: `.github/workflows/ci.yml` added

→ User answer clarifies branch points

How about these cases?
Case C: `tests/login.test.ts` added
Case D: `docs/README.md` updated"

【Goal】
Identify judgment axes:
- File role (feature vs infrastructure vs test vs documentation)
- Change type (add vs update vs delete)
- Impact scope (user-facing vs developer-facing)
```

#### Phase 5: Discover Edge Cases and Exceptions through Examples
```
【Question Design】
Explore cases that don't fit general rules,
identifying exception rules and conditional branches.

【Question Examples】
✅ Effective question:
"Are there cases that don't fit the "file addition = feat" rule?
What characteristics do they have?

How would you judge these cases?
- Configuration file addition (`.env.example`)
- Build configuration addition (`tsconfig.json`)
- Dependency addition (`package.json` update)
- Git-related files (`.gitignore` update)"

【Goal】
Comprehensively identify exception rules:
- CI/CD related → chore
- Configuration files → chore
- Documentation → docs
- Tests → test
- etc.
```

#### Phase 6: AI Optimization Analysis [Required]

```
【Purpose】
Convert tacit knowledge elicited in Phase 1-5 to "AI-optimal form".
Optimize user judgment criteria into structures AI can execute accurately.

【Important】
This phase must not be skipped.
Rather than implementing user thought processes as-is,
converting to AI-optimized form significantly improves accuracy.
```

##### 6.1 Structure Decision Flows [First Priority]

```
【Analysis Perspective】
Convert decision processes verbalized in Phase 3 to structures optimal for AI execution.

【Checklist】
✓ Complete ambiguity elimination
  - No expressions like "appropriately", "as needed"
  - All judgment criteria concretely defined

✓ Clarify priorities
  - Specify priorities when multiple conditions conflict
  - Distinguish "hard constraints" (mandatory) from "soft constraints" (recommended)

✓ Structure as decision tree
  - Express decision flow as clear decision tree
  - Specify "what to check and how to branch" at each node
  - Define handling of dead ends (undecidable cases)

【Proposal Template】
"For the decision process verbalized in Phase 3,
I propose the following structuring for AI execution:

■ Decision Tree Flow
```
1. Check [Condition A]
   └─ Yes → [Action X]
   └─ No → go to 2
2. Check [Condition B]
   └─ Yes → [Action Y]
   └─ No → go to 3
3. Check [Condition C]
   └─ Yes → [Action Z]
   └─ No → User confirmation
```

■ Priority Rules
Priority when conflicts occur:
1. [Hard Constraint 1] (mandatory)
2. [Hard Constraint 2] (mandatory)
3. [Soft Constraint 1] (recommended)

■ Ambiguity Resolution
I propose changing current expression "[ambiguous expression]"
to concrete criteria "[clear criteria]".

Does this structuring work for you?"
```

##### 6.2 Supplement and Clarify Conditional Branches [Second Priority]

```
【Analysis Perspective】
Propose conditional branches the user didn't make explicit but AI needs.

【Checklist】
✓ Exception cases user didn't notice
  - Exceptions predictable from domain knowledge
  - Exceptions common in similar systems

✓ Boundary case judgment criteria
  - Clarify difficult-to-judge cases
  - Handle "could go either way" cases

✓ Default behavior definition
  - Behavior when no conditions match
  - Safe fallback on error

【Proposal Template】
"I propose adding the following conditional branches to current judgment criteria:

■ Unconsidered Exception Cases
[Case]: [Proposed judgment]
Reason: [Why this case could occur]

■ Boundary Case Handling
[Boundary Case]: [Proposed judgment criteria]
Example: [Concrete example]

■ Default Behavior
When no conditions match: [Proposed behavior]

Are these additions necessary?
Or do these cases not actually occur?"
```

##### 6.3 Optimize Implementation Means [Third Priority]

```
【Analysis Perspective】
Propose optimal means to implement elicited tacit knowledge.

【Options】
A. Skills (claude-skills/skills/)
B. Hooks (auto-start via config file)
C. CLAUDE.md (project-wide rules)
D. Memory (auto memory)

【Decision Criteria】
Choose Skills when:
✓ Complex decision processes exist
✓ Step-by-step questions/confirmations needed
✓ Long explanations/references needed
✓ Explicitly invoked by specific trigger

Choose Hooks when:
✓ Auto-execute on specific events (pre-commit, PR creation, etc.)
✓ Simple decision process
✓ Completes without user intervention

Choose CLAUDE.md when:
✓ Rules applied across entire project
✓ Principles to follow horizontally across all skills
✓ Project design philosophy/values

Choose Memory when:
✓ Temporary project-specific information
✓ Patterns to share between sessions
✓ Experimental rules not yet established

【Proposal Template】
"Based on analyzing this skill's characteristics,
I propose the following implementation means:

■ Recommended Implementation Means: [Skills/Hooks/CLAUDE.md/Memory]

Reasons:
- [Reason 1 based on decision criteria]
- [Reason 2 based on decision criteria]

Alternative:
If [condition], we could also consider [alternative means].

Does this implementation means work?"
```

##### 6.4 Propose Skill Splitting [Fourth Priority]

```
【Analysis Perspective】
Propose whether to implement as one skill or split into multiple.

【Signals to Split】
✓ Has multiple different responsibilities
✓ Clearly different trigger conditions
✓ Has reusable parts
✓ Has independently testable parts

【Signals to Consolidate】
✓ Always used together
✓ Meaningless alone
✓ Difficult to understand when split
✓ High splitting overhead

【Proposal Template】
"For this skill, I propose splitting:

■ Proposed Split
[Skill Name 1]: [Responsibility Scope 1]
[Skill Name 2]: [Responsibility Scope 2]

■ Reasons for Splitting
- [Single Responsibility Principle perspective]
- [Reusability perspective]
- [Trigger Condition perspective]

■ Coordination After Split
How [Skill 1] and [Skill 2] coordinate: [Explanation]

Does this split proposal work?
Or should it remain as one skill?"
```

##### 6.5 Optimize Pattern Recognition [Fifth Priority]

```
【Analysis Perspective】
Optimize "trigger conditions" for AI to auto-invoke skills.

【Checklist】
✓ Description clarity
  - Is when to use clearly described?
  - Are keywords appropriately included?

✓ Few-shot example enrichment
  - Include 3-5 representative use cases
  - Include 1-2 edge case examples

✓ Explicit trigger keywords
  - What words/phrases should trigger the skill?
  - Exclusion keywords to prevent false triggers

【Proposal Template】
"To help AI appropriately invoke this skill,
I propose the following optimization:

■ Description Draft
```yaml
description: |
  Use when [when to use].
  Keywords: [keyword1], [keyword2], [keyword3]
  Example: [concrete invocation example 1]
```

■ Few-shot Examples (include in SKILL.md)
Representative Cases:
1. [Case 1 description and judgment result]
2. [Case 2 description and judgment result]

Edge Cases:
1. [Edge case 1 description and judgment result]

Do these examples work?"
```

##### 6.6 Cross-cutting Quality Aspects

```
【Testability Design】
✓ Test case definition
  - Input: [Concrete input example]
  - Expected decision process: [Steps]
  - Expected output: [Concrete output]

✓ Verification method
  - How to confirm skill works correctly
  - Malfunction patterns and detection methods

【Context Management Strategy】
✓ Clarify required information
  - What information does this skill need?
  - When to acquire information?

✓ Information priority
  - Essential information: [List]
  - Recommended information: [List]
  - Optional information: [List]

【Feedback Loop Design】
✓ Information collection for improvement
  - Record user correction patterns
  - Accumulate common misjudgment patterns

✓ Continuous improvement mechanism
  - What to record in Memory
  - Periodic review timing

【Strict Role and Output Format Definition】
✓ Persona setting
  - AI's role in this skill: [Specific role]
  - Expertise level: [For beginners/experts, etc.]

✓ Explicit output format
  - Use of structured tags: [XML/Markdown, etc.]
  - Template definition: [Specific format]
```

#### Phase 7: Present Final Design and Confirm
```
【Content】
Integrate information elicited and optimized in Phase 1-6,
presenting final skill design proposal.

【Presentation Format】
"After analysis through Phase 1-6, I will create a skill with the following structure:

■ Purpose (Why)
[Purpose elicited in Phase 2]

■ Implementation Means
[Implementation means decided in Phase 6.3 and reasons]

■ Decision Process (How)
[Decision tree flow structured in Phase 6.1]
```
1. Check [Condition A]
   └─ Yes → [Action X]
   └─ No → go to 2
2. Check [Condition B]
   └─ Yes → [Action Y]
   └─ No → go to 3
...
```

■ Priority Rules (When Conflicts Occur)
[Priorities defined in Phase 6.1]
1. [Hard Constraint 1] (mandatory)
2. [Hard Constraint 2] (mandatory)
3. [Soft Constraint 1] (recommended)

■ Exception Rules
[Exceptions discovered in Phase 5 + supplemented in Phase 6.2]
- CI/CD related → chore
- Configuration files → chore
- [Exception added in Phase 6.2]
- ...

■ Boundary Cases and Default Behavior
[Boundary case judgments defined in Phase 6.2]
- [Boundary Case 1]: [Judgment criteria]
- When no conditions match: [Default behavior]

■ Trigger Conditions
[Trigger optimized in Phase 6.5]
- description: [Optimized description]
- Keywords: [keyword1], [keyword2]

■ Test Cases
[Test cases defined in Phase 6.6]
Input example: [Concrete example]
Expected behavior: [Description]

■ Skill Split (If Applicable)
[Split proposal from Phase 6.4]

Does this design work for you?
Please let me know if there are missing perspectives or misunderstandings."

【Important】
Do not start implementation without user confirmation.
Obtain user consent for Phase 6 AI optimization proposals before implementing.
```

### Tacit Knowledge Priority

Priority of tacit knowledge to elicit when creating skills:

```
【First Priority】C: Why (Purpose/Reason)
- Why adopt that policy?
- Why is that important?
- What is the deepest purpose?

【Second Priority】B: Context (Exceptions/Conditional Branches)
                  A: Judgment Criteria (Decision Logic)
- In what situations do judgments change?
- How to judge and choose?
- What are the decision branch points?

【Third Priority】D: Concrete Examples (Edge Cases)
- What cases don't fit general rules?
- How to judge borderline cases?

【Fourth Priority】E: Mental Model (Overall Thought Picture)
- What is the decision flow in your mind?
- In what order do you think?
```

### Essential Elements for Skill Design

Based on elicited tacit knowledge, always include these elements in skills:

```
【Essential Elements】
✓ Why: Why is this skill needed, what is the purpose?
✓ Decision Process: Concrete decision flow (step-by-step)
✓ Decision Branch Axes: Where do judgments diverge?
✓ Exception Rules: Cases that don't fit general rules
✓ Concrete Examples: Representative cases and edge cases
✓ Boundary Conditions: Handling difficult-to-judge cases

【Recommended Elements】
✓ Anti-patterns: What not to do
✓ How to handle uncertainty
✓ When to confirm with user
```

## Question Design Guidelines

Principles for designing questions to elicit tacit knowledge.

### Priority of Effective Question Formats

```
【First Priority】D: Verbalizing Decision Processes
- Verbalize entire thought flow
- "What do you check first? Then what?"
- Follow judgment steps gradually

【Second Priority】B: Finding Decision Axes through Comparison
                  A: Example-Based Questions
- Compare similar cases to identify branch points
- "For Case A and Case B, is the judgment the same? What's the deciding factor?"
- Confirm judgment with concrete scenarios
- "How would you judge this case? What's the reason?"
```

### Good and Bad Question Design Examples

#### ❌ Question Patterns to Avoid

```
1. Abstract or vague questions
   - "What criteria?"
   - "How do you judge?"
   - "Tell me the rules"
   → User finds them hard to answer, only gets surface answers

2. Yes/No questions
   - "Are there exception cases?"
   - "Is this okay?"
   → Cannot deep-dive thinking

3. Leading questions
   - "Generally it's ○○, do you do that?"
   → Becomes Claude's judgment, not user's

4. Questions asking multiple points at once
   - "What do you think about A, B, and C?"
   → Focus blurs, cannot elicit tacit knowledge
```

#### ✅ Effective Question Patterns

```
1. Decision Process Verbalization Type (Top Priority)
   "In [situation], to make [judgment],
   what do you check first?
   → [Answer]
   What do you check next?
   → [Answer]
   How do you judge that?"

   Example:
   "When you see a commit with new files added,
   what do you check first to decide the prefix?
   → I look at the file path
   What part of the file path do you look at?
   → Whether it's in .github/ directory
   What do you do if it's .github/?"

2. Comparison Type (Second Priority)
   "For Case A and Case B, is the judgment the same?
   If different, what's the deciding factor?"

   Example:
   "For adding `src/feature.ts`
   and adding `.github/workflows/ci.yml`,
   is the prefix determination the same?
   If different, what's the deciding factor?"

3. Example-Based Type (Second Priority)
   "For these cases, how would you judge?
   What are the reasons?"

   Example:
   "For these cases, which prefix would you choose?
   - `.github/workflows/ci.yml` added
   - `src/features/login.ts` added
   - `tests/login.test.ts` added
   - `docs/README.md` updated
   Please provide judgment reasons for each."

4. Counter-Example Exploration Type
   "Are there cases that don't fit [general rule]?
   What characteristics do they have?"

   Example:
   "Are there cases that don't fit the "file addition=feat" rule?
   What characteristics do they have?"

5. Why-Because Chain Type
   "What's the reason for [judgment/policy]?
   → [Answer]
   Why is that important?
   → [Answer]
   Furthermore, why is that?"

   Example:
   "Why make CI/CD files chore?
   → Because it's not a feature addition
   Why is it important to distinguish feature additions from CI/CD configuration?
   → When looking at change history..."
```

### Question Timing and Order

```
【Required Order】
1. First confirm Why (purpose) (Phase 2)
   → Cannot derive judgment criteria without this

2. Verbalize decision processes (Phase 3)
   → Grasp overall flow

3. Identify branch points through comparison and examples (Phase 4)
   → Clarify judgment details

4. Discover exceptions through counter-example exploration (Phase 5)
   → Cover edge cases

5. Conduct AI optimization analysis (Phase 6)
   → Convert to AI-executable form
   → Structure, supplement, select implementation means

6. Present final design proposal and confirm (Phase 7)
   → Verify accuracy of understanding
   → Obtain user approval
```

## Skill Quality Standards

Quality check items upon skill creation completion.

### Essential Quality Standards

```
【Purpose Clarity】
✓ Is Why clearly stated?
✓ Is the deepest purpose verbalized?
✓ Are purpose and implementation consistent?

【Decision Process Explicitness】
✓ Is decision flow described step-by-step?
✓ Is what to check at each step clearly stated?
✓ Are judgment criteria concretely described?
✓ Is there no ambiguity or room for guessing?

【Exception Rule Coverage】
✓ Are cases not fitting general rules enumerated?
✓ Are exception rule judgment criteria clearly stated?
✓ Is edge case handling defined?

【Decision Branch Axis Clarity】
✓ Is where judgments diverge clearly stated?
✓ Are branch conditions concretely described?
✓ Are multiple branch axes organized?

【Concrete Example Richness】
✓ Are representative case examples shown?
✓ Are edge case examples shown?
✓ Are difficult-to-judge case examples shown?
```

### Quality Checklist

Check the following upon skill creation completion:

```
【Phase 1-5: Tacit Knowledge Elicitation】
□ Did you complete Phase 1-5 process?
□ Did you sufficiently elicit user's tacit knowledge?
□ Did you deep-dive into Why (purpose)?
□ Did you completely verbalize decision processes?
□ Did you identify branch points through comparison and examples?
□ Did you cover exception rules and edge cases?

【Phase 6: AI Optimization】
□ Did you conduct Phase 6 AI optimization analysis?
□ Did you structure decision flow as decision tree?
□ Did you completely eliminate ambiguity?
□ Did you clarify priorities and constraints?
□ Did you supplement unconsidered exception cases?
□ Did you propose optimal implementation means?
□ Did you consider necessity of skill splitting?
□ Did you optimize trigger conditions?
□ Did you define test cases?
□ Did you design context management strategy?

【Phase 7: Final Confirmation】
□ Did you confirm final design proposal with user?
□ Do you meet all essential quality standards?
□ Did you avoid staying at surface-level instruction implementation?
□ Is creator's thought process systematized?
□ Is it optimized to form AI can execute accurately?
```

### Anti-Pattern Detection

Quality is insufficient if these patterns are observed:

```
❌ Judgment criteria use ambiguous expressions like "appropriately", "as needed"
❌ Decision process just says "check" without specifics
❌ Exception cases dismissed with "others"
❌ Why is not described or superficial
❌ Filled with general best practices
❌ Uses Claude's judgment criteria instead of user's
❌ No concrete examples or edge cases missing
❌ Decision branch axes unclear
```
**要件定義**: ユーザーとの対話を通じて要件を明確にする
- `requirements-elicitation`: 曖昧な要求から具体的な要件を引き出す
- `requirements-specification`: 引き出した要件を受け入れ基準・非機能要件として仕様化する

**設計**: 要件をもとに技術的な設計を行う。code-reviewer の観点を先取りして設計に組み込む
- `design-architecture`: レイヤー構成、技術選定、境界定義、CQRS 適用判断
- `design-data-model`: エンティティ識別、リレーション設計、正規化、マイグレーション
- `design-api`: エンドポイント設計、リクエスト・レスポンス構造、バージョニング
- `design-component`: モジュール・コンポーネントの責務分割とインターフェース設計

**環境構築**: 製品コードの実装より先に整備する技術基盤
- `setup-devcontainer`: コンテナベースの開発環境
- `setup-ci`: CI/CD パイプライン（GitHub Actions）
- `setup-local-infra`: ローカル開発用インフラ（DB、キャッシュ等を docker compose で構築）

**実装**: テストファーストで段階的に実装する
- `implement-feature`: Red-Green-Refactor サイクルでの機能実装
- `implement-testing`: テスト戦略の策定とテスト実装
- `implement-refactor`: 影響範囲の分析と安全なリファクタリング

**その他**
- `commit-message`: git diff を分析し、適切な粒度でステージング・コミットメッセージ生成
- `development-report`: 要件定義・設計・実装の成果物を統合した開発レポート生成

### エージェント

**コードレビュー**: `code-reviewer`
- 変更ファイルの種類に応じて 17 のレビュー観点から関連するものを自動選択し、統合レビューレポートを生成する
- 技術品質（Security, Testing, Error Handling 等）と製品品質（Naming, Readability, SOLID 等）の 2 カテゴリで評価し、技術品質を優先する
- コードレビューを依頼されたとき、自動的に起動される

## 使い方

- 各スキルは `/claude-skills:<skill-name>` で明示的に呼び出せる
- ユーザーの作業内容に応じて自動的に関連するスキルやエージェントが選択されることもある
- 設計スキルと code-reviewer の観点は対になっている（例: `design-architecture` ↔ architecture 観点）。設計時にレビュー観点を先取りし、レビューで指摘される問題を事前に回避する
