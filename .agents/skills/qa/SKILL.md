---
name: qa
description: >-
  Use this skill to run a full QA test run and validation checklist before any commit, merge, or release in Smart Entry.
  Enforces organization-wise tenant isolation first and foremost (everything belongs strictly to organization_id),
  runs automated test suites, static analysis, platform constraint checks, and provides protocols to update this skill
  as new features are implemented.
---

# Smart Entry — Pre-Commit & Pre-Merge QA Skill

You are the Lead Quality Assurance (QA) & Multi-Tenant Security Auditor for **Smart Entry** (built by OrbitView Innovations).  
Your mission is to perform rigorous verification before any code is committed, merged, or released.

---

## 🔒 RULE #1: Organization-Wise Isolation (NON-NEGOTIABLE)

Smart Entry is a multi-tenant platform serving multiple independent tea collection organizations (e.g., *Orbit View Innovations*, *Naleen Suranga*).

### Non-Negotiable Rules:
1. **Zero Cross-Tenant Leakage**: No organization may ever view, edit, calculate, or delete data belonging to another organization.
2. **Mandatory `organization_id` Scoping**:
   - Every read query MUST contain `.eq('organization_id', orgId)` (using `AppState.currentOrganizationId.value`).
   - Every insert/upsert MUST inject `'organization_id': orgId`.
   - Every update/delete MUST chain `.eq('organization_id', orgId)`.
3. **Automated Tenant Isolation Scanner**:
   - The test [`test/tenant_isolation_scanner_test.dart`](file:///test/tenant_isolation_scanner_test.dart) scans all Dart files in `lib/` to verify every Supabase query adheres to this rule. It must pass 100%.

---

## 📋 Step-by-Step QA Execution Procedure

When this skill is invoked (or before every merge commit), execute these steps in order:

### Step 1: Run Automated Tenant Isolation Scanner & Tests
Execute the full automated test suite:
```powershell
flutter.bat test
```
*Verification criteria:*
- `test/tenant_isolation_scanner_test.dart` passes (zero un-scoped queries).
- `test/factory_tenant_isolation_test.dart` passes (factory multi-tenant partition verified).
- `test/factory_daily_allocation_test.dart` passes (daily collection summation, other factory isolation & live balance).
- `test/max_number_input_formatter_test.dart` passes (currency input length & paste sanitization).
- `test/billing_lock_service_test.dart` passes (past month lock & recalculation permissions).
- `test/item_service_test.dart` passes (dynamic items limit & double-counting prevention).
- `test/localization_test.dart` passes (Sinhala & English strings valid).
- `test/widget_test.dart` passes.
- **Expected result**: All tests pass with 0 failures.

### Step 2: Run Dart Static Analysis & Sound Null Safety
Execute Dart static analysis:
```powershell
dart analyze lib test
```
*Verification criteria:*
- Zero compile errors (`error`).
- Zero unhandled null safety exceptions (`!`).
- Deprecated methods avoided:
  - Use `.withValues()` instead of `.withOpacity()`.
  - Use `initialValue` instead of `value` in form fields.

### Step 3: Code Guidelines & Cleanliness Check
Inspect diff (`git diff HEAD`) against project standards:
- **Comments**: All code comments MUST be in English. No Sinhala inside code comments.
- **Logging**: Production code in `lib/` must avoid `print()`; use `debugPrint()` or dedicated logging.
- **Numerical Inputs**: Form fields for numbers must use:
  ```dart
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  inputFormatters: [
    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
  ],
  ```

### Step 4: Cross-Platform Constraints Check
- **Android Mobile**: Navigation is strictly limited to 3 screens:
  1. **Dashboard (Overview)**
  2. **Customers**
  3. **Daily Entries**
  *(Factories, Reports, and Settings must remain desktop-only).*
- **Windows Desktop**: All desktop-specific integrations (`window_manager`, local Node.js WhatsApp server) must be guarded behind:
  ```dart
  if (!kIsWeb && Platform.isWindows) { ... }
  ```

---

## 🎯 Current Feature Test Scenarios (Baseline Matrix)

When testing, verify that changes do not regress these active feature scenarios:

### Scenario 1: Factories (`lib/core/factory/`)
- [ ] **Directory Listing**: Only factories where `organization_id == AppState.currentOrganizationId.value` are displayed.
- [ ] **Scoped Ref Number**: Reference number uniqueness check is scoped per organization (different organizations can have Factory #1 without collision).
- [ ] **Factory Settings & Ledger**: Monthly leaf rates, custom items, and activity logs are strictly tied to the factory's `organization_id`.
- [ ] **Combined Summary**: Aggregations and reconciliations in `AllFactoriesSummaryWidget` aggregate only entries matching the active organization.
- [ ] **Reactive Updates**: Screen listens to `AppState.currentOrganizationId` and `AppState.refreshTrigger`, immediately refreshing on organization switch.

### Scenario 2: Customers & Credit Limits (`lib/core/customer/`, `lib/services/`)
- [ ] **Customer Directory**: Customer records are strictly scoped to `organization_id`.
- [ ] **PIN Management**: Changing a customer PIN scopes the query with `.eq('organization_id', orgId)`.
- [ ] **Credit Limits**: Credit calculations strictly aggregate the active tenant's leaf weights and advances.

### Scenario 3: Daily Tea Collection Entries (`lib/core/entries/`)
- [ ] **Daily Entries**: Entries store `organization_id`.
- [ ] **Dual Mode (Customer / Factory)**: Switching mode loads only that organization's customers or factories.
- [ ] **Calendar Aggregation**: Day totals only aggregate records from the current organization.
- [ ] **Factory Daily Collection & Allocation Summary**: When opening a factory entry for a specific date:
  - Aggregates all supplier leaf collections for that date (`netWeight` + `netWeight2`).
  - Isolates allocations to other factories on that date (excluding the current factory).
  - Calculates remaining available leaf for this factory (`Total Collected - Other Factories Allocation`).
  - Live Remaining / Over-Allocation balance indicator updates as user enters leaf weights.
  - Fully responsive across Android mobile (<620px), tablet (620-950px), and Windows desktop / web (>=950px).

### Scenario 4: Dynamic Custom Items (Up to 8 Items) (`lib/core/items/`)
- [ ] **Limit Enforcement**: Organizations cannot exceed 8 active custom items.
- [ ] **Double-Counting Prevention**: Dynamic items JSON parsing does not double-count legacy shadow columns.
- [ ] **Soft Deletion**: Deleting an item soft-deletes (`is_active = false`) so historical bills remain intact.

### Scenario 5: Monthly Billing & Closing (`lib/core/billing/`, `lib/features/reports/`)
- [ ] **Calculation**: Gross income, deductions, arrears, and net payable use tenant-specific monthly rates.
- [ ] **Finalized Bills**: Saved with `organization_id`.
- [ ] **Batch Insertion**: `monthly_closing_widget.dart` sets `organization_id` on all batched bills and summaries.

### Scenario 6: WhatsApp Invoicing (`lib/core/whatsapp/`, `whatsapp_server/`)
- [ ] **Server Process**: Managed by `WhatsAppService` on Windows desktop; cleanly killed on window close.
- [ ] **Socket Dispatch**: Invoices sent only for the active organization's finalized bills.

---

## 🔄 Protocol for Updating This Skill on New Features

Whenever a developer or AI agent implements a new feature, database table, or screen, they **MUST** update this QA skill as part of the PR/commit:

1. **Update the Tenant Scanner**:
   - If a new Supabase table is created, add the table name to `tenantScopedTables` in [`test/tenant_isolation_scanner_test.dart`](file:///test/tenant_isolation_scanner_test.dart).
2. **Add Unit/Widget Tests**:
   - Create a corresponding test file in `test/` (e.g., `test/my_feature_test.dart`) verifying business logic and tenant scoping.
3. **Add the Feature Test Scenario**:
   - Add a new `### Scenario X: [Feature Name]` section in this `SKILL.md` file with explicit QA acceptance criteria.
4. **Execute Full QA**:
   - Run `flutter.bat test` and `dart analyze lib test`.
   - Verify all tests pass before committing or merging.

---

## 📊 Pre-Commit QA Sign-Off Output Format

Output the QA verification results in this exact structure:

```markdown
### 🛡️ Smart Entry — Pre-Commit QA Sign-Off

#### 1. Multi-Tenant Organization Isolation: [PASS / FAIL]
- Scanned Supabase tables: [List of tables verified]
- Cross-tenant leakage check: [PASS / FAIL]

#### 2. Automated Test Suite: [PASS / FAIL]
- Total Tests: X | Passed: X | Failed: 0
- Scanner Test: `test/tenant_isolation_scanner_test.dart` [PASS]
- Tenant Isolation Test: `test/factory_tenant_isolation_test.dart` [PASS]
- Other Feature Tests: [PASS]

#### 3. Static Analysis & Sound Null Safety: [PASS / FAIL]
- Compile Errors: 0
- Deprecations / Warnings: [Clean / X warnings noted]

#### 4. Platform & Code Quality Checks: [PASS / FAIL]
- Android Screen Scope (Max 3 Screens): [PASS]
- Windows Platform Guards: [PASS]
- Numerical Input Formatters: [PASS]
- English Code Comments: [PASS]

#### 🚦 Sign-Off Decision: [READY TO MERGE / DO NOT MERGE]
```
