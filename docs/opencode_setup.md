# OpenCode API Key Setup

This guide explains how to obtain an OpenCode API key and configure it for the PR review GitHub Actions workflow.

---

## 1. Obtain an OpenCode API Key

### Option A: OpenCode Zen (hosted)

1. Go to [https://opencode.ai](https://opencode.ai)
2. Sign up or log in to your account
3. Navigate to **Settings** → **API Keys**
4. Click **Create new key**
5. Give it a name (e.g., `github-actions-pr-review`)
6. Copy the generated key (starts with `sk-`)

### Option B: Self-hosted OpenCode

1. Ensure your OpenCode server is running
2. Run `opencode auth` to generate a token
3. Copy the token

---

## 2. Add the Key to GitHub Repository Secrets

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Set:
   - **Name:** `OPENCODE_API_KEY`
   - **Value:** Your OpenCode API key (from step 1)
5. Click **Add secret**

---

## 3. Verify the Workflow

1. Open a pull request against `develop`
2. The **PR Review** workflow will automatically trigger
3. Check the **Actions** tab to see the workflow run
4. Once complete, the review will be posted as a comment on the PR

---

## 4. Workflow Details

| Setting | Value |
|---------|-------|
| Trigger | PR opened, synchronized, reopened |
| Model | `opencode/big-pickle` |
| Output | PR comment with review |
| Permissions | `contents: read`, `pull-requests: write` |

---

## 5. Troubleshooting

| Issue | Solution |
|-------|----------|
| Workflow fails with auth error | Verify `OPENCODE_API_KEY` secret is set correctly |
| Review not posted | Check workflow logs for errors; ensure `pull-requests: write` permission |
| Model not found | Verify the model ID `opencode/big-pickle` is available in your OpenCode plan |
