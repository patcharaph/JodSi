import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const DEEPGRAM_API_KEY = Deno.env.get("DEEPGRAM_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY")!;
const WEBHOOK_SECRET = Deno.env.get("WEBHOOK_SECRET")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  let noteId: string | null = null;
  let userId: string | null = null;

  try {
    const { note_id, audio_url } = await req.json();
    noteId = note_id;

    if (!note_id || !audio_url) {
      await logApiCall(supabase, {
        functionName: "process-audio",
        noteId: null, userId: null,
        status: "error", statusCode: 400,
        errorMessage: "note_id and audio_url are required",
        durationMs: Date.now() - startTime,
      });
      return new Response(
        JSON.stringify({ error: "note_id and audio_url are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Fetch note to get user_id for logging
    const { data: noteData } = await supabase
      .from("notes")
      .select("user_id")
      .eq("id", note_id)
      .maybeSingle();
    userId = noteData?.user_id || null;

    // Update note status to transcribing
    await supabase
      .from("notes")
      .update({ status: "transcribing" })
      .eq("id", note_id);

    // Fetch audio binary from Supabase Storage
    console.log("[DEBUG] Fetching audio from:", audio_url);
    const audioResponse = await fetch(audio_url);
    if (!audioResponse.ok) {
      const errText = await audioResponse.text();
      console.error("[DEBUG] Failed to fetch audio:", audioResponse.status, errText);
      await supabase.from("notes").update({ status: "error" }).eq("id", note_id);
      await logApiCall(supabase, {
        functionName: "process-audio",
        noteId: note_id, userId,
        status: "error", statusCode: audioResponse.status,
        errorMessage: `Failed to fetch audio: ${errText}`,
        durationMs: Date.now() - startTime,
      });
      return new Response(
        JSON.stringify({ error: "Failed to fetch audio" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    const audioBuffer = await audioResponse.arrayBuffer();
    console.log("[DEBUG] Audio fetched, size:", audioBuffer.byteLength, "bytes");

    // Send audio binary directly to Deepgram (synchronous — no callback)
    const deepgramUrl = new URL("https://api.deepgram.com/v1/listen");
    deepgramUrl.searchParams.set("model", "nova-3");
    deepgramUrl.searchParams.set("detect_language", "true");
    deepgramUrl.searchParams.set("punctuate", "true");
    deepgramUrl.searchParams.set("paragraphs", "true");
    deepgramUrl.searchParams.set("utterances", "true");
    deepgramUrl.searchParams.set("smart_format", "true");

    console.log("[DEBUG] Sending audio to Deepgram (sync mode)...");
    const deepgramResponse = await fetch(deepgramUrl.toString(), {
      method: "POST",
      headers: {
        Authorization: `Token ${DEEPGRAM_API_KEY}`,
        "Content-Type": "audio/wav",
      },
      body: new Uint8Array(audioBuffer),
    });

    if (!deepgramResponse.ok) {
      const errorText = await deepgramResponse.text();
      console.error("Deepgram error:", errorText);

      await supabase
        .from("notes")
        .update({ status: "error" })
        .eq("id", note_id);

      await logApiCall(supabase, {
        functionName: "process-audio",
        noteId: note_id, userId,
        status: "error", statusCode: deepgramResponse.status,
        errorMessage: `Deepgram: ${errorText}`,
        durationMs: Date.now() - startTime,
      });

      return new Response(
        JSON.stringify({ error: "Deepgram request failed", details: errorText }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const deepgramResult = await deepgramResponse.json();
    console.log("[DEBUG] Deepgram response metadata:", JSON.stringify(deepgramResult?.metadata || {}).substring(0, 500));
    console.log("[DEBUG] Deepgram model_info:", JSON.stringify(deepgramResult?.metadata?.model_info || {}));
    const channels = deepgramResult?.results?.channels;
    if (channels && channels.length > 0) {
      const alt = channels[0].alternatives[0];
      console.log("[DEBUG] detected_language:", channels[0].detected_language);
      console.log("[DEBUG] language_confidence:", channels[0].language_confidence);
      console.log("[DEBUG] transcript confidence:", alt?.confidence);
      console.log("[DEBUG] words count:", alt?.words?.length || 0);
    }
    const transcript = deepgramResult?.results?.channels?.[0]?.alternatives?.[0]?.transcript || "";
    console.log("[DEBUG] Deepgram sync result, transcript length:", transcript.length);
    console.log("[DEBUG] Deepgram transcript preview:", transcript.substring(0, 200));

    // Forward result to on-transcription-done
    const callbackUrl = `${SUPABASE_URL}/functions/v1/on-transcription-done?note_id=${note_id}&secret=${WEBHOOK_SECRET}`;
    console.log("[DEBUG] Forwarding to on-transcription-done...");
    const callbackResponse = await fetch(callbackUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(deepgramResult),
    });
    console.log("[DEBUG] on-transcription-done response:", callbackResponse.status);

    await logApiCall(supabase, {
      functionName: "process-audio",
      noteId: note_id, userId,
      status: "ok", statusCode: 200,
      durationMs: Date.now() - startTime,
    });

    return new Response(
      JSON.stringify({ success: true, note_id }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: unknown) {
    const errMsg = error instanceof Error ? error.message : String(error);
    console.error("Error in process-audio:", errMsg);

    await logApiCall(supabase, {
      functionName: "process-audio",
      noteId, userId,
      status: "error", statusCode: 500,
      errorMessage: errMsg,
      durationMs: Date.now() - startTime,
    }).catch(() => {});

    return new Response(
      JSON.stringify({ error: errMsg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

// ─── Logging Helper ───────────────────────────────────────
interface LogParams {
  functionName: string;
  noteId: string | null;
  userId: string | null;
  status: string;
  statusCode: number;
  errorMessage?: string;
  deepgramCost?: number;
  durationMs: number;
  audioDurationSec?: number;
  requestMeta?: Record<string, unknown>;
}

async function logApiCall(supabase: ReturnType<typeof createClient>, params: LogParams) {
  try {
    await supabase.from("api_logs").insert({
      function_name: params.functionName,
      note_id: params.noteId,
      user_id: params.userId,
      status: params.status,
      status_code: params.statusCode,
      error_message: params.errorMessage || null,
      deepgram_cost: params.deepgramCost || 0,
      total_cost: params.deepgramCost || 0,
      duration_ms: params.durationMs,
      audio_duration_sec: params.audioDurationSec || null,
      request_meta: params.requestMeta || null,
    });
  } catch (e) {
    console.error("Failed to log API call:", e);
  }
}
