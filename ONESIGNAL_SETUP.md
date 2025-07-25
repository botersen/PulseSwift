# OneSignal Setup Guide for Pulse App

## 🎯 Quick Setup Steps

### 1. Get Your OneSignal App ID
1. Go to [onesignal.com](https://onesignal.com) and create a free account
2. Click **"New App/Website"**
3. Enter **"Pulse"** as the app name
4. Select **Apple iOS (APNs)** as the platform
5. Copy your **App ID** (looks like: `12345678-1234-1234-1234-123456789abc`)

### 2. Update Your Code
In `PulseSwift/Core/Managers/OneSignalManager.swift`, find line 16:
```swift
private let appId = "YOUR_ONESIGNAL_APP_ID" // TODO: Replace with your actual OneSignal App ID
```

Replace `"YOUR_ONESIGNAL_APP_ID"` with your actual App ID:
```swift
private let appId = "12345678-1234-1234-1234-123456789abc"
```

### 3. Configure APNs (Apple Push Notification Service)
1. In OneSignal dashboard, go to **Settings → Platforms → Apple iOS (APNs)**
2. Upload your **APNs Certificate** or **APNs Key** from Apple Developer Center
3. Set environment to **Sandbox** for development, **Production** for App Store

### 4. Enable Push Notifications in Xcode
✅ You already did this! The capability should be enabled in your project.

## 🔔 Notification Types Setup

Your app is configured to handle these notification types:

### 1. New Pulse Received
```json
{
  "headings": {"en": "New Pulse! 📱"},
  "contents": {"en": "Someone sent you a pulse from Downtown!"},
  "data": {
    "type": "new_pulse",
    "pulse_id": "pulse_123",
    "sender_location": "Downtown"
  }
}
```

### 2. Pulse Match
```json
{
  "headings": {"en": "It's a Match! 💫"},
  "contents": {"en": "You and Alex both want to connect!"},
  "data": {
    "type": "pulse_match",
    "match_id": "match_456",
    "other_user": "alex_123"
  }
}
```

### 3. Pulse Expiring
```json
{
  "headings": {"en": "Pulse Expiring ⏰"},
  "contents": {"en": "Your pulse expires in 10 minutes"},
  "data": {
    "type": "pulse_expiring",
    "pulse_id": "pulse_789"
  }
}
```

### 4. Nearby Users
```json
{
  "headings": {"en": "Active Users Nearby 📍"},
  "contents": {"en": "5 users are active within 1 mile"},
  "data": {
    "type": "nearby_users",
    "user_count": 5,
    "radius": "1 mile"
  }
}
```

## 🧪 Testing Your Setup

### 1. Test Basic Setup
1. Build and run your app
2. Look for console logs: `✅ OneSignal initialized successfully`
3. Check for: `✅ OneSignal Player ID: abc123...`

### 2. Send Test Notification
Use OneSignal dashboard:
1. Go to **Messages → New Push**
2. Select **Send to Test Device**
3. Enter your Player ID (from console logs)
4. Send a test message

### 3. Test with Code
In your app, you can call:
```swift
oneSignalManager.sendTestNotification()
```

## 🚀 Going Live

### When ready for production:
1. Update APNs certificates to **Production**
2. Update OneSignal environment to **Production**
3. Test thoroughly on TestFlight
4. You're ready for App Store!

## 🎯 Geotargeted Notifications

Once you add location services:
1. Users will be automatically tagged with their location
2. You can send notifications to users within specific areas
3. Perfect for "Users nearby" or location-specific pulses

## 📊 Analytics

OneSignal dashboard provides:
- Delivery rates
- Open rates
- Click-through rates
- User engagement metrics
- Geographic distribution

## 🔧 Advanced Features (Coming Soon)

- **A/B Testing**: Test different notification strategies
- **Automation**: Send notifications based on user behavior
- **Segments**: Target specific user groups
- **Rich Media**: Add images and action buttons
- **Web Push**: Extend to web version later

---

## ✅ What's Working Now

- ✅ OneSignal initialization
- ✅ User identification
- ✅ Push permission handling
- ✅ Notification click handling
- ✅ User property syncing
- ✅ Deep linking ready
- ✅ Production ready architecture

Just add your OneSignal App ID and you're ready to go! 🚀 