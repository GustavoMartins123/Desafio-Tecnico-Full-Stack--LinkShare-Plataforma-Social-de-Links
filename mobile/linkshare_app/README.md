# LinkShare Mobile App

Flutter mobile application for the LinkShare platform - A social platform for sharing link collections.

## Features

- User authentication (Login/Register)
- Profile management
- Friend system (send/accept/decline requests)
- Create and manage collections (public/private)
- Add links to collections
- Share collections with friends
- Search for users

## Getting Started

### Prerequisites

- Flutter SDK (>= 3.0.0)
- Dart SDK (>= 3.0.0)
- Android Studio / VS Code with Flutter extensions
- Running LinkShare Backend API

### Installation

1. Install dependencies:
```bash
flutter pub get
```

2. Configure API endpoint:
Edit `lib/services/api_client.dart` and set the correct `baseUrl`:
```dart
static const String baseUrl = 'http://your-api-url:8080/api';
```

3. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
├── models/          # Data models
├── services/        # API services
├── providers/       # Riverpod state management
├── screens/         # UI screens
│   ├── auth/        # Login & Register
│   ├── home/        # Home & Feed
│   ├── collections/ # Collections management
│   ├── friends/     # Friends & search
│   └── profile/     # Profile management
├── widgets/         # Reusable widgets
└── main.dart        # App entry point
```

## State Management

This app uses **Riverpod** for state management with a clean architecture pattern:
- Providers for dependency injection
- FutureProviders for async data
- StateNotifier for complex state

## Tech Stack

- **Flutter** - UI framework
- **Riverpod** - State management
- **Dio** - HTTP client
- **SharedPreferences** - Local storage

## License

This project is part of the LinkShare technical challenge.
