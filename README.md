# ChatFlow 💬

ChatFlow is a modern messaging app built with Flutter, Firebase, and Supabase, focused on real-time communication and a clean, responsive user experience.

## ✨ Features

* User authentication with Firebase Authentication
* User profiles and account management
* One-to-one messaging with Cloud Firestore
* Real-time message synchronization
* Group chat functionality
* Supabase Storage integration for media
* Voice and video calling integration with ZEGOCLOUD
* Push notifications with Firebase Cloud Messaging
* Responsive UI with a focus on usability

## 🛠️ Tech Stack

* **Flutter & Dart** — Cross-platform app development
* **Firebase Authentication** — User sign-in and registration
* **Cloud Firestore** — User data, conversations, and messages
* **Firebase Cloud Messaging (FCM)** — Push notifications
* **Supabase Storage** — Media storage
* **ZEGOCLOUD** — Voice and video calling
* **Cubit / BLoC** — State management

## 📱 Platforms

* Android
* iOS (with the required configuration)
* Other Flutter-supported platforms, depending on project configuration

## 🚀 Getting Started

### Prerequisites

* Flutter SDK
* Dart SDK
* Android Studio or VS Code
* A Firebase project
* Supabase project credentials
* ZEGOCLOUD credentials if calling features are enabled

### Installation

1. Clone the repository:

   ```bash
   git clone YOUR_REPOSITORY_URL
   ```

2. Open the project directory:

   ```bash
   cd chat_flow
   ```

3. Install dependencies:

   ```bash
   flutter pub get
   ```

4. Configure Firebase, Supabase, and ZEGOCLOUD using your own project credentials.

5. Run the application:

   ```bash
   flutter run
   ```

## 🔧 Configuration

Before running the application, make sure the required backend services are configured correctly.

* Set up Firebase Authentication and Cloud Firestore.
* Configure Firebase Cloud Messaging if push notifications are enabled.
* Add your Supabase project URL and API key securely.
* Configure ZEGOCLOUD credentials for voice and video calls.
* Deploy appropriate Firestore security rules.

**Important:** Never commit private API keys, service-role keys, passwords, or other secrets to a public repository.

## 🧪 Testing

Run static analysis:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

Test authentication, messaging, and navigation on physical devices to verify the application works correctly across devices.

## 📂 Project Structure

The project follows a feature-oriented Flutter architecture. The exact folders may vary depending on the current implementation.

```text
chat_flow/
├── android/
├── ios/
├── lib/
│   ├── features/
│   ├── services/
│   ├── widgets/
│   └── main.dart
├── test/
├── pubspec.yaml
└── README.md
```

## 🔒 Security

* Use Firebase Authentication to identify users.
* Restrict Firestore access through appropriate security rules.
* Protect backend credentials and API keys.
* Validate access to conversations and messages.

## 🎯 Project Goal

The goal of ChatFlow is to provide a smooth messaging experience with user authentication, real-time conversations, group communication, and calling capabilities.

## 👨‍💻 Author

**Flutter Developer**

Built with Flutter, Dart, and modern backend technologies.

## 📄 License

Choose a license before distributing or publishing this project publicly.
