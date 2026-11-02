# Smart Entry — Release & Auto-Update Guide

Comprehensive guide for building, packaging, deploying, and distributing new versions of **Smart Entry** (Windows Desktop & Android) with the automated update system.

---

## Architecture Overview

```
                      ┌──────────────────────────────────────┐
                      │ Developer (OrbitView Innovations)    │
                      │ 1. Bump version in pubspec.yaml      │
                      │ 2. Build MSIX or Inno Setup EXE      │
                      │ 3. Upload installer to Supabase      │
                      │ 4. Update 'app_versions' table       │
                      └──────────────────┬───────────────────┘
                                         │
                                         ▼
                      ┌──────────────────────────────────────┐
                      │ Supabase Cloud                       │
                      │ • Storage: 'releases' public bucket  │
                      │ • Database: 'app_versions' row       │
                      └──────────────────┬───────────────────┘
                                         │
                                         ▼
                      ┌──────────────────────────────────────┐
                      │ Client Smart Entry Desktop Apps      │
                      │ • Check version on startup or About  │
                      │ • Download installer silently        │
                      │ • Auto-install & relaunch            │
                      └──────────────────────────────────────┘
```

---

## Quick Step-by-Step Release Workflow

### Step 1: Bump Version Numbers
Open [`pubspec.yaml`](pubspec.yaml) and bump the version in two places:

1. **App Version**:
   ```yaml
   # Change from:
   version: 1.0.0+1
   # To:
   version: 1.0.1+2
   ```

2. **MSIX Windows Version** (around line 151):
   ```yaml
   msix_config:
     display_name: Smart Entry
     publisher_display_name: Ruwan Pathirana
     identity_name: com.ruwan.smartentry
     msix_version: 1.0.1.0   # <- Bump this to match (must be 4 digits)
   ```

---

### Step 2: Build the Windows Installer

Choose your preferred format:

#### Option A: MSIX Package (Recommended for Silent Auto-Updates)
```powershell
flutter build windows --release
flutter pub run msix:create
```
- Output location:
  📁 `build\windows\x64\runner\Release\smart_entry.msix`

#### Option B: Inno Setup Executable (`.exe`)
1. Build the release binaries:
   ```powershell
   flutter build windows --release
   ```
2. Compile your Inno Setup script (`.iss`) or replace:
   📁 `Installer\SmartEntry_Setup.exe`

---

### Step 3: Upload the Installer to Supabase Storage

1. Go to your **Supabase Dashboard** -> **Storage**.
2. Select (or create) the bucket named **`releases`**.
   > [!IMPORTANT]
   > The bucket **must be set to Public** so client installations can download the file without API keys.
3. Upload your built installer:
   - For MSIX: `smart_entry_1.0.1.msix` (or `smart_entry.msix`)
   - For EXE: `SmartEntry_Setup.exe`
4. Click the file options `...` -> **Copy URL** (Public URL).
   *(Example: `https://your-project.supabase.co/storage/v1/object/public/releases/smart_entry_1.0.1.msix`)*

---

### Step 4: Publish the Version in Supabase

Run the following SQL in the **Supabase SQL Editor**:

```sql
UPDATE app_versions
SET
  version       = '1.0.1',
  download_url  = 'https://YOUR_PROJECT_ID.supabase.co/storage/v1/object/public/releases/smart_entry_1.0.1.msix',
  release_notes = '• Improved user interface and responsive layouts\n• Enhanced leaf rate calculation\n• Performance and stability optimizations',
  is_mandatory  = false,   -- Set to true if all clients MUST update before continuing
  created_at    = now()
WHERE id = 'windows';
```

---

### Step 5: Verify the Live Update

1. Launch Smart Entry on a test Windows machine running version `1.0.0`.
2. Navigate to **Settings** -> **About** tab.
3. Click **Check for Updates**.
4. The system will prompt the update modal, download the file, and execute the installation.

---

## Android Builds (Mobile & Tablet)

For client Android devices:

```powershell
# Standard APK for direct sideloading / WhatsApp sharing:
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Google Play Store App Bundle:
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## Release Checklist

- [ ] All code changes committed to git.
- [ ] Code comments are strictly in English (per `GEMINI.md`).
- [ ] Version updated in `pubspec.yaml` (`version` and `msix_version`).
- [ ] Windows build completed successfully with `flutter pub run msix:create`.
- [ ] Installer uploaded to Supabase Storage `releases` public bucket.
- [ ] Public URL verified in a browser (downloads file directly with HTTP 200).
- [ ] `app_versions` row updated in Supabase with matching version and URL.
- [ ] Tested update from a client machine.

---

*Authored by OrbitView Innovations — Technical Engineering Team*
