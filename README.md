# CleanMail ✉️🧹

> A fast, distraction-free, text-only email viewer with powerful cleanup workflows and multi-mailbox support, built with Flutter.
>
> 📖 **User Guide**: For a detailed, user-friendly walkthrough of all features and how to navigate the app, see the **[CleanMail User Guide](features.md)**.
>
> 🔧 **Technical Documentation**: For sequence diagrams, delta sync algorithms, and technical specs, see the **[Synchronization Architecture Guide](docs/SYNC_ARCHITECTURE.md)**.

---

## 🌟 Key Features

### 1. 📄 Pure Text-Only Reading Engine
* **Zero HTML & WebViews**: Heavy stylesheets, complex HTML layouts, and scripts are stripped away, presenting emails in clean, readable typography.
* **100% Tracking Pixel Protection**: Invisible tracking pixels (`1x1` GIFs, hidden beacons) are identified and neutralized before rendering.
* **Link Footnotes & Previews**: Hyperlinks are converted to clean, non-deceptive footnotes and Markdown-style links.
* **Ultra-Low Bandwidth & Battery**: No remote images or heavy assets are downloaded during reading.

### 2. 🧹 Easy-to-Clean Triage Suite & Full Two-Way Sync
* **Two-Way Read Sync**: Reading an email in CleanMail marks it as read in real Gmail via `POST /modify` (`removeLabelIds: ['UNREAD']`).
* **Two-Way Delete Sync**: Deleting in CleanMail (swipe gesture, reader trash button, or Sender Sweep) moves the message to Trash in real Gmail via `POST /trash`.
* **Two-Way Restore (Undo)**: Tapping **Undo** on the 5-second deletion snackbar restores the email locally and restores it from Gmail Trash via `POST /untrash`.
* **Sender Sweep**: Groups emails by sender volume, allowing you to inspect all messages from a sender or **Delete All** in a single tap with parallelized batch trashing in Gmail.
* **Email Locking & Protection**: Protect critical messages with a visible lock badge. Locked emails cannot be accidentally swiped to delete and are preserved during bulk triage.
* **Preferred Tags & Sender Rules**: Configure custom categories and auto-locking for specific senders going forward.
* **One-Tap Unsubscribe**: Detects `List-Unsubscribe` headers (HTTP or mailto) and surfaces a prominent 1-click unsubscribe banner.
* **Fast Swipe Triage**: Fluid swipe gestures in the inbox:
  * **Swipe Left** $\rightarrow$ Delete (red, syncs to Gmail Trash).
  * Includes an instant 5-second **Undo** toast notification with remote untrash.
* **Multi-Select & Batch Actions**: Long-press any email to enter multi-select mode, select multiple emails, and bulk delete or toggle lock status.

### 3. ⚡ Approach 2: High-Performance Gmail Delta History Sync
* **Ultra-Fast Delta Synchronization**: Instead of repeatedly re-downloading thousands of messages, CleanMail tracks mailbox checkpoints using Gmail's `users.history.list` API (`GET /gmail/v1/users/me/history?startHistoryId=...`).
* **Smart Sync with Batching (100 at a time)**: When refreshing, CleanMail checks for latest emails first, and if head is up to date, fetches older un-synced emails in batches of 100.
* **Mailbox Progress Bars**: Shows exact `X of Y synced (Z%)` and total emails available in the mailbox.
* **Scale-Free Performance**: Effortlessly syncs mailboxes with 10,000 to 500,000+ emails in **~100ms** using only **2 quota units** per sync.
* **Bi-Directional Change Detection**:
  * Deletions made in real Gmail (web/mobile) are automatically removed from CleanMail's local database.
  * Read/unread statuses changed in Gmail are immediately mirrored locally.
  * Only newly arrived messages (`messagesAdded`) are downloaded and sanitized.
* **Self-Healing Fallback**: If an account has not synced in over 30 days and Google expires the `historyId` (HTTP 404), CleanMail automatically recovers via a windowed resync, establishing a fresh `historyId` checkpoint without user intervention.
* *(See full architectural breakdown in [docs/SYNC_ARCHITECTURE.md](docs/SYNC_ARCHITECTURE.md))*.

### 4. 📬 Single-Pane Unified Multi-Mailbox
* **Chronological Aggregated Feed**: View messages across all your connected accounts in one central view.
* **Color-Coded Mailbox Chips**: Visual badges for each mailbox (e.g., Blue for Personal Gmail, Purple for Work Outlook).
* **Filter Chips**: Filter by **All Inboxes** or tap an individual account chip to isolate that mailbox.
* **Real-Time Search**: Instant local search across subjects, senders, and email text.

### 5. 🏷️ Smart On-Device Categorization
* Runs completely client-side with zero latency and full privacy:
  * **Personal**: Direct communications from colleagues, friends, or few recipients.
  * **Newsletters**: Mailing lists, digests, and recurring publications.
  * **Transactions**: Receipts, invoices, shipping tracking, and order confirmations.
  * **Updates**: System alerts, password resets, and automated platform notifications.

### 6. 🔒 Offline-First & Privacy-Focused
* **Drift (SQLite) Database**: All messages, accounts, and statistics are stored locally in an encrypted/private SQLite database.
* **Instant Offline Access**: Read, search, and triage previously synced emails with zero internet connection.
* **Secure Token Storage**: OAuth tokens and credentials are encrypted on-device via Android Keystore, iOS Keychain, and Windows DPAPI (`flutter_secure_storage`).

### 7. ⚙️ Settings Section & Terminal Nerd Theme
* **Multi-Theme Selection**:
  * **System Default**: Automatically follows your device light or dark appearance (Default).
  * **Paper Light**: Clean, high-contrast daylight reading aesthetic.
  * **Focus Dark**: Modern, low-glare dark mode for low-light environments.
  * **Terminal Nerd**: Retro hacker console aesthetic featuring CRT phosphor green (`#00FF66`), pure OLED black background (`#050805`), monospace typography throughout the entire app, retro status flags (`[NEWS]`, `[RECEIPTS]`, `[OK]`), and glowing terminal borders.
* **Persistent Preferences**: Selected theme is stored securely on-device and remembered across app restarts.
* **Central Settings Hub**: Quick access to appearance, audit logs, connected mailboxes, and Google Cloud OAuth Client ID configuration.

### 8. 📋 Operation Log Viewer & Diagnostic Audit Trail
* **Comprehensive Event Tracking**: Automatically tracks every operational event in the app:
  * **Email Synchronization**: Live counter of total emails synced, sync start/finish times, delta checkpoint updates, and quota usage.
  * **Auth & Tokens**: Login events, Google account chooser prompts, and OAuth Bearer token refresh timestamps.
  * **Email Triage**: Read status modifications, archivals, deletions, restores, and bulk Sender Sweeps.
  * **Errors & Warnings**: Immediate visibility into network issues, expired tokens (401), or disabled APIs (403).
* **Search & Real-Time Filtering**: Filter logs by category (`SYNC`, `AUTH`, `TRIAGE`, `PIPELINE`, `SYSTEM`) or severity (`INFO`, `SUCCESS`, `WARNING`, `ERROR`).
* **Export & Diagnostics**: One-tap copy of the complete formatted diagnostic log report to clipboard for troubleshooting.

---

## 🛠️ Technology Stack

| Layer | Technology |
| :--- | :--- |
| **Framework** | [Flutter 3.x](https://flutter.dev) (Dart 3) |
| **State Management** | [Flutter Riverpod](https://pub.dev/packages/flutter_riverpod) |
| **Local Database** | [Drift](https://drift.simonbinder.eu) (SQLite with Native & WebAssembly engines) |
| **Networking & APIs** | [Dio](https://pub.dev/packages/dio), [googleapis](https://pub.dev/packages/googleapis), [google_sign_in](https://pub.dev/packages/google_sign_in) |
| **HTML Sanitizer** | [html](https://pub.dev/packages/html) with custom text sanitizer |
| **Secure Storage** | [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) |

---

## 📂 Project Architecture

```
lib/
├── core/
│   ├── constants/            # App constants, badge colors, OAuth scopes
│   ├── services/             # GoogleAuthService, LogService (Audit Trail)
│   ├── theme/                # Typography & Themes (Light, Dark, Terminal Nerd)
│   └── utils/
│       ├── heuristic_classifier.dart   # On-device category classifier
│       └── html_to_text.dart           # HTML stripper & tracking pixel blocker
├── data/
│   ├── local/
│   │   ├── connection/       # Platform DB connections (Native SQLite & WASM)
│   │   ├── tables/           # Drift tables (Accounts, Messages, Senders)
│   │   ├── database.dart     # Drift Database & DAOs
│   │   └── sample_data.dart  # Realistic sample data seeder
│   └── repositories/         # Concrete repository implementations
├── domain/
│   ├── models/               # Domain entities (MailAccount, MailMessage, etc.)
│   └── repositories/         # Abstract repository contracts
└── features/
    ├── accounts/             # Mailbox manager & Google Client ID settings
    ├── clean_sweep/          # Sender Sweep screen (bulk cleanup)
    ├── inbox/                # Unified inbox screen & swipeable email tiles
    ├── reader/               # Distraction-free text-only viewer
    ├── settings/             # Settings screen & Operation Log Viewer
    └── providers.dart        # Global Riverpod reactive state providers
```

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.50+ recommended)
* Google Chrome (for web testing) or Android Studio / Device (for mobile)

### Installation
1. Clone or navigate to the repository:
   ```bash
   cd cleanmail
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

---

## 💻 Running the App

### 1. Web (Google Chrome)
For Google OAuth to match your authorized origins, run on fixed port `8080`:
```bash
# Using PowerShell helper:
.\run-web.ps1

# Or standard Flutter CLI:
flutter run -d chrome --web-hostname localhost --web-port 8080
```
> **VS Code / IDE**: Open the Run & Debug panel and select **"CleanMail (Chrome - Port 8080)"**, then press **F5**.

### 2. Android Device / Emulator
* Connect your phone with **USB Debugging enabled** and run:
  ```bash
  flutter run -d android
  ```
* Or build a standalone debug APK:
  ```bash
  flutter build apk --debug
  ```
  *(APK will be at `build/app/outputs/flutter-apk/app-debug.apk`)*

### 3. Windows Desktop
```bash
flutter run -d windows
```

---

## 🔑 Google OAuth Setup

CleanMail connects to Gmail using official Google OAuth 2.0.

### Configuring Your Google Client ID:
1. In the app, open **Mailboxes** (account icon in the top right).
2. Tap the **⚙️ Settings icon** (or the **"Google Client ID Configuration"** card).
3. Paste your OAuth Client ID and tap **Save Client ID**.

### Setup in Google Cloud Console:
1. Go to [Google Cloud Console](https://console.cloud.google.com/) and create a project.
2. Enable the **Gmail API** under *APIs & Services > Library*.
3. In **OAuth consent screen**, set user type to **External**, add your Gmail as a **Test User**, and add the scopes `https://www.googleapis.com/auth/gmail.readonly` and `https://www.googleapis.com/auth/gmail.modify`.
4. In **Credentials**, create an **OAuth 2.0 Client ID**:
   * **For Web**:
     * Application type: **Web application**
     * Authorized JavaScript origins: `http://localhost:8080`, `http://localhost`
     * Authorized redirect URIs: `http://localhost:8080`
   * **For Android**:
     * Application type: **Android**
     * Package name: `com.shuvankar.cleanmail`
     * SHA-1 fingerprint: `<YOUR_SHA1_FINGERPRINT>` (obtain via `cd android; .\gradlew signingReport`)

---

## 🧪 Testing & Code Quality

CleanMail maintains 100% static analysis pass rate and comprehensive unit tests:

```bash
# Run unit tests
flutter test

# Run static analysis
flutter analyze
```

---

## 📄 License
This project is private and intended for personal use.
