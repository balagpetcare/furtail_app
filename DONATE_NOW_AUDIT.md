# Donate Now Flow - Complete Audit Report

## Summary
The Donate Now flow shows a generic error "The fundraising service could not complete the request. Please try again." for all failures, masking the actual root cause. This prevents users from understanding why their donation failed or how to resolve it.

## Root Causes Found

### 1. Generic Error Catch-All (Backend)
**File**: `src/api/v1/modules/fundraising/fundraising.controller.ts:422-461`
**Issue**: The `donate` endpoint catches ALL errors and returns identical message regardless of failure type.

```typescript
catch (e) {
  if ((e as any)?.code === 'POLICY_DENIED' && (e as any)?.reasonCode) {
    return sendPolicyDenied(...);
  }
  // ❌ All other errors → generic message
  return sendFundraisingError(res, req, 'fundraising.donate', e, {
    statusCode: 500,
    code: 'FUNDRAISING_REQUEST_FAILED',
    message: 'The fundraising service could not complete the request. Please try again.',
  });
}
```

**Impact**: Errors from these scenarios all show the same message:
- Campaign not found (404)
- Campaign in wrong status (REJECTED/SUSPENDED/DRAFT/PENDING_REVIEW/etc)
- Campaign deleted
- Payment provider failure
- Network/timeout errors
- Database errors
- Any other exception

### 2. Incomplete Error Categorization (Frontend)
**File**: `lib/features/fundraising/presentation/controllers/fundraising_donation_checkout_controller.dart:328-369`
**Issue**: The `_mapFailure()` method doesn't distinguish between different error types.

Currently categorizes:
- ✅ Session expired (401)
- ✅ Network/timeout errors
- ✅ Validation errors (400)
- ❌ All other errors (500, 403, unknown) → `FundraisingDonationErrorType.paymentFailed` with raw error message

**Problem**: When API returns generic 500 error, Flutter shows raw error text without user-friendly mapping.

### 3. No Campaign Status Validation Before Payment
**File**: `src/api/v1/modules/fundraising/fundraising.payment.service.ts:281-296`
**Issue**: Campaign lookup doesn't distinguish why it wasn't found.

```typescript
const campaign = await prisma.fundraisingCampaign.findFirst({
  where: {
    id: campaignId,
    deletedAt: null,
    status: { in: ["ACTIVE", "FUNDED", "PAUSED"] }, // ← Only these statuses allowed
  },
});

if (!campaign) {
  const err = new Error("Campaign not found"); // ← Generic 404 for all cases
  (err as any).statusCode = 404;
  throw err;
}
```

**Allowed statuses for donations**: ACTIVE, FUNDED, PAUSED
**Blocked statuses**: DRAFT, PENDING_REVIEW, COMPLETED, EXPIRED, REJECTED, CANCELLED, SUSPENDED, ARCHIVED

When a campaign is in REJECTED/SUSPENDED state, donor gets generic 404.

## Flow Diagram

```
User taps "Donate Now"
  ↓
Checkout sheet: select amount + anonymous option + message
  ↓
User taps "Continue"
  ↓
Flutter calls: POST /api/v1/fundraising/campaigns/{id}/donate
  ├─ Body: { amount, currencyCode, returnUrl, cancelUrl }
  ├─ Headers: { Idempotency-Key: attemptId }
  ├─ Auth: Bearer token (user must be authenticated)
  ↓
API checks idempotency key (reuse if exists)
  ├─ If exists: return cached response ✅
  ├─ If new: proceed to create donation intent
  ↓
API validates campaign exists and is ACTIVE/FUNDED/PAUSED
  ├─ If not found or wrong status: throw 404 ❌ → generic error
  ├─ If deleted: throw 404 ❌ → generic error
  ├─ If REJECTED/SUSPENDED: throw 404 ❌ → generic error
  ↓
API creates donation intent (PENDING status)
  ↓
API calls createUnifiedPayment() to payment provider
  ├─ If fails: mark intent as FAILED, throw error ❌ → generic error
  ├─ If succeeds: return payment.redirectUrl ✅
  ↓
Flutter receives response with redirectUrl
  ↓
Flutter launches URL in external browser (payment provider UI)
  ↓
User completes payment in provider (e.g., bKash, Nagad)
  ↓
Provider redirects back to app with success/cancel/failure
  ↓
App polls: GET /api/v1/fundraising/campaigns/{id}/donations until confirmed
  ↓
Webhook from provider updates donation status
  ↓
App shows result: Success / Failed / Cancelled
```

## All Possible Failures

### Campaign-Related
1. **Campaign not found** (404)
   - Scenario: User tries to donate to non-existent campaign ID
   - Current message: "The fundraising service could not complete the request. Please try again."
   - Correct message: "Campaign not found. This fundraiser may have been removed."

2. **Campaign in wrong status** (404 - treated as not found)
   - Scenario: Campaign is DRAFT, PENDING_REVIEW, REJECTED, SUSPENDED, CANCELLED, ARCHIVED, etc.
   - Current message: "The fundraising service could not complete the request. Please try again."
   - Correct messages:
     - PENDING_REVIEW: "This fundraiser is under review. You can donate once it's approved."
     - REJECTED: "This fundraiser was rejected and cannot receive donations."
     - SUSPENDED: "This fundraiser has been suspended. Donations are not accepted."
     - ARCHIVED: "This fundraiser is no longer accepting donations."
     - DRAFT: "This fundraiser is not yet published."

3. **Campaign deleted** (404)
   - Scenario: Campaign has deletedAt timestamp set
   - Current message: "The fundraising service could not complete the request. Please try again."
   - Correct message: "Campaign not found. This fundraiser may have been removed."

### Payment-Related
1. **Payment provider failure** (varies)
   - Scenario: Payment provider API returns error
   - Current message: "The fundraising service could not complete the request. Please try again."
   - Correct message: "Payment provider error. Please try again or contact support."

2. **Invalid returnUrl/cancelUrl** (400)
   - Scenario: Malformed URLs sent by Flutter
   - Current message: "The fundraising service could not complete the request. Please try again."
   - Correct message: "Invalid payment configuration. Please contact support."

### Validation-Related
1. **Invalid amount** (400)
   - Scenario: amount <= 0, missing amount, negative amount
   - Current message: "The fundraising service could not complete the request. Please try again."
   - Correct message: "Please enter a valid amount to donate."

2. **Missing currency/campaign ID** (400)
   - Scenario: Incomplete request
   - Current message: "The fundraising service could not complete the request. Please try again."
   - Correct message: "Invalid donation request. Please try again."

### System Errors
1. **Database constraint violation** (varies)
2. **Payment service timeout** (varies)
3. **Concurrent idempotency key conflict** (rare)

## Required Fixes

### Priority 1: Backend Error Categorization (fundraising.payment.service.ts)

1. **Distinguish campaign not found from wrong status**
   ```typescript
   const campaign = await findCampaignForDonation(campaignId);
   if (!campaign.found) {
     throw createError(404, 'CAMPAIGN_NOT_FOUND', 'Campaign does not exist');
   }
   if (campaign.deleted) {
     throw createError(404, 'CAMPAIGN_DELETED', 'This campaign has been removed');
   }
   if (!campaign.isActive) {
     throw createError(400, `CAMPAIGN_STATUS_${campaign.status}`, 
       `Cannot donate to campaign in ${campaign.status} status`);
   }
   ```

2. **Specific error codes for each campaign status**
   - `CAMPAIGN_STATUS_REJECTED`
   - `CAMPAIGN_STATUS_SUSPENDED`
   - `CAMPAIGN_STATUS_PENDING_REVIEW`
   - `CAMPAIGN_STATUS_DRAFT`
   - `CAMPAIGN_STATUS_ARCHIVED`
   - `CAMPAIGN_STATUS_COMPLETED`
   - etc.

### Priority 2: Backend Error Handler (fundraising.controller.ts)

Map specific error codes to user-facing messages:
```typescript
const errorMessages = {
  'CAMPAIGN_NOT_FOUND': 'Campaign not found',
  'CAMPAIGN_DELETED': 'This fundraiser has been removed',
  'CAMPAIGN_STATUS_REJECTED': 'This fundraiser was rejected',
  'CAMPAIGN_STATUS_SUSPENDED': 'This fundraiser is suspended',
  'CAMPAIGN_STATUS_PENDING_REVIEW': 'This fundraiser is under review',
  'PAYMENT_CREATE_FAILED': 'Payment provider error',
  'INVALID_RETURN_URL': 'Invalid payment configuration',
  // ... etc
};

catch (e) {
  const msg = errorMessages[e.code] || e.message || DEFAULT_MESSAGE;
  return sendFundraisingError(res, req, 'fundraising.donate', e, {
    statusCode: e.statusCode || 500,
    code: e.code || 'UNKNOWN_ERROR',
    message: msg,
  });
}
```

### Priority 3: Frontend Error Mapping (fundraising_donation_checkout_controller.dart)

Enhance `_mapFailure()` to handle all status codes and provide user-friendly messages:
```dart
FundraisingDonationFailure _mapFailure(Object error) {
  if (error is ApiClientException) {
    // Handle specific error codes
    if (error.code == 'CAMPAIGN_NOT_FOUND') {
      return FundraisingDonationFailure(
        type: FundraisingDonationErrorType.validation,
        message: 'This fundraiser no longer exists.',
      );
    }
    if (error.code?.startsWith('CAMPAIGN_STATUS_') ?? false) {
      if (error.code == 'CAMPAIGN_STATUS_REJECTED') {
        return FundraisingDonationFailure(
          type: FundraisingDonationErrorType.validation,
          message: 'This fundraiser was rejected and cannot receive donations.',
        );
      }
      // ... handle other statuses
    }
    // ... handle other codes
  }
  // ... existing logic
}
```

### Priority 4: Tests

Add test cases for:
- [ ] Donation to non-existent campaign
- [ ] Donation to campaign in each invalid status (REJECTED, SUSPENDED, DRAFT, etc.)
- [ ] Donation to deleted campaign
- [ ] Payment provider errors
- [ ] Invalid amount validation
- [ ] Concurrent requests with same idempotency key
- [ ] Session expired during checkout

## Success Criteria

### Backend
- ✅ Campaign-not-found errors return 404 with `CAMPAIGN_NOT_FOUND` code
- ✅ Campaign-wrong-status errors return 400 with `CAMPAIGN_STATUS_*` code
- ✅ Payment provider errors return specific code (not generic)
- ✅ Validation errors (bad amount) return 400 with validation code
- ✅ Each error code maps to user-facing message

### Frontend
- ✅ Campaign not found: "This fundraiser no longer exists."
- ✅ Campaign rejected: "This fundraiser was rejected and cannot receive donations."
- ✅ Campaign suspended: "This fundraiser is suspended."
- ✅ Campaign pending review: "This fundraiser is under review. You can donate once it's approved."
- ✅ Payment provider error: Shows specific provider message or "Payment failed. Please try again."
- ✅ Network error: "Please check your connection and try again."
- ✅ Session expired: "Your session has expired. Please sign in again."
- ✅ Amount validation: "Please enter a valid amount to donate."
- ✅ No raw technical error messages shown

### User Experience
- ✅ User understands why donation failed
- ✅ User knows if they can retry or if campaign is permanently blocked
- ✅ User sees specific, actionable messages
- ✅ Never shows: "The fundraising service could not complete the request. Please try again."

## Key Design Decisions

1. **Status 400 for blocked campaigns**: Use 400 (validation/policy) not 404 (not found) when campaign exists but is in wrong status. This helps client distinguish "campaign doesn't exist" (404) from "campaign exists but blocked" (400).

2. **Idempotency by Idempotency-Key header**: Flutter sends stable `attemptId` in header. If request is retried with same key, return cached response. Prevents duplicate donations if network fails after payment succeeds.

3. **No creator account status checks for donations**: Do NOT block donations based on fundraiser creator's verification status. Creator can receive donations even if PENDING_REVIEW or PENDING. (Payout requires VERIFIED, but receiving donations does not.)

4. **Campaign must be published**: Campaign must be in ACTIVE/FUNDED/PAUSED (i.e., published by admin) to receive donations. Not even PENDING_REVIEW campaigns can receive donations.

5. **Safe error messages**: All user-facing messages in Flutter must be pre-defined, not raw backend error text. Use mapping tables to convert error codes to messages.
