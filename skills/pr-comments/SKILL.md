---
name: pr-comments
description: Use whenever leaving comments on GitHub on the user's behalf. Covers review comments (findings on a PR you review) and answers (replies to reviewers and bots on a PR you work on).
---

# PR Comments

Every comment an agent posts on the user's behalf is one of two kinds. Pick
the kind first, then use its template.

| Kind | When | Template |
| --- | --- | --- |
| **Review comment** | You are reviewing a PR and raising something: an inline finding, or the body of a review you submit. | [Review comments](#review-comments) |
| **Answer** | Someone (a human or a review bot) raised something on a PR you work on, and you reply: fixed it, declined it, or need to ask. Also the written reason before you resolve or dismiss feedback. | [Answers](#answers) |

A top-level comment that is neither (for example a status note the user asked
for) uses the attribution below and the writing rules, with no template.

## Attribution (both kinds)

Every comment starts with a GitHub note callout. The verb says which kind it
is:

```md
> [!NOTE]
> 🤖 **<model> reviewing on behalf of <user>**
```

```md
> [!NOTE]
> 🤖 **<model> responding on behalf of <user>**
```

- Use the verified public name of the model that wrote the comment, and the
  user's name or GitHub login. If the harness does not expose a model name,
  use the harness name. Do not guess.
- The line starts with the robot emoji. Keep the attribution inside the note
  and the comment itself outside it, after one blank line.
- Do not add a horizontal rule, Setext underline, heading, signature footer,
  or a second attribution.
- Do not add it to PR descriptions, commit messages, or text the user
  explicitly asked to post verbatim without attribution.

## Review comments

One finding per inline comment, anchored to the line it is about. Lead with a
severity label so the author can triage at a glance:

- `blocker`: the intended case is wrong; the PR should not merge as is.
- `should`: a real bug callers will hit, within the PR's intent.
- `nit`: everything else (style, rare paths, small costs). The author may
  ignore it.
- `question`: you cannot tell whether it is a bug. Ask, do not assert.

Inline comment template:

````md
> [!NOTE]
> 🤖 **<model> reviewing on behalf of <user>**

**<severity>:** <the claim in one sentence>.

<evidence: what you ran or read, e.g. `path/to/file.ts:42` calls this with `null` when ...>

```suggestion
<replacement lines, only when the fix is small and you are sure of it>
```
````

- Drop the `suggestion` block when the fix is not a drop-in replacement for
  the anchored lines. Describe the fix in one sentence instead.
- Do not post a finding you have not verified against the code. Mark what is
  judgment rather than fact ("I think", "likely").
- Do not split one issue across several comments, or repeat a finding that is
  already open on the PR.

Review body template (the summary submitted with the inline comments):

```md
> [!NOTE]
> 🤖 **<model> reviewing on behalf of <user>**

**<Approve | Request changes | Comment>:** <one sentence on why>.

- <n> blocker, <n> should, <n> nit (inline)
- Checked: <what you ran or read: tests, a reproduction, the files you traced>
- Not checked: <what you could not verify, or "nothing">
```

Submit the inline comments and the body as one review
(`gh api repos/<owner>/<repo>/pulls/<n>/reviews` with `comments[]`), not as
separate comments. Use the review event the user asked for. Without an
explicit request, submit `COMMENT`, never `APPROVE` or `REQUEST_CHANGES`.

## Answers

Reply in the thread you are answering, not in a new top-level comment. Lead
with the outcome:

- `Fixed in <short sha>`: you changed the code. Link the commit.
- `Won't fix`: you disagree or it is out of scope. Give the reason.
- `Question`: you need the reviewer or the user to decide.

Answer template:

```md
> [!NOTE]
> 🤖 **<model> responding on behalf of <user>**

**<Fixed in abc1234 | Won't fix | Question>:** <one sentence>.

<evidence: the test that now covers it, the line that already handles the case,
the reproduction output, or the trade-off behind declining>
```

- For `Fixed`, push the commit first, then reply with its SHA. Say in a few
  words what changed if the SHA alone does not make it obvious.
- For `Won't fix`, cite code, behavior, or the PR's stated scope. "Out of
  scope, follow-up: <link or one line>" is enough for a nit.
- When one fix answers several threads, answer each thread on its own,
  briefly, and point to the same commit.
- Do not thank the reviewer or bot, apologize, or restate their comment.

Resolve a thread only after your answer posted successfully, and only for
`Fixed` and `Won't fix` answers to bots or answers the reviewer will not
contest. Leave a human reviewer's thread open for them to resolve when you
declined their request.

## Writing rules (both kinds)

- Lead with the conclusion. One idea per comment.
- Cite the relevant code, behavior, check, or reproduction.
- Keep it concise. No filler, canned thanks, or status narration.
- Distinguish verified facts from judgment.

## Before and after posting

Before posting, check the whole comment, including quoted text, suggestions,
and attachments, for secrets and private details.

Preview the final Markdown so quoting, the callout, and blank lines render as
shown. After posting, verify that GitHub returned the comment or review URL.
