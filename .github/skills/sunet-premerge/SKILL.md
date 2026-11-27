---
name: sunet-premerge
description: 'Quick pre-merge check of a PR into main via the gh CLI: short summary, merge readiness (CI, reviews, conflicts, stack) and any remarks. Use when the user types /sunet-premerge or is about to merge a PR.'
---

## Style
- Short sentences, no filler or restating.
- Bullet points under the required headings.

You are a senior engineer giving a last check before a PR is merged. Be fast: this is a gate, not a full review. Do NOT merge, approve, push, or post anything to GitHub unless I explicitly say so.

The PR is given after the command: a URL (`https://github.com/OWNER/REPO/pull/N`) or a number (then use the current repo). If nothing was given, use the PR of the current branch (`gh pr view`). If none is found, ask me and stop.

## 1. Gather context
Use `gh` (if missing or unauthenticated, tell me to run `gh auth login` and stop). Replace PR with the URL or number:

- `gh pr view PR --json title,body,author,baseRefName,headRefName,isDraft,state,mergeable,mergeStateStatus,reviewDecision,files,commits,additions,deletions,latestReviews`
- `gh pr diff PR`
- `gh pr checks PR`
- `gh pr view PR --comments` (conversation and review summaries)
- Unresolved inline threads. REST does not expose resolved state, so use GraphQL and keep threads where `isResolved` is false:

```
gh api graphql --paginate -F owner=OWNER -F repo=REPO -F number=N -f query='
query($owner:String!, $repo:String!, $number:Int!, $endCursor:String) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) {
      reviewThreads(first:100, after:$endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          isResolved isOutdated path line
          comments(first:100) { totalCount nodes { author { login } body url } }
        }
      }
    }
  }
}'
```

## 2. Check merge readiness
- Base branch is `main` (or the default branch). If not, say so: this may be a stacked PR.
- Not a draft. State is open.
- No merge conflicts (`mergeable`, `mergeStateStatus`).
- CI and quality gates (SonarCloud etc.) pass. Name each failing or pending check.
- Review decision is approved. Note requested changes and missing required reviews.
- Review threads: list unresolved threads (`isResolved` false) and unanswered findings from people, Copilot, code scanning.
- Stack: if the description or base branch shows dependencies on other PRs, say which must merge first.
- Description claims vs diff: leftover TODOs, debug output, unrelated files, secrets, missing tests or docs for changed behaviour, breaking changes to API, config or stored data.

Skim the diff for real problems only (correctness, security, compatibility). Do not do a line-by-line review. For a deep review point me to `/sunet-prreview`.

## 3. Report
Use exactly this structure:

### Verdict
One line: **Ready to merge**, **Merge with remarks**, or **Do not merge yet**, plus the single biggest reason.

### Summary
2-3 sentences on what the PR does. Then size: files changed, additions/deletions, commit count.

### Remarks
- **Blockers:** failing checks, conflicts, missing approval, unresolved threads, wrong base. Each with the next action.
- **Worth a look:** risks found in the diff, with `path:line`.
- **Minor:** nits, doc gaps.

Write "None" where there is nothing. Do not invent problems.

### Merge command
Only when the verdict is not "Do not merge yet". Suggest the matching command (e.g. `gh pr merge PR --squash --delete-branch`) and ask which merge method I want. Run it only if I say yes.
