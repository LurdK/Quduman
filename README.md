# Quduman (قُدُمًا) — Daily Quran Ayah & Interactive Home Screen Widget

<p align="center">
  <img src="assets/images/app_icon.png" width="128" height="128" alt="Quduman App Icon" />
</p>

<p align="center">
  <em>A minimalist, distraction-free Android mobile application focused on reading <strong>one verse (ayah) of the Quran per day</strong>, prioritizing contemplation and consistency (istiqamah).</em>
</p>

---

## ✨ Features

- **📱 Interactive Android Home Screen Widget:**
  - Built natively with **Jetpack Glance** (Compose for AppWidgets).
  - Displays the active verse directly on your launcher with Arabic Uthmani text, Surah/Ayah badges, and translation.
  - **In-Place `[Next →]` Button:** Advance to the next verse directly from your home screen without opening the app.
  - **Deep-Link to App:** Tap any part of the verse to open the reader directly.
  - Forward-only cadence designed for daily progression across all 6,236 verses.

- **📖 Distraction-Free Verse Reader:**
  - **Uthmani Script:** Clean Quranic typography using bundled `Amiri Quran` font with complete tashkeel.
  - **Dual Translations:** English (Saheeh International) and Malay (Abdullah Muhammad Basmeih).
  - **Dynamic Verse Statistics:** Real-time character, word, and letter counts.

- **🎙️ Word-by-Word Audio Synchronization:**
  - Clear, deliberate recitation by Sheikh Mahmoud Khalil Al-Husary (`Husary_128kbps` via EveryAyah CDN).
  - Real-time karaoke-style word highlighting synchronized with precise audio timestamps.
  - Interactive audio scrubber slider with formatted timestamps (`00:00 / 00:00`).
  - Optional **Autoplay** mode for seamless listening when browsing verses.

- **🗃️ 100% Offline Database:**
  - Pre-bundled SQLite database (`quran.db`) containing all 6,236 verses.
  - Zero server dependency, zero tracking, zero ads.

---

## 📥 Download Standalone APK

You can download and install the ready-to-run `.apk` directly from the [GitHub Releases](../../releases) section:

1. Go to the **[Releases](../../releases)** tab on GitHub.
2. Under the latest release (`v1.0.0`), download **`app-release.apk`**.
3. On your Android device, tap the downloaded file and select **Install** (allow installation from unknown sources if prompted).
4. Add the **Quduman** widget to your home screen!

---

## 🛠️ Architecture & Tech Stack

```text
┌────────────────────────────────────────────────────────┐
│                   MAIN FLUTTER APP                     │
│  - Starting Verse Picker (Surah 1..114, Ayah 1..N)     │
│  - Verse Reader: Audio playback + word sync            │
│  - Reads from bundled SQLite (quran.db)                │
│  - Writes active verse to SharedPreferences            │
└───────────────────────────┬────────────────────────────┘
                            │
                            │ HomeWidget.saveWidgetData()
                            ▼
┌────────────────────────────────────────────────────────┐
│             ANDROID SHARED PREFERENCES                 │
│  Stores: current_verse_index, surah_name, ayah_number, │
│          verse_arabic, verse_translation               │
└───────────────────────────┬────────────────────────────┘
                            │
                            │ HomeWidget.updateWidget()
                            ▼
┌────────────────────────────────────────────────────────┐
│              ANDROID HOME SCREEN WIDGET                │
│  - Rendered natively with Jetpack Glance (Kotlin)      │
│  - Reads cached values from SharedPreferences          │
│  - [Next ->] runs background ActionCallback:           │
│      1. Reads current_verse_index                      │
│      2. Increments: next = (current % 6236) + 1        │
│      3. Queries SQLite for next verse & updates prefs  │
│      4. Redraws Glance widget in place on home screen  │
└────────────────────────────────────────────────────────┘
```

- **Framework:** Flutter (Channel stable, Dart 3.x)
- **Home Screen Widget:** Android Jetpack Glance (Kotlin)
- **Widget Bridge:** `home_widget`
- **Audio Engine:** `just_audio`
- **Database:** Bundled SQLite (`quran.db` via `sqflite`)
- **Font:** `Amiri Quran` (`assets/fonts/AmiriQuran-Regular.ttf`)

---

## 🚀 Building from Source

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.38+ recommended)
- Android SDK (API 35 / compileSdk 35)
- Java 17+

### Steps
```bash
# Clone the repository
git clone https://github.com/<your-username>/quduman.git
cd quduman

# Fetch dependencies
flutter pub get

# Run on connected Android device or emulator
flutter run

# Build production release APK
flutter build apk --release
```
The compiled standalone APK will be generated at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 📜 License

This project is open source and available under the [MIT License](LICENSE).

- **Code:** Copyright © 2026 Muhammad Syakil bin Mohd Zaidi. Licensed under the [MIT License](LICENSE).
- **Typography:** The `Amiri Quran` font is licensed under the [SIL Open Font License (OFL)](http://scripts.sil.org/OFL).
- **Quranic Data & Translations:** Tanzil Uthmani text and verified translations (Saheeh International & Abdullah Muhammad Basmeih) are sourced for open scholarly and educational contemplation.
- **Audio Recitations:** Audio streams provided by [EveryAyah](https://everyayah.com) (Sheikh Mahmoud Khalil Al-Husary).
