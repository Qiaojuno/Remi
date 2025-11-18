# Production Deployment Guide

This guide covers the steps needed to prepare the Halloo app for App Store release, with a focus on subscription service configuration.

---

## Pre-Release Checklist

### 1. RevenueCat API Key Configuration

**CRITICAL**: The app currently uses a Test Store API key that must be replaced before production deployment.

#### Current Setup
- **Development/Debug builds**: Automatically use Test Store key (`test_JxDSDtqZjJxdAqlujuzvhPtVHSO`)
- **Production/Release builds**: Placeholder key that MUST be replaced

#### Steps to Configure Production Key

1. **Get Production API Key**
   - Log into [RevenueCat Dashboard](https://app.revenuecat.com)
   - Navigate to your project
   - Go to **Settings → API Keys → Apple App Store**
   - Copy your production API key (starts with `appl_` or similar)

2. **Update App.swift**
   - Open `Halloo/Core/App.swift`
   - Find the `configureRevenueCat()` method (around line 99)
   - Replace `"YOUR_PRODUCTION_KEY_HERE"` with your actual production key:

   ```swift
   #else
   // Production key for App Store release
   return "appl_YOUR_ACTUAL_PRODUCTION_KEY"  // ← Replace this
   #endif
   ```

3. **Verify Configuration**
   - The app will crash in Release mode if you forget to replace the key
   - This is intentional to prevent accidental Test Store deployment

#### Important Notes

⚠️ **NEVER** submit an app to the App Store with a Test Store API key
⚠️ **NEVER** commit production API keys to public repositories
✅ Test Store keys are safe for development and can be committed

---

### 2. Superwall API Key Configuration

Superwall allows using the same API key for both development and production environments.

#### Current Setup
- **Development**: `pk_1FZVcGgpr1JMD5XJ4d0Cb`
- **Production**: Currently set to same key (update if needed)

#### Steps to Configure (If Using Separate Keys)

1. **Get Production API Key** (if applicable)
   - Log into [Superwall Dashboard](https://superwall.com/dashboard)
   - Go to **Settings → API Keys**
   - Copy your production key if you have separate environments

2. **Update App.swift** (if needed)
   - Open `Halloo/Core/App.swift`
   - Find the `configureSuperwall()` method (around line 138)
   - Update production key if using separate environments:

   ```swift
   #else
   return "pk_YOUR_PRODUCTION_KEY"  // ← Update if needed
   #endif
   ```

#### Important Notes

✅ Using the same Superwall key for dev and prod is common and acceptable
✅ Paywalls and experiments are configured per environment in Superwall Dashboard

---

### 3. Build Configuration Verification

The app automatically detects build configuration:

- **Debug builds** (Xcode Run, Simulator):
  - Use Test Store keys
  - Print "TEST STORE MODE" in logs
  - Safe for development and testing

- **Release builds** (Archive, App Store):
  - Use Production keys
  - Print "PRODUCTION MODE" in logs
  - Require valid production keys

#### Test Build Configuration

```bash
# Build for Debug (uses Test Store)
xcodebuild -scheme Halloo -configuration Debug

# Build for Release (uses Production - will crash if keys not set)
xcodebuild -scheme Halloo -configuration Release
```

---

### 4. RevenueCat Dashboard Setup

Before releasing to production:

1. **Connect App Store**
   - RevenueCat Dashboard → Project Settings
   - Connect to App Store Connect
   - Configure bundle ID and shared secret

2. **Configure Products**
   - Create products matching your App Store Connect setup
   - Recommended: `monthly` and `yearly` subscription products

3. **Configure Entitlements**
   - Create entitlement: `"Remi Unlimited"`
   - Attach to your subscription products
   - This matches the entitlement ID used in code

4. **Set Up Offerings**
   - Create default offering
   - Add packages (e.g., `$rc_monthly`, `$rc_annual`)
   - Publish offering

---

### 5. Superwall Dashboard Setup

Before releasing to production:

1. **Create Paywalls**
   - Design paywall UI in Superwall Dashboard
   - Configure product variables
   - Test preview in dashboard

2. **Configure Placements**
   - Create placement events (e.g., `"profile_limit"`, `"task_limit"`)
   - Assign paywalls to placements
   - Set up targeting rules

3. **Set Up Campaigns**
   - Define when paywalls should appear
   - Configure A/B tests (optional)
   - Set audience targeting

4. **Link RevenueCat Products**
   - Ensure Superwall product IDs match RevenueCat
   - Verify product metadata syncs correctly

---

### 6. Testing Checklist

Before production release, test:

- [ ] Purchase flow works in sandbox environment
- [ ] Restore purchases works correctly
- [ ] Entitlement checking works (`hasUnlimitedAccess()`)
- [ ] Paywall displays correctly
- [ ] User identification on login
- [ ] User logout clears subscription state
- [ ] Build configuration correctly switches keys
- [ ] Release build crashes if production key not set
- [ ] Analytics tracking (if implemented)

---

### 7. Security Best Practices

#### API Key Management

**Current Approach**: Build configuration with compile-time switching
- ✅ Simple and effective
- ✅ Test keys can be committed safely
- ⚠️ Production keys in source code

**Alternative Approaches** (for enhanced security):

##### Option A: Use .xcconfig files (Recommended for teams)

1. Create `Config/Debug.xcconfig`:
   ```
   REVENUECAT_API_KEY = test_JxDSDtqZjJxdAqlujuzvhPtVHSO
   SUPERWALL_API_KEY = pk_1FZVcGgpr1JMD5XJ4d0Cb
   ```

2. Create `Config/Release.xcconfig`:
   ```
   REVENUECAT_API_KEY = appl_YOUR_PRODUCTION_KEY
   SUPERWALL_API_KEY = pk_YOUR_PRODUCTION_KEY
   ```

3. Add to `.gitignore`:
   ```
   Config/Release.xcconfig
   ```

4. Update `Info.plist`:
   ```xml
   <key>REVENUECAT_API_KEY</key>
   <string>$(REVENUECAT_API_KEY)</string>
   <key>SUPERWALL_API_KEY</key>
   <string>$(SUPERWALL_API_KEY)</string>
   ```

5. Read in code:
   ```swift
   guard let apiKey = Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as? String else {
       fatalError("Missing RevenueCat API key")
   }
   ```

##### Option B: Use Environment Variables (CI/CD)

For automated builds, inject keys via environment variables:

```bash
# In CI/CD pipeline
export REVENUECAT_API_KEY="appl_production_key"
xcodebuild -scheme Halloo ...
```

---

### 8. App Store Submission

Final pre-submission checklist:

- [ ] Production RevenueCat API key configured
- [ ] Test Store key NOT used in Release build
- [ ] Products configured in App Store Connect
- [ ] Products configured in RevenueCat Dashboard
- [ ] Paywalls configured in Superwall Dashboard
- [ ] Privacy policy updated for subscriptions
- [ ] App Store screenshots show paywall (if applicable)
- [ ] Restore purchases button available in UI
- [ ] Subscription management link in settings

---

### 9. Post-Launch Monitoring

After launching to production:

1. **RevenueCat Dashboard**
   - Monitor customer info updates
   - Check transaction logs
   - Review revenue analytics
   - Track active subscriptions

2. **Superwall Dashboard**
   - Monitor paywall presentation rates
   - Track conversion rates
   - Review A/B test results
   - Analyze user behavior

3. **App Store Connect**
   - Monitor subscription metrics
   - Review customer feedback
   - Check for failed transactions

---

### 10. Troubleshooting

#### Issue: "Invalid API key" in production

**Solution**: Verify you're using the correct production key for Apple App Store

#### Issue: Purchases not restoring

**Solution**:
- Verify user identification is working (`logIn()` called)
- Check RevenueCat dashboard for customer record
- Ensure App Store Connect is properly connected

#### Issue: Paywall not showing

**Solution**:
- Check Superwall placement configuration
- Verify campaign is active
- Review targeting rules
- Check console logs for Superwall events

#### Issue: Entitlements not active after purchase

**Solution**:
- Verify entitlement ID matches (`"Remi Unlimited"`)
- Check product is attached to entitlement
- Review customer info in RevenueCat dashboard

---

## Support Resources

- **RevenueCat Docs**: https://www.revenuecat.com/docs
- **Superwall Docs**: https://superwall.com/docs
- **RevenueCat Support**: support@revenuecat.com
- **Superwall Support**: support@superwall.com

---

## Emergency Rollback

If critical issues arise after launch:

1. **Disable paywalls**: Use Superwall Dashboard to disable campaigns
2. **Monitor RevenueCat**: Check for failed transactions or entitlement issues
3. **App update**: Submit hotfix if code changes needed

---

**Last Updated**: 2025-11-18
**Next Review**: Before App Store submission
