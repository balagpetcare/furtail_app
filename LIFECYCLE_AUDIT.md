# Fundraising Lifecycle - Systematic Audit

## Lifecycle Steps Analysis

### Step 1: User Opens Fundraisers
**Files**: `fundraising_feed_screen.dart`, `fundraising_providers.dart`
- [ ] Check providers correctly invalidate after profile/verification update
- [ ] Check empty state when no campaigns exist
- [ ] Check loading state during feed fetch

### Step 2: User Taps Create Fundraiser
**Files**: `fundraising_create_screen.dart`, `fundraising_create_wizard_controller.dart`
- [ ] Check account readiness is fetched
- [ ] Check verification setup shown if needed
- [ ] Check draft loaded if exists

### Step 3: Missing Account Opens Verification Setup
**Files**: `fundraising_verification_setup_screen.dart`
- [ ] Check profile form validation
- [ ] Check document upload handling
- [ ] Check submission endpoint

### Step 4: Profile + Document Complete Enables Creation
**Files**: `fundraising_models.dart` (canStartFundraiser check)
- [ ] Check profile completeness logic
- [ ] Check document validation
- [ ] Check status eligibility (PENDING/VERIFIED, not REJECTED)

### Step 5: User Creates Three-Step Fundraiser
**Files**: `fundraising_create_wizard_controller.dart`
- [ ] Check form validation
- [ ] Check date serialization (UTC ISO-8601)
- [ ] Check campaign creation endpoint
- [ ] Check response parsing

### Step 6: Media Uploads and Processes
**Files**: `fundraising_media_upload_controller.dart`
- [ ] Check upload idempotency
- [ ] Check media processing status
- [ ] Check stored media ID references

### Step 7: Draft Saves Locally and Server
**Files**: `fundraising_create_wizard_controller.dart`
- [ ] Check local draft persistence
- [ ] Check server save endpoint
- [ ] Check idempotency key usage
- [ ] Check response status

### Step 8: Submit Creates PENDING_REVIEW
**Files**: `fundraising_create_screen.dart`
- [ ] Check submission endpoint
- [ ] Check campaign status is PENDING_REVIEW (never ACTIVE)
- [ ] Check duplicate prevention
- [ ] Check error handling

### Step 9: Approved Campaign Appears Publicly
**Files**: Backend admin approval flow
- [ ] Check campaign status updates to ACTIVE
- [ ] Check feed cache invalidation
- [ ] Check public access

### Step 10: Donor Opens Donate Now
**Files**: `fundraising_details_screen.dart`, `fundraising_donation_checkout_controller.dart`
- [ ] Check campaign is ACTIVE/FUNDED/PAUSED
- [ ] Check payment intent creation
- [ ] Check provider redirect
- [ ] Check idempotency key

### Step 11: Donation Updates After Verified Payment
**Files**: `fundraising_payment_webhook_handler.ts`
- [ ] Check webhook signature verification
- [ ] Check donation credit only after SUCCEEDED status
- [ ] Check no duplicate credits
- [ ] Check stats update

### Step 12: Creator Sees Pending/Available Balance
**Files**: `fundraising_balance_screen.dart`
- [ ] Check pending donations calculation
- [ ] Check available balance
- [ ] Check currency formatting

### Step 13: Withdrawal Requires VERIFIED Account + Payout
**Files**: `fundraising_withdraw_screen.dart`
- [ ] Check account must be VERIFIED (not PENDING/REJECTED)
- [ ] Check payout method required
- [ ] Check minimum balance

### Step 14: Restricted Account/Campaign Actions Blocked
**Files**: Various
- [ ] Check REJECTED account cannot submit
- [ ] Check SUSPENDED campaign cannot receive donations
- [ ] Check safe error messages

## Check Items

### 1. Flutter/API Readiness Mismatch
- Account statuses in Flutter vs Prisma schema
- Campaign statuses handling
- Media processing states

### 2. Missing Prisma Migrations
- All schema updates applied
- No pending migrations

### 3. Stale Providers After Updates
- Profile updates invalidate readiness provider
- Document uploads invalidate readiness provider
- Campaign submission invalidates draft provider
- Approval invalidates feed provider

### 4. Duplicate Prevention
- Idempotency keys for draft creation
- Idempotency keys for submission
- Webhook deduplication for donations

### 5. Media Uploads
- Media ID stored correctly
- No orphaned media
- File type validation

### 6. Date Serialization
- All dates sent to API as UTC ISO-8601
- No "Invalid ISO datetime" errors

### 7. Campaign ID Handling
- Public ID vs internal ID clarity
- ID used correctly in all endpoints
- Correct ID in URL parameters

### 8. Error Messages
- No raw technical errors shown
- User-friendly campaign status messages
- User-friendly payment error messages

### 9. Loading/Empty/Retry States
- Loading spinners during async operations
- Empty states when no data
- Retry buttons on failure
- Proper state cleanup on disposal

### 10. Financial Fields
- No client-trusted amounts
- All calculations server-side
- Proper formatting for display

### 11. Payout Checks
- NOT required during campaign creation
- NOT required during submission
- REQUIRED during withdrawal
- VERIFIED account required for withdrawal

### 12. Verification Blocking
- PENDING account CAN submit (if profile/docs complete)
- VERIFIED account can submit
- Only REJECTED blocks submission
- Does NOT block donations to creator

### 13. Checkout Dependencies
- Donation checkout does NOT depend on creator payout
- Donation checkout does NOT depend on creator verification
- Donation checkout requires ACTIVE/FUNDED/PAUSED campaign

