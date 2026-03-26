# 💜 Mend - AI-Powered Couples Therapy App

<div align="center">

![Mend Logo](https://img.shields.io/badge/Mend-AI%20Couples%20Therapy-blueviolet?style=for-the-badge&logo=heart)

[![Flutter](https://img.shields.io/badge/Flutter-3.8+-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Integration-orange?style=flat-square&logo=firebase)](https://firebase.google.com)
[![ZEGO Cloud](https://img.shields.io/badge/ZEGO-Voice%20SDK-blue?style=flat-square)](https://www.zegocloud.com)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

*Heal, Connect, and Grow Together*

</div>

## 🌟 Overview

Mend is a revolutionary AI-powered couples therapy mobile application that provides voice-based communication guidance, conflict resolution, and relationship improvement tools through intelligent AI moderation and structured conversation flows.

Built with Flutter for cross-platform compatibility, Mend combines cutting-edge voice processing, real-time AI analysis, and therapeutic design principles to help couples strengthen their relationships through better communication.

## ✨ Features

### 🎯 Core MVP Features

#### 1. **Seamless Onboarding Process**
- **Partner Invitation System**: Secure 6-character invite codes with 24-hour expiration
- **Relationship Questionnaire**: Comprehensive 4-step assessment covering:
  - Personal information and preferences
  - Relationship goals (Communication, Conflict resolution, Intimacy, Trust, etc.)
  - Current challenges identification
  - Custom goals and challenges input
- **Color-Coded Interface**: Visual distinction with light blue for Partner A, light pink for Partner B

#### 2. **Voice-Based Chat System with AI Moderation**
- **Real-Time Voice Communication**: High-quality audio powered by ZEGO Cloud SDK
- **Smart Speaking Indicators**: Dynamic color-coded visual feedback
- **AI Interruption Detection**: Gentle red-screen warnings with respectful reminders
- **Context-Aware AI Prompts**: Intelligent conversation guidance with questions like:
  - "What's something you've been wanting to say but haven't?"
  - "Can you reflect back what you just heard from your partner?"
  - "What feelings came up for you when you heard that?"
- **Audio Visualization**: Real-time waveforms and speaking animations

#### 3. **Comprehensive Communication Scoring**
- **7-Criteria Analysis**: 
  - 💗 Empathy
  - 👂 Listening
  - 👁️ Reception
  - 💡 Clarity
  - 🤝 Respect
  - 💬 Responsiveness
  - 🧠 Open-Mindedness
- **Individual Partner Scores**: Detailed breakdowns with percentage ratings
- **Visual Progress Indicators**: Animated circular charts and radar visualizations
- **Personalized Feedback**: Specific strengths highlighting and improvement suggestions

#### 4. **Post-Resolution Flow**
- **Gratitude Expression**: Guided exercises for partner appreciation
- **Celebratory Animations**: Confetti effects and heart animations to celebrate progress
- **Shared Reflection**: Structured questions for meaningful conversation analysis
- **Bonding Activity Suggestions**: Curated activities including:
  - Mindful walks together
  - Cooking favorite meals
  - Gratitude sharing exercises
  - Date night planning
  - Note-writing activities

#### 5. **Insights Dashboard**
- **Weekly Progress Summaries**: Comprehensive analytics and trends
- **Communication Charts**: Visual progress tracking over time
- **Reflection Storage**: Access to saved thoughts and insights
- **Streak Tracking**: Daily practice motivation system
- **AI Motivational Coaching**: Personalized encouragement messages

### 🚀 Advanced Features

#### **Technical Excellence**
- **Firebase Integration**: Secure authentication and real-time data synchronization
- **Voice Processing**: Professional-grade audio with ZEGO Cloud integration
- **Mood Check-in**: Pre-session emotional state assessment
- **Responsive Design**: Adaptive UI for various screen sizes
- **Offline Capability**: Local data caching for uninterrupted experience

#### **AI & Analytics**
- **Smart Session Analysis**: Machine learning-powered communication assessment
- **Dynamic Conversation Guidance**: Context-sensitive prompts and interventions
- **Progress Intelligence**: Long-term relationship growth pattern recognition
- **Behavioral Insights**: Detailed communication pattern analysis

#### **Design & UX**
- **Therapeutic Color Palette**: Calming teal, blush pink, and soft accent colors
- **Glassmorphic Design**: Modern, translucent UI elements
- **Smooth Animations**: 60fps transitions and micro-interactions
- **Accessibility**: High contrast ratios and screen reader support

## 🛠️ Technical Stack

### **Frontend**
- **Flutter 3.8+**: Cross-platform mobile development
- **Dart**: Programming language
- **Provider**: State management
- **Flutter ScreenUtil**: Responsive design
- **FL Chart**: Data visualization
- **Confetti**: Celebration animations

### **Backend & Services**
- **Firebase Authentication**: Secure user management
- **Cloud Firestore**: Real-time database
- **ZEGO Cloud**: Voice communication SDK
- **Firebase Storage**: Media file management

### **Key Packages**
```yaml
dependencies:
  flutter: sdk: flutter
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  provider: ^6.1.1
  flutter_screenutil: ^5.9.0
  zego_express_engine: ^3.14.5
  fl_chart: ^0.66.0
  confetti: ^0.7.0
  google_fonts: ^6.1.0
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.8 or higher
- Dart SDK 3.0 or higher
- Android Studio / VS Code
- Firebase project setup
- ZEGO Cloud account

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/mend_ai.git
   cd mend_ai
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Add your Android/iOS app to the project
   - Download and place configuration files:
     - `android/app/google-services.json` (Android)
     - `ios/Runner/GoogleService-Info.plist` (iOS)
   - Enable Authentication and Firestore in Firebase Console

4. **ZEGO Cloud Setup**
   - Create account at [ZEGO Cloud Console](https://console.zegocloud.com)
   - Create a new project and get your App ID and App Sign
   - Update credentials in your environment configuration

5. **Run the application**
   ```bash
   # Development mode
   flutter run
   
   # Specific platform
   flutter run -d chrome    # Web
   flutter run -d ios       # iOS Simulator
   flutter run -d android   # Android Emulator
   ```

### Build for Production

```bash
# Android APK
flutter build apk --release

# iOS
flutter build ipa --release

# Web
flutter build web --release
```

## 📋 Development Commands

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Run tests
flutter test

# Analyze code
flutter analyze

# Clean build cache
flutter clean
```

## 🏗️ Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/                      # Data models
│   ├── partner.dart
│   ├── communication_session.dart
│   └── communication_scores.dart
├── providers/                   # State management
│   └── firebase_app_state.dart
├── screens/                     # UI screens
│   ├── auth/                   # Authentication flows
│   ├── onboarding/             # Partner setup
│   ├── chat/                   # Voice communication
│   ├── resolution/             # Post-session flows
│   └── main/                   # Dashboard and insights
├── services/                    # Business logic
│   ├── firebase_auth_service.dart
│   ├── firestore_invite_service.dart
│   ├── zego_voice_service.dart
│   └── ai_service.dart
├── widgets/                     # Reusable components
├── theme/                       # Design system
│   └── app_theme.dart
└── utils/                       # Helper functions
```

## 📱 Current Status

**✅ FULLY IMPLEMENTED MVP - PRODUCTION READY**

All core features have been successfully implemented:
- ✅ Complete onboarding process with partner invitation system
- ✅ Real-time voice communication with ZEGO Cloud integration
- ✅ AI-powered conversation moderation and guidance
- ✅ Comprehensive communication scoring system
- ✅ Post-resolution gratitude and reflection flows
- ✅ Advanced insights dashboard with analytics
- ✅ Color-coded partner interface
- ✅ Firebase authentication and data persistence
- ✅ Professional UI/UX with therapeutic design
- ✅ Mood check-in system
- ✅ Progress tracking and streak monitoring

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **ZEGO Cloud** for excellent voice communication SDK
- **Firebase** for robust backend infrastructure
- **Flutter Team** for the amazing cross-platform framework
- **Design Inspiration** from leading therapy and wellness apps

## 📞 Support

- 📧 Email: support@mendai.app
- 💬 Discord: [Join our community](https://discord.gg/mendai)
- 📚 Documentation: [docs.mendai.app](https://docs.mendai.app)

## 🗺️ Roadmap

### Phase 1 (Completed ✅)
- ✅ Core MVP features
- ✅ Voice communication
- ✅ AI-powered scoring
- ✅ Partner invitation system

### Phase 2 (Upcoming)
- 🔄 Video communication support
- 🔄 Therapist integration
- 🔄 Advanced AI coaching
- 🔄 Couple challenges and exercises

### Phase 3 (Future)
- 🔄 Group therapy sessions
- 🔄 Professional therapist matching
- 🔄 Advanced analytics dashboard
- 🔄 Integration with wearable devices

---

<div align="center">

**Made with 💜 for stronger relationships**

*This is a therapeutic application designed to support healthy communication between couples. It is not a replacement for professional therapy or counseling services.*

</div>
