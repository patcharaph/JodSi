-- ============================================================
-- JodSi v2.1 — Initial Database Schema
-- ============================================================

-- ─── Users ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.users (
  id               uuid PRIMARY KEY,            -- Supabase Auth UID
  display_name     text,                         -- NULL if Anonymous
  avatar_url       text,                         -- NULL if Anonymous
  is_anonymous     boolean DEFAULT true,          -- v2.1: Anonymous-First
  plan             text DEFAULT 'free',
  usage_min_month  int DEFAULT 0,
  created_at       timestamptz DEFAULT now()
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON public.users FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "Users can update own profile"
  ON public.users FOR UPDATE
  USING (id = auth.uid());

CREATE POLICY "Users can insert own profile"
  ON public.users FOR INSERT
  WITH CHECK (id = auth.uid());

-- ─── Notes ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.notes (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid REFERENCES public.users(id) ON DELETE CASCADE,
  title            text,
  audio_url        text,
  duration_sec     int,
  status           text DEFAULT 'recording',
  bookmarks        jsonb DEFAULT '[]'::jsonb,
  created_at       timestamptz DEFAULT now()
);

CREATE INDEX idx_notes_user_id ON public.notes(user_id);
CREATE INDEX idx_notes_status ON public.notes(status);

ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see own notes"
  ON public.notes FOR ALL
  USING (user_id = auth.uid());

-- ─── Transcripts ────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.transcripts (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id          uuid REFERENCES public.notes(id) ON DELETE CASCADE,
  segments         jsonb,               -- [{start, end, text}]
  full_text        text,
  raw_response     jsonb
);

CREATE INDEX idx_transcripts_note_id ON public.transcripts(note_id);

ALTER TABLE public.transcripts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see own transcripts"
  ON public.transcripts FOR SELECT
  USING (
    note_id IN (
      SELECT id FROM public.notes WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Service role can insert transcripts"
  ON public.transcripts FOR INSERT
  WITH CHECK (true);

-- ─── Summaries ──────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.summaries (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id          uuid REFERENCES public.notes(id) ON DELETE CASCADE,
  key_takeaways    jsonb,               -- [string]
  detail           text,
  action_items     jsonb                -- [string]
);

CREATE INDEX idx_summaries_note_id ON public.summaries(note_id);

ALTER TABLE public.summaries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see own summaries"
  ON public.summaries FOR SELECT
  USING (
    note_id IN (
      SELECT id FROM public.notes WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Service role can insert summaries"
  ON public.summaries FOR INSERT
  WITH CHECK (true);

-- ─── Storage Bucket ─────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public)
VALUES ('audio', 'audio', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Users can upload own audio"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'audio'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "Users can read own audio"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'audio'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "Users can delete own audio"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'audio'
    AND auth.role() = 'authenticated'
  );

-- ─── Realtime ───────────────────────────────────────────────
-- Enable realtime for notes table so Flutter can listen for status changes

ALTER PUBLICATION supabase_realtime ADD TABLE public.notes;

-- ─── Anonymous Cleanup (pg_cron) ────────────────────────────
-- Run this manually in Supabase SQL Editor after enabling pg_cron extension:
--
-- SELECT cron.schedule(
--   'cleanup-anonymous-users',
--   '0 3 * * *',  -- Every day at 3 AM UTC
--   $$
--   DELETE FROM public.users
--   WHERE is_anonymous = true
--     AND created_at < now() - interval '90 days';
--   $$
-- );
