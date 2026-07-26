# Fundraiser Creation Flow - Audit Findings

## Root Cause: "Verification unavailable" After Submit

**Issue**: After attempting to submit, users see generic "Verification unavailable" error instead of specific issues.

**Root Cause**: 
- The preflight error handler in `fundraising_create_screen.dart:_preflightErrorTitle()` maps ALL non-network/session/parse errors to "Verification unavailable"
- This includes 500 server errors, 403 forbidden, 400 validation, and unknown errors
- When an account is PENDING_REVIEW with incomplete profile, the API returns a proper 400 validation error, but it's masked

**Affected Flow**:
1. User taps "Submit for review" in FundraisingCreateScreen
2. Preflight check fetches fundraisingMyAccountProvider
3. If account missing or incomplete, API returns validation error
4. Error is categorized as FundraisingErrorCategory.validation
5. UI shows "Verification unavailable" instead of specific field error

## Policy Issues Found

### Flutter Account Readiness (fundraising_models.dart:609-614)
```dart
bool get canStartFundraiser =>
    requiredProfileComplete &&
    requiredDocumentsUploaded &&
    statusNotRejectedOrBlocked;
```

**Problems**:
- ✅ Correctly checks profile and documents
- ❌ Missing DISABLED, INACTIVE, EXPIRED statuses (only checks REJECTED/SUSPENDED/BLOCKED)
- ❌ Doesn't distinguish between missing account vs. incomplete profile vs. restricted account

### API Account Eligibility (fundraising.service.ts:70-77)
```typescript
function isCampaignSubmissionEligibleAccountStatus(value: unknown) {
  const status = normalizeFundraisingAccountStatus(value);
  return ["DRAFT", "PENDING", "PENDING_REVIEW", "VERIFIED"].includes(status);
}
```

**Status**:
- ✅ Correctly allows DRAFT, PENDING, PENDING_REVIEW, VERIFIED
- ✅ Correctly denies REJECTED, SUSPENDED, BLOCKED via assertCampaignSubmissionEligibleAccount()
- ⚠️ Missing DISABLED and other restricted statuses

## Specific Issues

### 1. Overly Broad Error Categorization
- Network errors → "Unable to connect" ✅
- Session expired → "Session expired" ✅
- Parse failures → "We couldn't read the response" ✅
- **Validation (400) → "Verification unavailable" ❌**
- **Server (500) → "Verification unavailable" ❌**
- **Forbidden (403) → "Verification unavailable" ❌**
- **Unknown → "Verification unavailable" ❌**

### 2. Missing Account States Not Distinguished
When account fetch returns null, the UI should show:
- "Create an account" if no account exists
- "Complete your profile" if account incomplete
- "Your account is restricted" if status is REJECTED/SUSPENDED/BLOCKED/DISABLED

Currently, all these show the same generic verification setup screen.

### 3. Payout Method Requirements
- ❌ Code may be requiring payout method for submission
- ✅ API does not require it (only for withdrawal)
- Fix: Remove all payout method checks from campaign creation/submission

### 4. Duplicate Submit Prevention
- ✅ `_isSubmitting` flag exists
- ⚠️ Must ensure it's reset in finally block
- ⚠️ Must ensure auth state failures don't leave flag stuck

### 5. Date Serialization
- ✅ Already fixed in previous task using UTC ISO-8601
- Verified: `FundraisingDateSerializer.serializeToUtcIso8601()`

## Required Fixes

1. **Improve error categorization** → Distinguish validation from unknown errors
2. **Add specific error messages** → Show which field is missing (profile/docs)
3. **Separate account states** → No account vs. incomplete vs. restricted
4. **Fix Flutter readiness** → Add DISABLED, INACTIVE, EXPIRED checks
5. **Remove payout checks** → Never require payout for campaign submission
6. **Ensure duplicate prevention** → Reset flags in finally blocks
7. **Add focused tests** → Verify each error path and account state

## Success Criteria

- ✅ PENDING_REVIEW account with complete profile/docs submits successfully
- ✅ Incomplete PENDING_REVIEW account shows specific missing field
- ✅ REJECTED account shows rejection reason
- ✅ Network failure shows "Unable to connect" with Retry
- ✅ No "Verification unavailable" for valid PENDING accounts
- ✅ Submit creates PENDING_REVIEW once (no duplicates)
- ✅ Payout method never required
- ✅ All dates in UTC ISO-8601
