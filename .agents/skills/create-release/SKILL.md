---
name: create-release
description: >-
  Use this skill when the user asks to create a new release, build a new version, 
  publish an update, or deploy an installer for Smart Entry (Windows Desktop or Android).
---

# Smart Entry — Create New Release Skill

You are an expert Release Engineer & DevOps Architect for **Smart Entry** (built by OrbitView Innovations).
Your job is to assist the user in building, packaging, and deploying a new release for Windows Desktop and Android.

---

## When to Activate This Skill
- The user asks to:
  - "create a new release"
  - "build new version / update"
  - "publish update to clients"
  - "how do I update the installer"
  - "deploy app update"

---

## Step-by-Step Release Procedure

### 1. Pre-Release Validation
Before building:
1. Run `git status -s` to inspect uncommitted changes.
2. Verify code quality:
   - Ensure all code comments are in English (per `GEMINI.md`).
   - Check multi-tenancy: Supabase queries MUST use `AppState.currentOrganizationId` / `.eq('organization_id', orgId)`.
3. Check current version:
   - Read `pubspec.yaml` to find the current version (e.g., `1.0.0+1`).

### 2. Determine the Next Version
Ask or confirm the next semantic version with the user:
- **Patch** (Bug fixes & minor UI polish): e.g. `1.0.0` -> `1.0.1+2` (MSIX: `1.0.1.0`)
- **Minor** (New features / new tabs / calculations): e.g. `1.0.0` -> `1.1.0+2` (MSIX: `1.1.0.0`)
- **Major** (Breaking architecture changes): e.g. `1.0.0` -> `2.0.0+1` (MSIX: `2.0.0.0`)

### 3. Update Configuration Files
Update [`pubspec.yaml`](file:///pubspec.yaml):
1. Bump `version: X.Y.Z+BUILD`
2. Bump `msix_config.msix_version: X.Y.Z.0` (must have exactly 4 numbers)

### 4. Build Windows MSIX Package
Execute in the terminal:
```powershell
flutter build windows --release
flutter pub run msix:create
```
Verify the output exists:
`build\windows\x64\runner\Release\smart_entry.msix`

*(If the user requests an Android APK instead):*
```powershell
flutter build apk --release
```
Output: `build\app\outputs\flutter-apk\app-release.apk`

### 5. Guide Supabase Storage Upload
Instruct the user:
1. Open **Supabase Dashboard** -> **Storage** -> **releases** bucket.
2. Confirm the bucket is **Public**.
3. Upload the newly created `smart_entry.msix` file.
4. Copy the **Public URL** (e.g. `https://<project-id>.supabase.co/storage/v1/object/public/releases/smart_entry.msix`).

### 6. Generate the SQL Query for `app_versions`
Provide the exact SQL snippet for the user to run in the **Supabase SQL Editor**:

```sql
UPDATE app_versions
SET
  version       = '<NEW_VERSION>',
  download_url  = '<PUBLIC_SUPABASE_STORAGE_URL>',
  release_notes = '<RELEASE_NOTES_SUMMARY>',
  is_mandatory  = false,
  created_at    = now()
WHERE id = 'windows';
```

### 7. Post-Release Verification
- Have the user launch the app and navigate to **Settings** -> **About**.
- Click **Check for Updates** to confirm the update downloads and installs successfully.
