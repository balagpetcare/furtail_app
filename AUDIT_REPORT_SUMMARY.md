# Fundraiser Creation Flow - Complete Audit Report

## 1. ROOT CAUSE: "Verification unavailable" After Submit

**Exact Cause**: 
- Located: `lib/features/fundraising/presentation/screens/fundraising_create_screen.dart:_preflightErrorTitle()`
- Issue: All non-network/session/parse errors are mapped to "Verification unavailable"
- When account fetch fails with validation 400, it's categorized as `FundraisingErrorCategory.validation` 
- The switch statement treats validation as unknown → shows generic "Verification unavailable"
- Should instead show specific error like "Profile incomplete: Missing date of birth"

**Impact**: 
- PENDING_REVIEW users with incomplete profiles see generic error instead of specific missing field
- Cannot distinguish between "Account doesn't exist" vs "Profile incomplete" vs "Account restricted"

## 2. Files Changed (Required Fixes)

### Flutter App
- `lib/features/fundraising/presentation/screens/fundraising_create_screen.dart` - Error categorization
- `lib/features/fundraising/data/models/fundraising_models.dart` - Account readiness policy
- `lib/features/fundraising/data/fundraising_error_mapper.dart` - Error type classification
- `lib/features/fundraising/presentation/controllers/fundraising_create_wizard_controller.dart` - Submit flow
- `test/features/fundraising/...` - Targeted tests

### API Backend
- `src/api/v1/modules/fundraising/fundraising.service.ts` - Account status validation
- `src/api/v1/modules/fundraising/fundraising.errors.ts` - Error codes

## 3. Account Readiness Policy (Canonical Rule)

**Allowed Account Statuses for Campaign Creation/Submission**:
- DRAFT ✅ (no account, create form shown)
- PENDING ✅ (account incomplete, user can still submit once profile/docs complete)
- PENDING_REVIEW ✅ (account under review, user can create/submit if profile/docs complete)
- VERIFIED ✅ (account approved)

**Denied Account Statuses**:
- REJECTED ❌ (account was rejected; show rejection reason + require reapplication)
- SUSPENDED ❌ (account suspended by admin; show suspension reason)
- BLOCKED ❌ (account blocked; show reason)
- DISABLED ❌ (account disabled; show reason)
- INACTIVE ❌ (account inactive; show reason)
- EXPIRED ❌ (account verification expired; require renewal)

**Required for Submission**:
- ✅ Complete profile (present address, permanent address, DOB, location)
- ✅ Verified document upload (primary ID)
- ❌ Payout method (NOT required - only for withdrawal)
- ❌ VERIFIED status (NOT required - PENDING_REVIEW can submit)

## 4. Submission Flow Fixes

### Problem 1: Error Message Too Generic
**Before**: All validation/server/forbidden errors → "Verification unavailable"
**After**: 
- Validation (400) → Show field-specific error from API
- Server (500) → "Service temporarily unavailable" with Retry
- Forbidden (403) → "Your account is restricted" or specific restriction reason
- Network → "Unable to connect" with Retry
- Session expired → "Your session expired" with Sign In button

### Problem 2: No Duplicate Submit Prevention
**Before**: Flag exists but may not reset properly if error occurs
**After**: Ensure `_isSubmitting` always resets in `finally` block

### Problem 3: Incomplete Account State Handling  
**Before**: Null account and incomplete account both trigger same "setup" flow
**After**:
- No account exists → Show "Create account" form
- Account exists but incomplete → Show "Complete profile" form with missing fields highlighted
- Account restricted → Show restriction message with reason

## 5. Typed Errors (Backend Response)

### New Error Codes
```typescript
// For validation errors (400)
FUNDRAISING_DATETIME_INVALID: "End date is invalid"
FUNDRAISING_PROFILE_INCOMPLETE: "Complete profile before submitting" 
  (details.missingFields: ["dateOfBirth", "presentAddress"])
FUNDRAISING_ACCOUNT_RESTRICTED: "Your account is restricted"
  (details.reason: "REJECTED|SUSPENDED|BLOCKED|DISABLED")
FUNDRAISING_MEDIA_INVALID: "Media validation failed"
  (details.invalidMediaIds: [123, 456])
```

### Safe Field Messages (Never expose raw errors)
❌ "PrismaClientKnownRequestError in models/fundraising.ts line 427"
❌ "SQL query error: SELECT * FROM..."
❌ "TypeError: Cannot read property status of undefined"
✅ "Profile incomplete: Missing date of birth"
✅ "Your account is restricted. Contact support for more information."

## 6. Submission Behavior

### One-Time Fundraiser
```
Valid requirements:
✅ title, caption, category
✅ targetAmountMinor > 0
✅ endsAt: valid future date in UTC ISO-8601
✅ fundingMode = "ONE_TIME"
✅ location specified
✅ media IDs valid and ready
✅ account status in [DRAFT, PENDING, PENDING_REVIEW, VERIFIED]
✅ profile complete + primary document uploaded

Response:
- Status 201 ✅
- Campaign.status = "PENDING_REVIEW"
- Never "ACTIVE"
- Idempotency key prevents duplicates
```

### Ongoing Fundraiser
```
Valid requirements:
✅ title, caption, category
✅ endsAt = null
✅ monthlyGoalMinor optional
✅ nextReviewAt optional (calculated if omitted)
✅ fundingMode = "ONGOING"
✅ All other same as ONE_TIME

Response:
- Status 201 ✅
- Campaign.status = "PENDING_REVIEW"
```

## 7. Test Coverage Required

### Flutter Tests
- [ ] Missing account redirects to verification setup
- [ ] PENDING account with complete profile/docs submits successfully
- [ ] PENDING_REVIEW account with incomplete profile shows specific error
- [ ] VERIFIED account submits successfully
- [ ] REJECTED account shows rejection reason
- [ ] SUSPENDED/BLOCKED account denied
- [ ] Payout method NOT required
- [ ] Valid ONE_TIME dates submit once
- [ ] Valid ONGOING dates (endsAt=null) submit once
- [ ] Network failure shows Retry button
- [ ] Server error (500) shows Retry
- [ ] No raw technical errors shown to user
- [ ] Duplicate Submit taps → only one request

### API Tests
- [ ] Account status validation
- [ ] Profile completeness check
- [ ] Document validation
- [ ] Date range validation (endsAt > now)
- [ ] Media ID validation
- [ ] Idempotency enforcement
- [ ] Campaign status always PENDING_REVIEW on create
- [ ] No payout method required
- [ ] PENDING_REVIEW account can submit

## 8. Implementation Checklist

### Phase 1: Error Handling
- [ ] Improve error categorization (distinguish validation from unknown)
- [ ] Add specific field error messages
- [ ] Update preflight error UI

### Phase 2: Account Policy
- [ ] Add DISABLED/INACTIVE/EXPIRED status checks
- [ ] Separate account states (none vs incomplete vs restricted)
- [ ] Show specific missing fields in verification setup

### Phase 3: Submission Flow
- [ ] Remove payout method requirements
- [ ] Ensure `_isSubmitting` flag resets properly
- [ ] Verify date serialization (UTC ISO-8601)
- [ ] Implement idempotency checking

### Phase 4: Testing
- [ ] Add Flutter targeted tests
- [ ] Add API validation tests
- [ ] Verify each error path
- [ ] Verify each account state

## 9. Success Validation

- ✅ No "Verification unavailable" for valid PENDING_REVIEW accounts
- ✅ Specific error for each missing profile field
- ✅ Network errors show Retry button
- ✅ Submit creates PENDING_REVIEW exactly once
- ✅ No technical errors exposed
- ✅ Payout method never blocks submission
- ✅ All dates in UTC ISO-8601
