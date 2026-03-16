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
│   └── plugin.json               # Plugin manifest
├── .claude/
│   ├── CLAUDE.md                  # For plugin developers (this file)
│   └── CLAUDE.ja.md              # Japanese version of this file
├── CLAUDE.md                      # For plugin consumers (skill overview & usage)
├── README.md                      # For humans (setup procedures, etc.)
├── skills/                        # Skill implementations
│   └── <skill-name>/
│       ├── SKILL.md               # Entry point (YAML frontmatter + instructions)
│       └── resources/             # Detailed references, checklists, etc.
└── agents/                        # Agent definitions
    ├── <agent-name>.md            # Agent definition (YAML frontmatter + system prompt)
    └── <agent-name>-resources/    # Agent resources
```

## Skill Creation & Editing Rules

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
2. **Update this file**: If the feedback is a general rule applicable to other skills, add it as a rule to the "Rules to Follow" or relevant section of this file
3. **Horizontal deployment to existing skills**: If existing skills violate the added rule, fix them as well

## Tacit Knowledge Elicitation Protocol for Skill Creation

When receiving a skill creation request, do not simply implement surface-level instructions. Follow this protocol to systematically elicit the user's tacit knowledge.

### Basic Principles

**Prohibited Actions:**
- Implementing instructions as-is
- Asking abstract or vague questions ("What criteria?", etc.)
- Filling gaps with general best practices
- Guessing decision processes

**Required Actions:**
- Elicit tacit knowledge through a 7-stage structured process and optimize for AI
- Prioritize deep-diving into Why (purpose/reason)
- Verbalize decision processes
- Identify decision branch points through comparison and examples
- Convert to AI-executable form and optimize

### 7-Stage Skill Creation Process

```
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
1. Receive user instructions
2. Structure surface-level elements of instructions
   - What to create (What)
   - What functionality (Function)
   - What constraints (Constraint)

Output Example:
"I received a request to create a skill with the following content:
- Target: commit-message skill
- Functionality: Add prefix, separate granularity
- Constraints: (Not specified)

I will confirm step-by-step to elicit tacit knowledge."
```

#### Phase 2: Deep-Dive into Why (Purpose/Reason) [Top Priority]
```
Question Design:
Identify why that policy is adopted and the deepest purpose.
Dig deeper with Why-Because chains, not just surface reasons.

Bad question: "Why add prefixes?"
  -> Only gets surface answers

Good question:
"What is the purpose of adding prefixes?
- Improve commit history searchability?
- Visualize change impact?
- Automatic determination in CI/CD?
- Team communication?

Why is that important? (dig deeper)"

Important:
Understanding Why naturally derives judgment criteria.
Do not implement without clear purpose.
```

#### Phase 3: Verbalize Decision Processes [Second Priority]
```
Question Design:
Verbalize the decision flow in the user's mind.
Follow specific steps, not abstract questions.

Bad question: "What criteria do you use to choose prefixes?"
  -> Too vague to answer

Good question:
"When you see a commit with new files added,
what do you check first to decide the prefix?

-> User answer: "I look at the file's role"

How do you determine the file's role?
What specific information do you look at?

-> User answer: "I look at the path, if it's CI/CD related..."

What do you check next?"

Goal:
Completely verbalize decision flow:
1. Check file path
2. Determine if CI/CD-related directory
3. Yes -> chore, No -> next step
4. ...
```

#### Phase 4: Identify Decision Branch Points through Comparison [Second Priority]
```
Question Design:
Compare similar cases to identify decision branch points.

Bad question: "Are there exception cases?"
  -> User may not think of them

Good question:
"For these two cases, is the prefix determination the same?
If different, what's the deciding factor?

Case A: `src/features/login.ts` added
Case B: `.github/workflows/ci.yml` added

-> User answer clarifies branch points

How about these cases?
Case C: `tests/login.test.ts` added
Case D: `docs/README.md` updated"

Goal - Identify judgment axes:
- File role (feature vs infrastructure vs test vs documentation)
- Change type (add vs update vs delete)
- Impact scope (user-facing vs developer-facing)
```

#### Phase 5: Discover Edge Cases and Exceptions through Examples
```
Question Design:
Explore cases that don't fit general rules,
identifying exception rules and conditional branches.

Effective question:
"Are there cases that don't fit the 'file addition = feat' rule?
What characteristics do they have?

How would you judge these cases?
- Configuration file addition (`.env.example`)
- Build configuration addition (`tsconfig.json`)
- Dependency addition (`package.json` update)
- Git-related files (`.gitignore` update)"

Goal - Comprehensively identify exception rules:
- CI/CD related -> chore
- Configuration files -> chore
- Documentation -> docs
- Tests -> test
- etc.
```

#### Phase 6: AI Optimization Analysis [Required]

```
Purpose:
Convert tacit knowledge elicited in Phase 1-5 to "AI-optimal form".
Optimize user judgment criteria into structures AI can execute accurately.

Important:
This phase must not be skipped.
Rather than implementing user thought processes as-is,
converting to AI-optimized form significantly improves accuracy.
```

##### 6.1 Structure Decision Flows [First Priority]

```
Analysis Perspective:
Convert decision processes verbalized in Phase 3 to structures optimal for AI execution.

Checklist:
- Complete ambiguity elimination
  - No expressions like "appropriately", "as needed"
  - All judgment criteria concretely defined
- Clarify priorities
  - Specify priorities when multiple conditions conflict
  - Distinguish "hard constraints" (mandatory) from "soft constraints" (recommended)
- Structure as decision tree
  - Express decision flow as clear decision tree
  - Specify "what to check and how to branch" at each node
  - Define handling of dead ends (undecidable cases)

Proposal Template:
"For the decision process verbalized in Phase 3,
I propose the following structuring for AI execution:

Decision Tree Flow:
1. Check [Condition A]
   -> Yes: [Action X]
   -> No: go to 2
2. Check [Condition B]
   -> Yes: [Action Y]
   -> No: go to 3
3. Check [Condition C]
   -> Yes: [Action Z]
   -> No: User confirmation

Priority Rules (when conflicts occur):
1. [Hard Constraint 1] (mandatory)
2. [Hard Constraint 2] (mandatory)
3. [Soft Constraint 1] (recommended)

Ambiguity Resolution:
I propose changing current expression '[ambiguous expression]'
to concrete criteria '[clear criteria]'.

Does this structuring work for you?"
```

##### 6.2 Supplement and Clarify Conditional Branches [Second Priority]

```
Analysis Perspective:
Propose conditional branches the user didn't make explicit but AI needs.

Checklist:
- Exception cases user didn't notice
  - Exceptions predictable from domain knowledge
  - Exceptions common in similar systems
- Boundary case judgment criteria
  - Clarify difficult-to-judge cases
  - Handle "could go either way" cases
- Default behavior definition
  - Behavior when no conditions match
  - Safe fallback on error

Proposal Template:
"I propose adding the following conditional branches:

Unconsidered Exception Cases:
[Case]: [Proposed judgment]
Reason: [Why this case could occur]

Boundary Case Handling:
[Boundary Case]: [Proposed judgment criteria]
Example: [Concrete example]

Default Behavior:
When no conditions match: [Proposed behavior]

Are these additions necessary?
Or do these cases not actually occur?"
```

##### 6.3 Optimize Implementation Means [Third Priority]

```
Analysis Perspective:
Propose optimal means to implement elicited tacit knowledge.

Options:
A. Skills (claude-skills/skills/)
B. Hooks (auto-start via config file)
C. CLAUDE.md (project-wide rules)
D. Memory (auto memory)

Decision Criteria:

Choose Skills when:
- Complex decision processes exist
- Step-by-step questions/confirmations needed
- Long explanations/references needed
- Explicitly invoked by specific trigger

Choose Hooks when:
- Auto-execute on specific events (pre-commit, PR creation, etc.)
- Simple decision process
- Completes without user intervention

Choose CLAUDE.md when:
- Rules applied across entire project
- Principles to follow horizontally across all skills
- Project design philosophy/values

Choose Memory when:
- Temporary project-specific information
- Patterns to share between sessions
- Experimental rules not yet established
```

##### 6.4 Propose Skill Splitting [Fourth Priority]

```
Signals to Split:
- Has multiple different responsibilities
- Clearly different trigger conditions
- Has reusable parts
- Has independently testable parts

Signals to Consolidate:
- Always used together
- Meaningless alone
- Difficult to understand when split
- High splitting overhead
```

##### 6.5 Optimize Pattern Recognition [Fifth Priority]

```
Checklist:
- Description clarity
  - Is when to use clearly described?
  - Are keywords appropriately included?
- Few-shot example enrichment
  - Include 3-5 representative use cases
  - Include 1-2 edge case examples
- Explicit trigger keywords
  - What words/phrases should trigger the skill?
  - Exclusion keywords to prevent false triggers
```

##### 6.6 Cross-cutting Quality Aspects

```
Testability Design:
- Test case definition (Input, Expected decision process, Expected output)
- Verification method (How to confirm skill works correctly)

Context Management Strategy:
- Clarify required information (what, when to acquire)
- Information priority (Essential / Recommended / Optional)

Feedback Loop Design:
- Record user correction patterns
- Accumulate common misjudgment patterns
- What to record in Memory, periodic review timing

Strict Role and Output Format Definition:
- Persona setting (AI's role, expertise level)
- Explicit output format (structured tags, template definition)
```

#### Phase 7: Present Final Design and Confirm
```
Integrate information elicited and optimized in Phase 1-6,
presenting final skill design proposal.

Important:
Do not start implementation without user confirmation.
Obtain user consent for Phase 6 AI optimization proposals before implementing.
```

### Tacit Knowledge Priority

```
First Priority: Why (Purpose/Reason)
- Why adopt that policy?
- Why is that important?
- What is the deepest purpose?

Second Priority: Context (Exceptions/Conditional Branches)
                 Judgment Criteria (Decision Logic)
- In what situations do judgments change?
- How to judge and choose?
- What are the decision branch points?

Third Priority: Concrete Examples (Edge Cases)
- What cases don't fit general rules?
- How to judge borderline cases?

Fourth Priority: Mental Model (Overall Thought Picture)
- What is the decision flow in your mind?
- In what order do you think?
```

### Essential Elements for Skill Design

```
Essential Elements:
- Why: Why is this skill needed, what is the purpose?
- Decision Process: Concrete decision flow (step-by-step)
- Decision Branch Axes: Where do judgments diverge?
- Exception Rules: Cases that don't fit general rules
- Concrete Examples: Representative cases and edge cases
- Boundary Conditions: Handling difficult-to-judge cases

Recommended Elements:
- Anti-patterns: What not to do
- How to handle uncertainty
- When to confirm with user
```

## Question Design Guidelines

### Priority of Effective Question Formats

```
First Priority: Verbalizing Decision Processes
- Verbalize entire thought flow
- "What do you check first? Then what?"
- Follow judgment steps gradually

Second Priority: Finding Decision Axes through Comparison / Example-Based Questions
- Compare similar cases to identify branch points
- "For Case A and Case B, is the judgment the same? What's the deciding factor?"
- Confirm judgment with concrete scenarios
```

### Question Patterns to Avoid

```
1. Abstract or vague questions ("What criteria?", "How do you judge?")
2. Yes/No questions ("Are there exception cases?")
3. Leading questions ("Generally it's X, do you do that?")
4. Questions asking multiple points at once
```

### Effective Question Patterns

```
1. Decision Process Verbalization Type (Top Priority)
   "In [situation], to make [judgment], what do you check first?"

2. Comparison Type (Second Priority)
   "For Case A and Case B, is the judgment the same? What's the deciding factor?"

3. Example-Based Type (Second Priority)
   "For these cases, how would you judge? What are the reasons?"

4. Counter-Example Exploration Type
   "Are there cases that don't fit [general rule]? What characteristics do they have?"

5. Why-Because Chain Type
   "What's the reason for [judgment/policy]? Why is that important? Furthermore, why?"
```

## Skill Quality Standards

### Essential Quality Standards

```
Purpose Clarity:
- Is Why clearly stated?
- Is the deepest purpose verbalized?
- Are purpose and implementation consistent?

Decision Process Explicitness:
- Is decision flow described step-by-step?
- Is what to check at each step clearly stated?
- Are judgment criteria concretely described?
- Is there no ambiguity or room for guessing?

Exception Rule Coverage:
- Are cases not fitting general rules enumerated?
- Are exception rule judgment criteria clearly stated?
- Is edge case handling defined?

Decision Branch Axis Clarity:
- Is where judgments diverge clearly stated?
- Are branch conditions concretely described?

Concrete Example Richness:
- Are representative case examples shown?
- Are edge case examples shown?
- Are difficult-to-judge case examples shown?
```

### Anti-Pattern Detection

Quality is insufficient if these patterns are observed:

```
- Judgment criteria use ambiguous expressions like "appropriately", "as needed"
- Decision process just says "check" without specifics
- Exception cases dismissed with "others"
- Why is not described or superficial
- Filled with general best practices
- Uses Claude's judgment criteria instead of user's
- No concrete examples or edge cases missing
- Decision branch axes unclear
```
