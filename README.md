# Healthcare App
## Advanced Healthcare & Doctor Appointment Management System

[![Flutter](https://img.shields.io/badge/Flutter-3.47+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Tests](https://img.shields.io/badge/Tests-31%20Passed-16A34A?logo=checkmarx&logoColor=white)](test/)
[![Analysis](https://img.shields.io/badge/Analysis-0%20Issues-16A34A)](analysis_options.yaml)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

An end-to-end medical appointment scheduling, consultation, and patient record management system built with Flutter and Dart following Clean Architecture and Feature-First packaging.

- **Package ID / Application ID:** `com.mudasir.healthcareapp`
- **Application Label:** `Healthcare App`
- **Target Platforms:** Android & iOS

---

## 1. Quick Start & Demo Personas

For evaluators and reviewers, quick login chips are built directly into the login screen:

| Role | Email | Password | Persona & Capabilities |
| :--- | :--- | :--- | :--- |
| **Patient** | `patient@healthcare.com` | `Password123!` | **Sarah Jenkins** • Search specialists, book slots, attend video room, view Rx |
| **Doctor** | `doctor@healthcare.com` | `Password123!` | **Dr. Emily Stone, MD** (Cardiologist) • Manage agenda, accept requests, write Rx |
| **Pending Doc** | `doctor2@healthcare.com` | `Password123!` | **Dr. Alex Morgan, DO** (Dermatologist) • Pending verification workflow demo |
| **Admin** | `admin@healthcare.com` | `Password123!` | **Admin Mark** • Verification desk, taxonomy manager, system metrics |

---

## 2. The 7 Mandatory Difficult Challenges

### 1. Conflict-Free Booking (Database-Level Concurrency Protection)
- **Problem:** Preventing race-condition double bookings when multiple users simultaneously book the same time slot for a doctor.
- **Solution:** Every reservation claims a deterministic slot lock key:
  `slots/{doctorId}_{yyyyMMddTHHmm}` (e.g. `doc123_20261102T0900`).
- Transactions atomically check if the slot key exists. The first write commits, while colliding attempts immediately receive `SlotAlreadyBookedException` and prompt the user to re-pick an available slot.

### 2. Time-Zone Normalization & Local Rendering
- **Problem:** Coordinating consultations across patients and specialists in different time zones.
- **Solution:** All timestamps are strictly stored and transmitted in ISO-8601 UTC (`toUtc().toIso8601String()`). The presentation layer parses UTC and dynamically converts to the user's device local timezone with explicit timezone indicators (e.g., `Nov 2, 2026 • 9:30 AM (PKT)`).

### 3. Formal Appointment State Machine
- **Problem:** Preventing invalid status progressions or illegal cancellations.
- **Solution:** Formal Dart state machine (`AppointmentStateMachine`) enforcing valid forward transitions:
  - `Requested` ➔ `Confirmed` (Doctor approves)
  - `Requested` ➔ `Rejected` (Doctor declines)
  - `Requested` ➔ `Cancelled` (Patient cancels)
  - `Confirmed` ➔ `InProgress` (Consultation begins)
  - `Confirmed` ➔ `Cancelled` (Patient or Doctor cancels)
  - `InProgress` ➔ `Completed` (Doctor finalizes and prescribes)
- **Cancellation Rule:** Patient cancellations are blocked if the appointment scheduled time is less than 2 hours in the future (`CancellationNotAllowedException`).

### 4. Doctor Search & Multi-Attribute Filtering
- Dynamic searching by doctor name, specialty, bio keyword, minimum rating (e.g., ≥ 4.8), and fee threshold (e.g., ≤ $60).
- Explicit states for Skeleton Shimmer Loading, Empty Results with reset filters CTA, and Error/Retry views.

### 5. Role-Based Privacy & Security Guard
- Access to private video rooms, consultation chat, and prescriptions is strictly verified against participant IDs (`patientId` or `doctorId`).
- Unverified doctors cannot be discovered in public search until approved by an administrator.

### 6. Offline Resilient Data Store
- In-memory reactive local store (`MockDataStore`) paired with offline persistence allows continuous browsing of appointments and prescriptions even when disconnected, with a non-intrusive offline indicator.

### 7. Automated Testing Suite (31 Tests Passed)
- 31 automated unit and widget tests covering concurrency locking, race conditions, state transitions, timezone calculations, cancellation windows, search filters, and UI components.

---

## 3. Architecture & Directory Structure

Clean Architecture with Feature-First packaging:

```
lib/
├── app.dart                   # Root MaterialApp with theme & routing
├── main.dart                  # Application bootstrap (ProviderScope)
├── core/                      # Cross-cutting concerns
│   ├── data/                  # MockDataStore (reactive state & atomic transactions)
│   ├── errors/                # AppException hierarchy (SlotAlreadyBookedException, etc.)
│   ├── providers/             # Riverpod providers & dependency injection
│   ├── routing/               # Declarative GoRouter configuration
│   ├── theme/                 # AppTheme, AppColors, AppTypography
│   ├── utils/                 # DateTimeUtils & timezone helpers
│   └── widgets/               # StatusBadge, StateViews (Empty, Error, Shimmer, Offline)
└── features/
    ├── auth/                  # Authentication, Sign In, Registration, Role Dispatcher
    ├── patient/               # Discovery, Doctor Profile, Booking Engine, Appointments
    ├── doctor/                # Consultation Agenda, Requests Queue, Availability Setup
    ├── admin/                 # Doctor Verification Desk, Taxonomy, Platform Analytics
    ├── appointment/           # Domain models, repositories, State Machine
    └── consultation/          # Video Consultation Room, Chat, Digital Prescriptions
```

---

## 4. Running the Project

### Prerequisites
- Flutter SDK 3.13.0 or higher
- Android Studio / Xcode for emulators or physical devices

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run Static Analysis
```bash
flutter analyze
```
*(Expected output: No issues found!)*

### 3. Run Automated Tests
```bash
flutter test
```
*(Expected output: 31 tests passed!)*

### 4. Run the Application
```bash
flutter run
```

---

## 5. Automated Test Coverage Summary

```bash
00:01 +31: All tests passed!
```
- `test/unit/concurrency_booking_test.dart`: Single booking, slot locking, colliding attempts, concurrent race conditions, and rescheduling.
- `test/unit/state_machine_test.dart`: Valid lifecycle progression, doctor rejection, invalid jumps, and terminal state immutability.
- `test/unit/timezone_utils_test.dart`: ISO-8601 UTC storage, local conversion, slot key generation, and timezone formatting.
- `test/unit/cancellation_eligibility_test.dart`: 2-hour window rules, patient cancellation rejection, and doctor emergency cancellation.
- `test/unit/doctor_filtering_test.dart`: Verified filtering, specialty filtering, rating filtering, fee filtering, search keywords, and admin approval indexing.
- `test/unit/prescription_and_chat_test.dart`: Digital prescription attachment, medication items parsing, and encrypted chronological chat.
- `test/widget/widget_components_test.dart`: StatusBadge pills, EmptyStateView, ErrorStateView with retry, and OfflineBanner.

---

## 6. Known Limitations & Extensibility

- **Live Video SDK:** The app currently features a production-ready WebRTC/mock video room test harness with camera/mic controls, call duration timers, and access guards. For live production deployment, the harness is architected with a swappable interface to plug in Agora, Twilio, or LiveKit SDKs.
- **Push Notifications:** Firebase Cloud Messaging (FCM) handlers can be connected directly to the `AppointmentRepository` event streams.
