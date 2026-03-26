# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mend is a fully-implemented AI-powered couples therapy mobile application built with Flutter. The app provides voice-based communication guidance, conflict resolution, and relationship improvement tools through AI moderation and structured conversation flows using Firebase backend and ZEGO Cloud for real-time voice communication.

## Development Commands

### Essential Commands
```bash
# Install dependencies
flutter pub get

# Run the app (development)
flutter run

# Run on specific device
flutter run -d chrome        # Web
flutter run -d macos         # macOS  
flutter run -d ios           # iOS simulator
flutter run -d android       # Android emulator

# Build for production
flutter build apk --release  # Android APK
flutter build ipa --release  # iOS
flutter build web --release  # Web

# Run tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage

# Analyze code (lint and static analysis)
flutter analyze

# Clean build cache
flutter clean && flutter pub get
```

## Architecture and Current Implementation

### Application Structure
The app follows a feature-based architecture with clear separation of concerns:

```
lib/
├── main.dart                     # App entry point with Firebase initialization
├── models/                       # Data models
│   ├── partner.dart              # Partner data structure
│   └── communication_session.dart # Session recording model
├── providers/                    # State management (Provider pattern)
│   └── firebase_app_state.dart   # Global app state and authentication
├── screens/                      # UI screens organized by feature
│   ├── auth/                     # Authentication flows
│   │   ├── auth_wrapper.dart     # Authentication state handler
│   │   └── login_screen.dart     # Google Sign-In interface
│   ├── onboarding/               # Partner setup and questionnaire
│   │   └── questionnaire_screen.dart
│   ├── chat/                     # Voice communication
│   │   └── zego_voice_chat_screen.dart # ZEGO Cloud integration
│   ├── main/                     # Core app screens
│   │   ├── home_screen.dart      # Dashboard and session initiation
│   │   ├── insights_dashboard_screen.dart # Analytics and progress
│   │   └── session_waiting_room_screen.dart # Pre-session setup
│   └── resolution/               # Post-session flows
│       ├── scoring_screen.dart   # Communication assessment
│       └── post_resolution_screen.dart # Gratitude and reflection
├── services/                     # Business logic and integrations
│   ├── firebase_auth_service.dart      # Authentication
│   ├── firestore_invite_service.dart   # Partner invitation system
│   ├── firestore_relationship_service.dart # Relationship data
│   ├── firestore_sessions_service.dart # Session management
│   ├── zego_voice_service.dart         # Voice communication
│   ├── zego_token_service.dart         # ZEGO authentication
│   └── ai_service.dart                 # AI conversation analysis
├── widgets/                      # Reusable components
│   ├── animated_card.dart        # Glassmorphic cards
│   ├── app_logo.dart            # Brand logo component
│   ├── gradient_button.dart     # Themed buttons
│   ├── loading_overlay.dart     # Loading states
│   └── mood_checkin_dialog.dart # Pre-session mood assessment
└── theme/
    └── app_theme.dart           # Complete design system
```

### Key Dependencies and Integrations

**Core Framework:**
- Flutter 3.8+ with Material 3 design system
- Provider for state management
- ScreenUtil for responsive design

**Backend Services:**
- Firebase Core, Auth, and Firestore for data persistence
- Google Sign-In integration
- ZEGO Express Engine for real-time voice communication

**Audio and Voice:**
- Speech-to-text and TTS capabilities
- Record package for audio capture
- Audioplayers for playback
- Audio waveforms for visualization

**UI and Animations:**
- FL Chart for analytics visualization
- Lottie animations for engagement
- Confetti effects for celebrations
- Glassmorphic design with custom decorations

### Theme and Design System

The app implements a sophisticated dark-mode design system with:
- **Neon Color Palette**: Teal (AI), Pink (Partner B), Blue (Partner A), Violet (accents)
- **Glassmorphic Components**: Translucent cards with blur effects and glow
- **Partner Color System**: Dynamic color assignment based on partner roles
- **Typography**: Google Fonts Manrope with hierarchical text styles
- **Spacing System**: Consistent 8pt grid (4px, 8px, 16px, 24px, 32px, 48px)

### State Management Pattern

The app uses Provider pattern with:
- `FirebaseAppState`: Global authentication and user state
- Screen-level state management for UI components
- Service classes for business logic separation

### Voice Communication Architecture

ZEGO Cloud integration provides:
- Real-time voice rooms with partner identification
- Audio quality optimization
- Speaking indicator visualization
- Room management and user presence

## Development Guidelines

### Code Conventions
- Follow existing architectural patterns in the codebase
- Use the established theme system (`AppTheme`) for all styling
- Implement glassmorphic design with provided decoration methods
- Maintain Partner A/B color coding throughout the app
- Use Provider pattern for state management
- Keep business logic in service classes

### Firebase Integration
- All data operations go through Firestore services
- Authentication handled by `FirebaseAppState`
- Real-time listeners for collaborative features
- Proper error handling and offline capabilities

### ZEGO Voice Integration
- Use `ZegoVoiceService` for all voice operations
- Implement proper cleanup in dispose methods
- Handle voice room lifecycle management
- Partner identification through user IDs

### Testing
- Widget tests in `test/` directory
- Follow existing test patterns
- Test both authentication flows and core features

## Platform Considerations

**Primary Target:** iOS with full Android and Web support
**Build Requirements:**
- iOS: Requires proper provisioning and signing
- Android: Uses standard APK build process
- Web: Supported but voice features may have limitations

## Environment Setup

Required configurations:
1. **Firebase Project**: Set up with Authentication and Firestore
2. **ZEGO Cloud Account**: Configure App ID and tokens
3. **Google Sign-In**: Configure OAuth client IDs
4. **Platform-specific**: iOS Info.plist and Android permissions

## Development Notes

- Uses Material 3 with custom theme implementation
- Flutter SDK ^3.8.1 with null safety
- Lint rules via `flutter_lints ^5.0.0`
- Custom analysis_options.yaml with Flutter recommended lints
- Firebase integration requires proper configuration files
- ZEGO Cloud requires API credentials for voice functionality