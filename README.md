# VoxClass — Give Your Class a Voice

> **Shortcut Asia Internship Challenge 2026** — Cross-platform Flutter app that makes every classroom smarter with real-time mood tracking, AI-generated questions, and instant student feedback.

---

## What It Does

VoxClass bridges the gap between lecturers and students in real time. A lecturer starts a session, students join with a 6-digit code, and the app continuously surfaces how the room is feeling — so no student gets left behind silently.

| Role | What they get |
|------|--------------|
| **Lecturer** | Live mood donut chart, slide upload → AI quiz questions, confused-student alerts → Gemini clarifying questions, session summary with AI insights |
| **Student** | One-tap reactions (got it / unsure / confused), view shared slides, answer AI-generated questions live |

---

## Features

### Class Mode
- **Live mood meter** — real-time donut chart (green / amber / red) powered by Supabase Realtime streams
- **Session codes** — shareable 6-digit code + QR code for instant student join
- **Slide sharing** — lecturer uploads JPG/PNG slides, students see them live
- **AI quiz questions** — upload a slide → Gemini Vision analyses it → 3 quiz questions generated instantly
- **Confused panel** — when 🔴 reactions spike, one tap generates 3 targeted clarifying questions via Gemini
- **Push to students** — lecturer picks a question and pushes it; all students see it and can respond
- **Session summary** — post-session stats + AI-generated insights

### Polish Mode
Rewrite any text in 4 styles powered by Gemini 1.5 Flash:
- **Soften** — warmer, more empathetic tone
- **Strengthen** — more assertive and direct
- **Academic** — formal, scholarly language
- **Simplify** — plain language, no jargon

Word-level diff view shows exactly what changed (lime = added, red = removed).

### Auth & Onboarding
- Email/password signup with role picker (Lecturer / Student)
- Animated 3-slide onboarding
- Session-persistent auth with Supabase

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Framework** | Flutter 3.x (Dart) — Android, iOS, Windows, macOS, Linux, Web |
| **AI** | Google Gemini 1.5 Flash (text + vision multimodal) |
| **Backend** | Supabase (Auth + PostgreSQL + Realtime + Storage) |
| **State** | Riverpod 2.x (StreamProvider, FutureProvider) |
| **Navigation** | go_router 14.x with auth redirect |
| **Charts** | fl_chart (animated PieChart) |
| **QR** | qr_flutter |
| **Animations** | flutter_animate |

---

## Architecture

```
lib/
├── main.dart                    # App entry — loads .env, inits Supabase
├── app.dart                     # MaterialApp.router + theme
├── core/
│   ├── constants.dart           # .env key accessors
│   ├── router.dart              # go_router + auth redirect notifier
│   └── theme/                   # Dark theme (black/lime/purple)
├── models/                      # ProfileModel, SessionModel, ReactionModel, SlideModel, QuestionModel
├── providers/                   # Riverpod: authStateProvider, reactionsStreamProvider, etc.
├── services/
│   ├── supabase_service.dart    # All DB + auth operations
│   ├── gemini_service.dart      # AI: polish, slide questions, clarifying questions, insights
│   └── storage_service.dart    # Supabase Storage slide upload/download
└── features/
    ├── onboarding/
    ├── auth/                    # Login + Signup
    ├── dashboard/               # Role-branched home screen
    ├── class_mode/
    │   ├── lecturer/            # Create session, live session (4 tabs), summary
    │   ├── student/             # Join session, student view
    │   └── widgets/             # MoodDonutChart, QrDisplayWidget, ReactionButton, QuestionCard
    └── polish_mode/             # Text rewriting with diff view
```

---

## Database Schema

```
profiles        — user id, full_name, role (lecturer/student)
sessions        — id, lecturer_id, title, subject, code, status, ended_at
reactions       — session_id, student_id, student_name, type (green/yellow/red)
slides          — session_id, file_url, file_name, order_index
ai_questions    — session_id, slide_id, question_text, source_type, is_pushed
question_responses — question_id, student_id, student_name, response_text
polish_logs     — user_id, input_text, output_text, mode
```

Row Level Security is enabled on all tables. Realtime is enabled on `reactions`, `ai_questions`, and `slides`.

---

## Setup

### 1. Prerequisites
- Flutter SDK 3.x
- A [Supabase](https://supabase.com) project
- A [Gemini API key](https://aistudio.google.com/apikey)
- Windows: Developer Mode enabled (Settings → System → For Developers)

### 2. Clone & install
```bash
git clone https://github.com/your-username/voxclass.git
cd voxclass
flutter pub get
```

### 3. Configure environment
Copy `.env.example` to `.env` and fill in your keys:
```bash
cp .env.example .env
```
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJ...
GEMINI_API_KEY=AIza...
```

### 4. Set up Supabase
1. Create a new Supabase project
2. Open the SQL Editor and run the contents of `supabase/schema.sql`
3. Go to **Table Editor → reactions / ai_questions / slides** → enable **Realtime**
4. Go to **Storage** → create a bucket named `slides` (set to **public**)

### 5. Run
```bash
# Web (Chrome) — no extra setup
flutter run -d chrome

# Windows desktop
flutter run -d windows

# Android (device connected)
flutter run -d android
```

---

## Gemini Integration Highlights

```dart
// Slide → quiz questions (multimodal)
final content = Content.multi([
  TextPart(prompt),
  DataPart('image/jpeg', imageBytes),
]);
final response = await model.generateContent([content]);

// Confused students → clarifying questions
// Session summary → AI insights
// Polish Mode → 4 text rewriting styles
```

All Gemini calls return structured JSON which is parsed with a fallback to default questions if the model output is malformed.

---

## Screenshots

> Run `flutter run -d chrome` and open the app to see the full UI.

Key screens:
- **Onboarding** — animated emoji slides
- **Dashboard** — role-branched with session history
- **Live Session** — 4 tabs: Mood / Slides / Questions / Confused
- **Student View** — reaction buttons + slide viewer + question cards
- **Polish Mode** — before/after diff with word-level highlighting

---

## Shortcut Asia Challenge Context

VoxClass was built for the **Shortcut Asia 2026 Open Call** around the theme *"go deeper, not broader."* Rather than listing features, each feature is tightly integrated:

- The mood meter isn't decorative — it directly triggers AI question generation
- Slide upload isn't file storage — it feeds Gemini Vision to generate curriculum-aligned questions
- Polish Mode isn't a text editor — it gives voice to students and lecturers who struggle to express themselves clearly

The entire app runs cross-platform from a single codebase, with no native code beyond platform boilerplate.

---

## License

MIT
