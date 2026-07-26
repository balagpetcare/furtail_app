# Donate Now Flow - Fixes Summary

## Problem Statement
Users saw a generic error message "The fundraising service could not complete the request. Please try again." for all donation failures, regardless of the actual cause. This prevented users from understanding why their donation failed or how to resolve the issue.

## Root Causes Identified
1. **Backend**: Generic catch-all error handler returned same message for all failures
2. **Backend**: Campaign lookup didn't distinguish between "not found" and "wrong status"
3. **Frontend**: Error categorization didn't map specific error codes to user-friendly messages

## Fixes Implemented

### Backend Fixes

#### 1. Specific Error Codes (fundraising.payment.service.ts)

**File**: `src/api/v1/modules/fundraising/fundraising.payment.service.ts`

**Changes**:
- Added error code to validation errors: `DONATION_VALIDATION_FAILED`
- Added error code to redirect URL errors: `INVALID_REDIRECT_URL`
- Added error code to payment provider errors: `PAYMENT_PROVIDER_ERROR`
- Separated campaign-not-found from campaign-wrong-status errors:
  - `CAMPAIGN_NOT_FOUND` (404): Campaign doesn't exist
  - `CAMPAIGN_DELETED` (404): Campaign exists but has been deleted
  - `CAMPAIGN_STATUS_*` (400): Campaign exists but in non-donatable status (e.g., REJECTED, SUSPENDED, PENDING_REVIEW, etc.)

**Code Changes**:
```typescript
// Before: Generic 404 for all cases
if (!campaign) {
  const err = new Error("Campaign not found");
  (err as any).statusCode = 404;
  throw err;
}

// After: Specific error codes
const rawCampaign = await prisma.fundraisingCampaign.findUnique({...});
if (rawCampaign?.deletedAt) {
  const err = new Error("This fundraiser has been removed");
  (err as any).statusCode = 404;
  (err as any).code = "CAMPAIGN_DELETED";
  throw err;
}
if (rawCampaign && !["ACTIVE", "FUNDED", "PAUSED"].includes(rawCampaign.status)) {
  const err = new Error(`Campaign status is ${rawCampaign.status}`);
  (err as any).statusCode = 400;
  (err as any).code = `CAMPAIGN_STATUS_${rawCampaign.status}`;
  throw err;
}
if (!rawCampaign) {
  const err = new Error("Campaign not found");
  (err as any).statusCode = 404;
  (err as any).code = "CAMPAIGN_NOT_FOUND";
  throw err;
}
```

#### 2. Error Code Mapping (fundraising.controller.ts)

**File**: `src/api/v1/modules/fundraising/fundraising.controller.ts`

**Changes**:
- Replaced generic error handler with specific error code mapping
- Maps each error code to a user-friendly message
- Preserves error codes in API response

**Code Changes**:
```typescript
// Before: One generic message for all errors
catch (e) {
  return sendFundraisingError(res, req, 'fundraising.donate', e, {
    statusCode: 500,
    code: 'FUNDRAISING_REQUEST_FAILED',
    message: 'The fundraising service could not complete the request. Please try again.',
  });
}

// After: Specific messages for each error code
catch (e) {
  const errorCode = (e as any)?.code;
  const statusCode = (e as any)?.statusCode || 500;
  
  const errorMessages: Record<string, string> = {
    'CAMPAIGN_NOT_FOUND': 'Campaign not found',
    'CAMPAIGN_DELETED': 'This fundraiser has been removed',
    'CAMPAIGN_STATUS_DRAFT': 'This fundraiser has not been published yet',
    'CAMPAIGN_STATUS_PENDING_REVIEW': 'This fundraiser is under review. You can donate once it is approved',
    // ... etc for all statuses
    'PAYMENT_PROVIDER_ERROR': 'Payment provider error. Please try again',
    'DONATION_VALIDATION_FAILED': 'Please enter a valid donation amount',
  };
  
  const userMessage = errorMessages[errorCode] || ...;
  return sendFundraisingError(res, req, 'fundraising.donate', e, {
    statusCode,
    code: errorCode || 'FUNDRAISING_DONATION_FAILED',
    message: userMessage,
  });
}
```

### Frontend Fixes

#### Error Code Mapping (fundraising_donation_checkout_controller.dart)

**File**: `lib/features/fundraising/presentation/controllers/fundraising_donation_checkout_controller.dart`

**Changes**:
- Enhanced `_mapFailure()` method to handle specific error codes
- Maps backend error codes to predefined user-friendly messages
- Never shows raw technical error text

**Code Changes**:
```dart
// Added error code mapping table
final errorMessages = <String, String>{
  'CAMPAIGN_NOT_FOUND': 'This fundraiser does not exist.',
  'CAMPAIGN_DELETED': 'This fundraiser has been removed.',
  'CAMPAIGN_STATUS_DRAFT': 'This fundraiser has not been published yet.',
  'CAMPAIGN_STATUS_PENDING_REVIEW': 'This fundraiser is under review. You can donate once it is approved.',
  'CAMPAIGN_STATUS_COMPLETED': 'This fundraiser has been completed.',
  'CAMPAIGN_STATUS_EXPIRED': 'This fundraiser has expired.',
  'CAMPAIGN_STATUS_REJECTED': 'This fundraiser was rejected and cannot receive donations.',
  'CAMPAIGN_STATUS_CANCELLED': 'This fundraiser has been cancelled.',
  'CAMPAIGN_STATUS_SUSPENDED': 'This fundraiser is suspended.',
  'CAMPAIGN_STATUS_ARCHIVED': 'This fundraiser is archived.',
  'PAYMENT_PROVIDER_ERROR': 'Payment provider error. Please try again.',
  'DONATION_VALIDATION_FAILED': 'Please enter a valid donation amount.',
};

// Check for mapped error codes
if (error.code != null && errorMessages.containsKey(error.code)) {
  return FundraisingDonationFailure(
    type: FundraisingDonationErrorType.validation,
    code: error.code,
    message: errorMessages[error.code]!,
  );
}
```

## Error Code Reference

### Campaign-Related Errors
| Code | HTTP Status | User Message |
|------|-------------|--------------|
| `CAMPAIGN_NOT_FOUND` | 404 | This fundraiser does not exist. |
| `CAMPAIGN_DELETED` | 404 | This fundraiser has been removed. |
| `CAMPAIGN_STATUS_DRAFT` | 400 | This fundraiser has not been published yet. |
| `CAMPAIGN_STATUS_PENDING_REVIEW` | 400 | This fundraiser is under review. You can donate once it is approved. |
| `CAMPAIGN_STATUS_COMPLETED` | 400 | This fundraiser has been completed. |
| `CAMPAIGN_STATUS_EXPIRED` | 400 | This fundraiser has expired. |
| `CAMPAIGN_STATUS_REJECTED` | 400 | This fundraiser was rejected and cannot receive donations. |
| `CAMPAIGN_STATUS_CANCELLED` | 400 | This fundraiser has been cancelled. |
| `CAMPAIGN_STATUS_SUSPENDED` | 400 | This fundraiser is suspended. |
| `CAMPAIGN_STATUS_ARCHIVED` | 400 | This fundraiser is archived. |

### Validation Errors
| Code | HTTP Status | User Message |
|------|-------------|--------------|
| `DONATION_VALIDATION_FAILED` | 400 | Please enter a valid donation amount. |
| `INVALID_REDIRECT_URL` | 400 | Payment configuration error. Please contact support. |

### Payment Errors
| Code | HTTP Status | User Message |
|------|-------------|--------------|
| `PAYMENT_PROVIDER_ERROR` | 400 | Payment provider error. Please try again. |

### Existing Session/Network Errors (unchanged)
| Type | HTTP Status | User Message |
|------|-------------|--------------|
| Session Expired | 401 | Your session has expired. Please sign in again. |
| Network Error | 0 | Please check your connection and try the payment again. |
| Timeout | 0 | The payment request timed out. Please try again. |

## Data Flow

### Error Code Path
1. **Backend throws error** with `statusCode` and `code` properties
2. **sendFundraisingError()** extracts code from error object
3. **toSafeFundraisingErrorResponse()** preserves code in response
4. **API Response** includes `{ success: false, code: "...", message: "..." }`
5. **Flutter ApiClient** extracts code via `_codeFromDecoded()`
6. **ApiClientException** is created with `code` field populated
7. **_mapFailure()** looks up code in errorMessages map
8. **User sees** mapped message in snackbar

## Testing Strategy

### Unit Tests
- Test each error code maps to correct message
- Test fallback for unmapped error codes
- Test null/empty code handling

### Integration Tests
- Donate to non-existent campaign → CAMPAIGN_NOT_FOUND → "This fundraiser does not exist."
- Donate to deleted campaign → CAMPAIGN_DELETED → "This fundraiser has been removed."
- Donate to REJECTED campaign → CAMPAIGN_STATUS_REJECTED → "This fundraiser was rejected..."
- Donate to SUSPENDED campaign → CAMPAIGN_STATUS_SUSPENDED → "This fundraiser is suspended."
- Donate to PENDING_REVIEW campaign → CAMPAIGN_STATUS_PENDING_REVIEW → "This fundraiser is under review..."
- Payment provider fails → PAYMENT_PROVIDER_ERROR → "Payment provider error. Please try again."
- Session expired → 401 → "Your session has expired. Please sign in again."
- Network error → Network error → "Please check your connection..."

## Validation Checklist

- [x] Backend distinguishes campaign-not-found from campaign-wrong-status
- [x] Backend sets specific error code for each failure scenario
- [x] Backend error handler maps codes to user-friendly messages
- [x] API response includes error code field
- [x] Flutter receives and parses error code
- [x] Flutter maps error code to message
- [x] No raw technical error messages shown
- [x] flutter analyze passes with no errors
- [x] Error messages are specific and actionable
- [x] Users can understand why donation failed
- [x] Messages guide user to resolution (retry, contact support, etc.)

## Success Metrics

### Before Fix
- All donation failures → "The fundraising service could not complete the request. Please try again."
- User confusion about cause and remedy
- No way to distinguish between network error vs. campaign restriction

### After Fix
- Network error → "Please check your connection and try the payment again."
- Campaign doesn't exist → "This fundraiser does not exist."
- Campaign rejected → "This fundraiser was rejected and cannot receive donations."
- Campaign suspended → "This fundraiser is suspended."
- Campaign under review → "This fundraiser is under review. You can donate once it is approved."
- Payment provider error → "Payment provider error. Please try again."
- Clear user understanding of issue and next steps

## Files Modified

### Backend
1. `src/api/v1/modules/fundraising/fundraising.payment.service.ts`
   - Added specific error codes to all failure paths
   - Separated campaign-not-found from wrong-status

2. `src/api/v1/modules/fundraising/fundraising.controller.ts`
   - Replaced generic error handler with specific error code mapping
   - Maps each code to user-friendly message

### Frontend
1. `lib/features/fundraising/presentation/controllers/fundraising_donation_checkout_controller.dart`
   - Enhanced error categorization with specific error code mapping
   - Added error message lookup table
   - Handles fallback for unmapped codes

## Notes
- Error codes flow through: Backend → API Response → Flutter ApiClient → _mapFailure() → User Message
- Error messages are pre-defined and never expose raw technical details
- Idempotency key prevents duplicate donations on network retry
- Campaign must be in ACTIVE/FUNDED/PAUSED status to receive donations
- No creator account status checks block donations (only affects withdrawal eligibility)
