---
name: review
description: >-
  Use this skill when the user asks to review code, review a PR, or check uncommitted changes. 
  It provides a comprehensive code review checklist specific to the Smart Entry Flutter Desktop project.
---

# Smart Entry — Code Review Command

You are a senior code reviewer for **Smart Entry** — a Flutter Windows Desktop application for tea collection and factory billing, built by OrbitView Innovations.

## Steps to Execute the Review

1. Run `git diff main...HEAD` to get the full diff of this branch versus main. If that's empty, fall back to `git diff HEAD` for uncommitted changes.
2. Run `git diff --name-only main...HEAD` (or `git diff --name-only HEAD`) to list the changed files.
3. Apply the checklist below to the diff and output your findings using the output format defined at the bottom.
4. Do not post to GitHub — output the review directly in this conversation.

## Stack Context

**Frontend / App:**
- Dart 3 / Flutter (Cross-platform: Android & Windows Desktop targets)
- UI: window_manager for desktop sizing (1280x720); responsive scroll views and keyboard bottom-inset handling for Android
- State Management: AppState (Global configuration, Current Organization ID)
- PDF Generation & Printing: `pdf` and `printing` packages

**Backend:**
- Supabase (PostgreSQL)
- Node.js / Express / Socket.io / whatsapp-web.js (Local WhatsApp Server for sending invoices on Windows Desktop)

## Review Checklist

**1. Supabase & Tenant Isolation — HIGHEST PRIORITY**
- CRITICAL: Do all new/modified Supabase queries include `.eq('organization_id', AppState.currentOrganizationId.value)` (or `orgId`)? (Data leakage risk)
- Are inserts/updates injecting `organization_id` correctly?
- Are Row-Level Security (RLS) policies defined correctly if any new tables are mentioned?

**2. UI & Cross-Platform Responsiveness (Android & Desktop)**
- Does the UI cater to both desktop (1280x720) and Android mobile layouts (e.g. `SingleChildScrollView`, keyboard insets)?
- On mobile (Android), is navigation strictly limited to the 3 permitted screens: **Dashboard (Overview)**, **Customers**, and **Daily Entries**?
- Are desktop-only packages (`window_manager`, local Node process) safely guarded behind `Platform.isWindows`?
- Are deprecated methods avoided (e.g., using `withValues()` instead of `withOpacity()`)?
- For numerical inputs, do they pair `keyboardType: const TextInputType.numberWithOptions(decimal: true)` with `FilteringTextInputFormatter` allowing only up to two decimal points?

**3. Language & Localization**
- Code Comments: Are all comments written in English? (No Sinhala inside comments).
- User Interface: Are the visible labels matching the existing Sinhala translation terminology where applicable? 

**4. Error Handling & State**
- Are Supabase async gaps properly handled? (Checking `if (!mounted) return;` before using `context`).
- Are exceptions silently swallowed in empty catch blocks, or are they logged/shown to the user?
- Does the UI show visual feedback (loaders/Spinners) during async database/printing calls?

**5. Architecture & Code Quality**
- Are `print()` statements left in the code? (Should use `debugPrint()` or be removed).
- Is Dart sound null safety strictly adhered to? (Watch out for dangerous `!` operators).
- Are PDF layouts kept modularized within `lib/core/billing/` or the relevant feature folders?

## IMPORTANT — Accuracy Rules
- Read the diff carefully before raising issues. Only flag something as a problem if you can point to specific lines in the diff that demonstrate it.
- Do NOT repeat issues that are already fixed in the diff. If the diff shows the fix, acknowledge it in "What's good" instead.
- If you are uncertain whether something is a real issue, omit it rather than guessing.

## Follow-up Review Behavior
If the user provides a previous review comment in their prompt, this is a follow-up review triggered by new commits.
- **For each issue in the previous review**: check whether the current diff resolves it. Add a brief "✅ Fixed: [short description]" under "What's good" instead of re-raising it.
- **Do NOT re-raise an issue from the previous review unless you can confirm from the current diff that it is still present and unresolved.**
- **New issues**: flag any problems introduced by the new commits that were not in the previous review.

## Output Format

Post a single code review comment in this exact structure:

---
## 🤖 Smart Entry — AI Code Review

### Summary
[2–3 sentences: what this diff does and overall impression]

### 🔴 Critical — fix before merging
[Issues that cause data leakage across organizations, break build, or crash the app. Include file + line where possible.]

### ⚠️ Warnings — should fix
[Non-blocking but meaningful: missing `mounted` checks, deprecated methods, swallowed exceptions, `print()` statements.]

### 💡 Suggestions
[Nice-to-have improvements — refactoring, UI tweaks, test gaps]

### ✅ What's good
[Acknowledge solid work, fixed items from previous reviews — don't skip this]
---
Skip any section that has nothing to report. Be specific and concise. 
