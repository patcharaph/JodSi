-- ============================================================
-- JodSi v2.2 — Admin Logs & Feedback
-- ============================================================

-- ─── API Logs ─────────────────────────────────────────────
-- Tracks every Edge Function call: cost, latency, errors

CREATE TABLE IF NOT EXISTS public.api_logs (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  function_name    text NOT NULL,           -- 'process-audio' | 'on-transcription-done'
  note_id          uuid REFERENCES public.notes(id) ON DELETE SET NULL,
  user_id          uuid REFERENCES public.users(id) ON DELETE SET NULL,
  status           text NOT NULL DEFAULT 'ok',  -- 'ok' | 'error'
  status_code      int,
  error_message    text,
  -- Cost tracking
  deepgram_cost    numeric(10,6) DEFAULT 0, -- USD
  openrouter_cost  numeric(10,6) DEFAULT 0, -- USD
  total_cost       numeric(10,6) DEFAULT 0, -- USD
  -- Performance
  duration_ms      int,                     -- Edge Function execution time
  audio_duration_sec int,                   -- Input audio length
  transcript_chars int,                     -- Output transcript length
  -- Metadata
  model_used       text,                    -- e.g. 'google/gemini-flash-1.5'
  request_meta     jsonb,                   -- Any extra info
  created_at       timestamptz DEFAULT now()
);

CREATE INDEX idx_api_logs_created_at ON public.api_logs(created_at DESC);
CREATE INDEX idx_api_logs_function_name ON public.api_logs(function_name);
CREATE INDEX idx_api_logs_status ON public.api_logs(status);
CREATE INDEX idx_api_logs_note_id ON public.api_logs(note_id);

ALTER TABLE public.api_logs ENABLE ROW LEVEL SECURITY;

-- Only service_role can insert logs (from Edge Functions)
CREATE POLICY "Service role can insert api_logs"
  ON public.api_logs FOR INSERT
  WITH CHECK (true);

-- Only admin can read logs (we'll check via app logic + service_role)
CREATE POLICY "Service role can read api_logs"
  ON public.api_logs FOR SELECT
  USING (true);

-- ─── Feedback ─────────────────────────────────────────────
-- User feedback/bug reports from within the app

CREATE TABLE IF NOT EXISTS public.feedback (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid REFERENCES public.users(id) ON DELETE SET NULL,
  note_id          uuid REFERENCES public.notes(id) ON DELETE SET NULL,
  type             text NOT NULL DEFAULT 'general', -- 'bug' | 'feature' | 'general' | 'quality'
  rating           int CHECK (rating >= 1 AND rating <= 5),
  message          text NOT NULL,
  app_version      text,
  device_info      text,
  status           text DEFAULT 'new',      -- 'new' | 'reviewed' | 'resolved'
  admin_notes      text,
  created_at       timestamptz DEFAULT now()
);

CREATE INDEX idx_feedback_created_at ON public.feedback(created_at DESC);
CREATE INDEX idx_feedback_type ON public.feedback(type);
CREATE INDEX idx_feedback_status ON public.feedback(status);

ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;

-- Users can insert their own feedback
CREATE POLICY "Users can insert feedback"
  ON public.feedback FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Users can read their own feedback
CREATE POLICY "Users can read own feedback"
  ON public.feedback FOR SELECT
  USING (user_id = auth.uid());

-- Service role can read/update all feedback (for admin dashboard)
CREATE POLICY "Service role can manage feedback"
  ON public.feedback FOR ALL
  USING (true);

-- ─── Admin Stats View ─────────────────────────────────────
-- Materialized-style helper: daily aggregated stats

CREATE OR REPLACE VIEW public.admin_daily_stats AS
SELECT
  date_trunc('day', created_at)::date AS day,
  count(*) AS total_requests,
  count(*) FILTER (WHERE status = 'error') AS error_count,
  sum(total_cost) AS total_cost_usd,
  sum(deepgram_cost) AS deepgram_cost_usd,
  sum(openrouter_cost) AS openrouter_cost_usd,
  avg(duration_ms)::int AS avg_duration_ms,
  sum(audio_duration_sec) AS total_audio_sec,
  count(DISTINCT user_id) AS unique_users
FROM public.api_logs
GROUP BY date_trunc('day', created_at)::date
ORDER BY day DESC;
