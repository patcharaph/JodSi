# JodSi (จดสิ) 📝🎙️

AI Voice-to-Note สำหรับคนไทย — เปิดแอป อัดเสียง ได้โน้ตสรุปสวยๆ

## Features

- **One-tap Recording** — กดปุ่มเดียว อัดได้ทันที พร้อม Real-time Amplitude bar
- **Thai Transcription** — Deepgram Nova-2 รองรับไทย + Thaiglish
- **AI Summary** — OpenRouter (LLM gateway) สรุป Key Takeaways + Detail + Action Items
- **Copy & Share** — กดปุ่มเดียว Copy ไปใช้งานต่อ
- **Anonymous-First** — ใช้ก่อน สมัครทีหลัง ไม่มี Login Wall

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter (Dart) |
| Backend | Supabase (Auth + DB + Storage + Edge Functions + Realtime) |
| Speech-to-Text | Deepgram Nova-2 |
| Summarization | OpenRouter → Gemini / GPT / Claude (เลือกได้) |
| Database | PostgreSQL (Supabase) |

## Project Structure

```
lib/
├── main.dart                       # App entry point
├── core/
│   ├── config/                     # App & Supabase config
│   ├── router/                     # GoRouter navigation
│   └── theme/                      # App theme & design tokens
├── data/
│   ├── models/                     # Data models (Note, Transcript, Summary, etc.)
│   └── services/                   # Auth, DB, Storage, Recording, Processing
├── providers/                      # Riverpod state management
└── ui/
    ├── screens/                    # RecorderScreen, ProcessingScreen, etc.
    └── widgets/                    # AmplitudeVisualizer, LinkAccountSheet

supabase/
├── config.toml                     # Supabase project config
├── migrations/
│   └── 00001_initial_schema.sql    # Database schema + RLS policies
└── functions/
    ├── process-audio/              # Edge Function: upload → Deepgram
    └── on-transcription-done/      # Edge Function: Deepgram callback → OpenRouter LLM → DB
```

## Setup

### 1. Prerequisites

- Flutter SDK (3.10+)
- Supabase account
- Deepgram API key
- OpenRouter API key (https://openrouter.ai)

### 2. Supabase Setup

```bash
# Create a Supabase project at https://supabase.com

# Run the migration in Supabase SQL Editor
# Copy contents of supabase/migrations/00001_initial_schema.sql

# Enable Anonymous Sign-Ins:
# Dashboard → Authentication → Settings → Enable Anonymous Sign-Ins

# Set Edge Function secrets:
supabase secrets set DEEPGRAM_API_KEY=your-key
supabase secrets set OPENROUTER_API_KEY=your-key
supabase secrets set OPENROUTER_MODEL=google/gemini-flash-1.5  # หรือเปลี่ยนเป็นโมเดลอื่น

# Deploy Edge Functions:
supabase functions deploy process-audio
supabase functions deploy on-transcription-done
```

### 3. Flutter Setup

```bash
# Copy environment file
cp .env.example .env
# Fill in your Supabase URL and Anon Key

# Update lib/core/config/app_config.dart with your Supabase credentials
# Or pass them as dart-define:
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### 4. Android Permissions

Microphone permission is already configured. For release builds, ensure `android/app/src/main/AndroidManifest.xml` includes:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

### 5. iOS Permissions

Add to `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>JodSi needs microphone access to record voice notes</string>
```

## Processing Pipeline

```
Flutter (record .m4a)
  → Supabase Storage (upload)
  → Edge Function [process-audio]
  → Deepgram Nova-2 (transcribe, with callback URL)
  → Edge Function [on-transcription-done] (webhook)
  → OpenRouter LLM (summarize, default: gemini-flash-1.5)
  → PostgreSQL (save results)
  → Supabase Realtime → Flutter (display)
```

## License

Private — All rights reserved.
