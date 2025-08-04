# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PulseSwift is a camera-first iOS social media app built with SwiftUI and Clean Architecture. It features location-based social networking, ephemeral messaging, and real-time push notifications.

## Build Commands

```bash
# Open project in Xcode
open PulseSwift.xcodeproj

# Build via Xcode
# Cmd+B (Build)
# Cmd+R (Build and Run)
# Cmd+U (Run Tests)
# Cmd+Shift+K (Clean Build Folder)

# Run on simulator
# Select simulator in Xcode toolbar, then Cmd+R

# Run on device
# Connect device, select it in toolbar, then Cmd+R
```

## Architecture

The codebase follows Clean Architecture with clear separation of concerns:

### Layer Structure
- **Domain Layer** (`Architecture/Domain/`): Business logic, entities, use cases, repository protocols
- **Data Layer** (`Architecture/Data/`): Repository implementations, API clients
- **Presentation Layer** (`Architecture/Presentation/`): ViewModels with Combine
- **UI Layer** (`Architecture/UI/`): SwiftUI views and screens
- **Core Services** (`Architecture/Core/`): Shared services (network, security, media)
- **DI** (`Architecture/DI/`): Dependency injection container

### Key Patterns
- Repository pattern for data access
- Use cases for business logic
- ViewModels for presentation logic
- Protocol-oriented design for testability
- Dependency injection for loose coupling

### Navigation Flow
1. `PulseSwiftApp` → `PulseApp` → `AppFlowViewModel`
2. Camera screen loads immediately (performance optimization)
3. Auth and profile screens pre-loaded in background
4. Navigation based on authentication state

## Key Dependencies

Managed via Swift Package Manager:
- **Supabase** (2.30.2): Backend services, auth, database
- **GoogleSignIn** (9.0.0): Google authentication
- **OneSignal** (5.2.14): Push notifications
- **Swift Crypto** (3.13.2): Cryptographic operations

## Environment Configuration

Four environments configured in `AppConfiguration.swift`:
- **Development**: Local testing, verbose logging
- **Staging**: Testing with production-like setup
- **Production**: Live environment, optimized settings
- **Testing**: Unit/UI testing configuration

Set environment via Xcode scheme environment variables:
- `APP_ENVIRONMENT`: development/staging/production/testing

## Key Services

### Authentication (`SupabaseService.swift`)
- Multi-provider support: Apple, Google, Supabase email
- Token management with Keychain storage
- Automatic token refresh

### Camera (`CameraViewModel.swift`, `MediaProcessor.swift`)
- Instant camera startup optimization
- Video/photo capture with quality levels
- Background compression and processing

### Location (`LocationManager.swift`)
- User location tracking for nearby connections
- Permission handling
- Background location updates

### Push Notifications (`NetworkService.swift`)
- OneSignal integration
- User preference management
- Rich notification support

## Database Schema

PostgreSQL database with key tables:
- `users`: User profiles with locations
- `messages`: Ephemeral messaging
- `pulses`: User activity broadcasts
- `conversations`: 3-minute chat windows
- `push_preferences`: Notification settings

## Testing

```bash
# Run unit tests in Xcode
Cmd+U

# Run specific test
Click test diamond in Xcode editor

# UI tests included but require setup
```

## Common Development Tasks

### Adding New Features
1. Create domain entities in `Domain/Entities/`
2. Define repository protocol in `Domain/Repositories/`
3. Implement use cases in `Domain/UseCases/`
4. Create repository implementation in `Data/Repositories/`
5. Add ViewModel in `Presentation/ViewModels/`
6. Build UI in `UI/Screens/` or `UI/Views/`
7. Register dependencies in `DIContainer.swift`

### Updating API Endpoints
- Network configuration in `NetworkService.swift`
- Environment-specific URLs in `AppConfiguration.swift`
- Add new endpoints following existing patterns

### Modifying Push Notifications
- OneSignal setup in `NetworkService.swift`
- User preferences in `push_preferences` table
- Rich notifications support via OneSignal dashboard

## Important Notes

### Performance Considerations
- Camera preloading is critical for app experience
- Use appropriate media quality levels
- Implement caching for frequently accessed data
- Profile performance with Instruments

### Security
- All tokens stored in Keychain
- Certificate pinning enabled for staging/production
- Never commit sensitive data or API keys
- Use environment variables for configuration

### Code Style
- Follow existing SwiftUI patterns
- Use Combine for reactive programming
- Maintain Clean Architecture boundaries
- Write testable code with protocols