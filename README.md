# 🔐 Password Manager

A fully offline, secure and modern **Password Manager App** featuring biometric authentication, master PIN protection, encrypted backup, and local database storage.

---

## ✨ Features

### 🛡️ Security
- **Master PIN Protection** — 4-digit authentication at app launch
- **Biometric Authentication** — Fingerprint unlock support
- **Dual Authentication** — Master PIN for edits/deletes, Biometric for viewing
- **Secure Local Storage** — SQLite database with Flutter Secure Storage for sensitive keys
- **Auto Lock** — Locks automatically when the app is backgrounded or interrupted

### 🔑 PIN Management
- **Change PIN** — Update your master PIN anytime by verifying the current one first
- **Forgot PIN? Reset via Fingerprint** — If you forget your PIN, reset it securely using fingerprint authentication (no email/SMS required)
- Reset option is hidden if the device has no enrolled biometrics

### 📦 Backup & Restore
- **Encrypted Export** — Backs up all credentials to an AES-256 encrypted `.pmbak` file
- **Password-Protected Backup** — Every backup file is protected by a user-chosen backup password, separate from your PIN
- **Import / Restore** — Pick a `.pmbak` file from any source (local storage, Google Drive, etc.) and decrypt it to restore credentials
- **Platform-Agnostic** — Backup files can be transferred between devices and cloud providers freely

### 📋 Credential Management
- Add, edit, and delete credentials
- Search credentials by app/website name
- Group accounts by app/website
- Display total credential count

### 🎨 UI & UX
- Modern dark theme
- Responsive layout for all screen sizes
- Smooth navigation & animations
- Glassmorphism busy overlay during encryption/decryption
- Confirmation dialogs for destructive actions

---

## ⚡ Performance

- ⚙️ Fast SQLite queries with minimal overhead
- 🔍 Instant search filtering
- 🔒 AES-256 encryption runs off the main thread to keep the UI responsive

---

## 📚 Technical Stack

| Layer | Technology |
|---|---|
| Framework | Flutter |
| Language | Dart |
| Database | SQLite (`sqflite`) |
| Secure Key Storage | `flutter_secure_storage` |
| Biometric Auth | `local_auth` |
| PIN / Lock UI | `flutter_screen_lock` |
| App Lifecycle Lock | `flutter_app_lock` |
| Encryption | `encrypt` (AES-256) |
| File Sharing | `share_plus` |
| File Picking | `file_picker` |
| UI Design | Material Design 3 |

---

## 🔄 How Backup Works

```
Export
  └─ Enter backup password
       └─ All credentials → JSON → AES-256 encrypted → .pmbak file
            └─ Share via any app (Drive, Files, WhatsApp, etc.)

Import
  └─ Pick .pmbak file
       └─ Enter backup password
            └─ Decrypt → validate → insert credentials into local DB
```

---

## 🔐 How PIN Management Works

```
Change PIN
  └─ ⋮ menu → Change PIN → Enter current PIN → Set new PIN

Forgot PIN (fingerprint only)
  └─ ⋮ menu → Change PIN → Forgot PIN? → Fingerprint prompt → Set new PIN
```

---
