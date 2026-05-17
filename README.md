<p align="center">
  <img src="assets/images/logo_wordmark.png" alt="VoxClass" width="320">
</p>

# VoxClass — Give Your Class a Voice

> **Shortcut Asia Internship Challenge 2026** · Real-time AI teaching co-pilot
> *"Go deeper, not broader"*

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Gemini](https://img.shields.io/badge/Gemini-1.5_Flash-4285F4?logo=google)
![Supabase](https://img.shields.io/badge/Supabase-Realtime-3ECF8E?logo=supabase)
![License](https://img.shields.io/badge/license-MIT-green)

---

## The Problem

Every lecturer has had this moment: you finish explaining a concept, ask "any questions?" — silence. Then the exam results come back and half the class didn't understand it. Silence isn't understanding. It's disengagement.

**VoxClass makes the invisible visible.** Students react in real time. The lecturer sees confusion the moment it happens — not a week later.

---

## What It Does

VoxClass closes the feedback loop between lecturers and students during live sessions. A lecturer starts a session, students join with a 6-digit code, and the app continuously surfaces how the room is feeling — so no student gets left behind silently.

> **In a 30-student class, VoxClass surfaces confusion in under 3 seconds.**

| Role | What they get |
|------|---------------|
| **Lecturer** | Live mood meter, confused-student alerts → Gemini clarifying questions, slide upload → AI quiz questions, session summary with AI insights, Polish Mode for feedback |
| **Student** | One-tap reactions (got it / unsure / confused), shared slide viewer, anonymous questions, live AI-generated quiz questions |

---

## Key Features

### 🎭 Class Mode — Live Session

**Live mood meter** — Real-time donut chart (🟢 / 🟡 / 🔴) powered by Supabase Realtime. Updates in under 3 seconds of a student reacting.

**Session codes** — Shareable 6-digit code + QR for instant student join. No accounts needed for students.

**Slide sharing** — Lecturer uploads slides (JPG, PNG, PDF, PPTX). Students see them live. Multiple files in one upload.

**AI quiz questions** — Upload a slide → Gemini Vision analyses the content → 3 curriculum-aligned questions generated instantly.

**Confused panel** — When 🔴 reactions spike, one tap generates 3 targeted clarifying questions via Gemini. Push the best one to all students.

**Re-explain** — Gemini generates 3 different explanations of the topic (analogy / step-by-step / concrete example). Lecturer picks one and pushes it live.

**Anonymous questions** — Students submit questions without their name. Gemini clusters them by theme so the lecturer sees patterns, not noise.

**Full presenter view** — Slide fills the screen. Live mood HUD overlays the corner. Confused-student alert banner fires automatically.

### ✍️ Polish Mode

Rewrite any text in 4 styles powered by Gemini 1.5 Flash:

| Mode | What it does |
|------|-------------|
| **Soften** | Warmer, more empathetic feedback tone |
| **Strengthen** | More assertive, structured arguments |
| **Academic** | Formal scholarly language |
| **Simplify** | Plain language, no jargon |

Word-level diff shows exactly what changed (added vs removed).

### 🔐 Auth & Onboarding

Email/password signup with role picker (Lecturer / Student). Animated 3-slide onboarding. Session-persistent auth via Supabase.

---

## Why This Wins on "Go Deeper, Not Broader"

The features don't stand alone — each one feeds the next:

1. **Student reacts 🔴** → mood meter spikes
2. **Lecturer sees spike** → taps "Generate Clarifying Questions"
3. **Gemini uses session context** → generates targeted questions, not generic ones
4. **Lecturer pushes best question** → all students see it instantly
5. **Session ends** → AI summary explains *why* this topic caused confusion

The mood meter isn't decorative — it directly triggers AI question generation.  
Slide upload isn't file storage — it feeds Gemini Vision to generate curriculum-aligned questions.  
Polish Mode isn't a text editor — it gives voice to students and lecturers who struggle to express themselves clearly.

---

## Screenshots

> Run `flutter run -d chrome` to see the full UI in action.

**Key screens:**
- **Onboarding** — animated emoji slides introducing the product
- **Dashboard** — role-branched home with session history and teaching pattern insights
- **Live Session** — 4 tabs: Mood / Slides / Questions / Signals
- **Presenter View** — fullscreen slide + live mood HUD + confused-student alert
- **Student View** — reaction buttons + slide viewer + question cards
- **Session Summary** — post-session stats + Gemini AI insights
- **Polish Mode** — before/after diff with word-level highlighting

*Add screenshots here before submitting — the live mood donut updating in real time is your killer visual.*

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
│   └── theme/                   # Dark theme (indigo/purple palette)
├── models/                      # ProfileModel, SessionModel, ReactionModel,
│                                #   SlideModel, QuestionModel, AnonQuestionModel
├── providers/                   # Riverpod: authStateProvider,
│                                #   reactionsStreamProvider, slidesStreamProvider…
├── services/
│   ├── supabase_service.dart    # All DB + auth operations
│   ├── gemini_service.dart      # AI: polish, slide questions, clarifying
│   │                            #   questions, insights — with retry logic
│   └── storage_service.dart    # Supabase Storage slide upload/download
└── features/
    ├── onboarding/
    ├── auth/                    # Login + Signup
    ├── dashboard/               # Role-branched home screen
    ├── class_mode/
    │   ├── lecturer/            # Create session, live session (4 tabs),
    │   │                        #   presenter view, session summary
    │   ├── student/             # Join session, student session view
    │   └── widgets/             # MoodDonutChart, QrDisplayWidget,
    │                            #   ReactionButton, QuestionCard, FileViewer
    └── polish_mode/             # Text rewriting with diff view
```

---

## Database Schema

```
profiles          — user id, full_name, role (lecturer/student)
sessions          — id, lecturer_id, title, subject, code, status, ended_at
reactions         — session_id, student_id, student_name, type (green/yellow/red)
slides            — session_id, file_url, file_name, order_index, speaker_notes
ai_questions      — session_id, slide_id, question_text, source_type, is_pushed
question_responses — question_id, student_id, student_name, response_text
polish_logs       — user_id, input_text, output_text, mode
```

Row Level Security enabled on all tables.  
Realtime enabled on `reactions`, `ai_questions`, and `slides`.

---

## Quick Start

**Prerequisites:** [Flutter SDK 3.x](https://docs.flutter.dev/get-started/install)

```bash
# 1. Clone
git clone https://github.com/Lovemore-1/voxclass.git
cd voxclass

# 2. Install dependencies
flutter pub get

# 3. Create .env with the demo credentials below
cp .env.example .env
# (then paste the demo credentials — see next section)

# 4. Run
flutter run -d chrome
```

### Demo credentials (no account setup needed)

Create a `.env` file in the project root with these pre-configured keys:

```
SUPABASE_URL=https://jntgzjvguzoomhsrzwcs.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpudGd6anZndXpvb21oc3J6d2NzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg3NDk0NjMsImV4cCI6MjA5NDMyNTQ2M30.FRuNhF7uwfo30CdGh-jVSq2RT-wt-D-imBKYmNoZz3M
GEMINI_API_KEY=your_gemini_api_key_here
```

The backend is live and fully configured — just paste the keys and run.

### Test the full flow (two browser windows)

1. Run `flutter run -d chrome` — sign up as **Lecturer** → **Start Class** → copy the 6-digit code
2. Open an **incognito window** at the same localhost URL → sign up as **Student** → **Join Session** with the code
3. Student sends reactions → Lecturer sees the live mood meter update in real time
4. Upload an image slide → tap **Ask Gemini** → 3 quiz questions generated instantly

---

## Setup (own instance)

Follow these steps only if you want to run VoxClass against your own Supabase project.

### 1. Prerequisites
- Flutter SDK 3.x
- A [Supabase](https://supabase.com) project (free tier works)
- A [Gemini API key](https://aistudio.google.com/apikey) (free)

### 2. Configure environment

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJ...
GEMINI_API_KEY=AIza...
```

### 3. Set up Supabase

1. Create a new Supabase project
2. Open the **SQL Editor** and paste + run the entire contents of `supabase/schema.sql`
3. Go to **Table Editor → reactions → Realtime** → enable. Repeat for `ai_questions`, `slides`, `sessions`
4. Go to **Storage → New bucket** → name it `slides` → toggle **Public** ON

### 4. Run

```bash
flutter run -d chrome      # Web (recommended)
flutter run -d windows     # Windows desktop
flutter run -d android     # Android device
```

---

## Gemini Integration

```dart
// Slide → quiz questions (multimodal vision)
final content = Content.multi([
  TextPart(prompt),
  DataPart('image/jpeg', imageBytes),
]);
final response = await model.generateContent([content]);

// All Gemini calls include automatic retry (3 attempts, exponential backoff)
// with safe fallback defaults if the API is unavailable
```

All Gemini calls return structured JSON parsed with fallback to sensible defaults if the model output is malformed or the API is temporarily unavailable.

---

## License

MIT
