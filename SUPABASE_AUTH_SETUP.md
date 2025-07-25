# Supabase Authentication Provider Setup

## 🍎 Apple Sign-In Configuration

### Supabase Dashboard Setup:
1. Navigate to: **Authentication** → **Providers** → **Apple**
2. Enable Apple provider
3. Configure the following:

**Required Information:**
- **Services ID**: `com.brennen.PulseSwift.auth`
- **Team ID**: [Your Apple Developer Team ID]
- **Key ID**: [From Apple Developer Console]
- **Private Key**: [Content of .p8 file from Apple]

### Apple Developer Console Setup:
1. **App ID Configuration**:
   - Bundle ID: `com.brennen.PulseSwift`
   - Enable "Sign In with Apple" capability

2. **Services ID Creation**:
   - Identifier: `com.brennen.PulseSwift.auth`
   - Enable "Sign In with Apple"
   - Configure Return URLs:
     - `https://nlkmhztubzbnkjjgkpop.supabase.co/auth/v1/callback`

3. **Apple Sign-In Key**:
   - Create new key with "Sign In with Apple" enabled
   - Download .p8 file
   - Note the Key ID

---

## 🟢 Google Sign-In Configuration

### Supabase Dashboard Setup:
1. Navigate to: **Authentication** → **Providers** → **Google**
2. Enable Google provider
3. Configure the following:

**Required Information:**
- **Client ID**: `376592536925-48eurq0njh0uqhaam862pb0fav5aq94h.apps.googleusercontent.com`
- **Client Secret**: [Get from Google Cloud Console]

### Google Cloud Console Setup:
1. **OAuth 2.0 Client Configuration**:
   - Application type: iOS
   - Bundle ID: `com.brennen.PulseSwift`

2. **Add Authorized Redirect URIs**:
   - `https://nlkmhztubzbnkjjgkpop.supabase.co/auth/v1/callback`

3. **Get Client Secret**:
   - Go to APIs & Services → Credentials
   - Find your OAuth 2.0 Client ID
   - Copy the Client Secret

---

## 🔧 Testing Configuration

Once configured, test in your app:

1. **Apple Sign-In**: Should redirect to Apple's auth flow
2. **Google Sign-In**: Should redirect to Google's auth flow
3. **Both should redirect back to your app** after successful authentication

## 📝 Important Notes

- **Redirect URLs must match exactly** between providers and Supabase
- **Bundle IDs must be consistent** across all configurations
- **Test in simulator first**, then on device
- **Apple Sign-In** requires actual Apple ID (won't work with test accounts)

## 🚨 Common Issues

1. **"Invalid client" error**: Check Client ID/Secret match
2. **Redirect mismatch**: Verify redirect URLs are exact
3. **App not opening**: Check URL scheme configuration
4. **Apple Sign-In not working**: Verify Team ID and Key ID are correct 