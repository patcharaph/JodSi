import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const OPENROUTER_API_KEY = Deno.env.get("OPENROUTER_API_KEY")!;
const OPENROUTER_MODEL = Deno.env.get("OPENROUTER_MODEL") || "google/gemini-2.0-flash-001";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY")!;
const WEBHOOK_SECRET = Deno.env.get("WEBHOOK_SECRET")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `You are a smart note summarizer. Summarize the transcript into JSON with this schema:

{
  "title": "Short note title (max 50 chars)",
  "key_takeaways": ["Key point 1", "Key point 2", "..."],
  "detail": "Detailed summary in 2-4 sentences",
  "action_items": ["Action 1", "Action 2", "..."]
}

Rules:
- Respond with JSON ONLY, no markdown wrapping
- key_takeaways: 3-7 key points
- detail: summary paragraph 2-4 sentences
- action_items: things to do (if any), empty array if none
- IMPORTANT: Reply in the SAME language as the transcript. If transcript is Thai, reply in Thai. If English, reply in English. If mixed, use the dominant language.
- Respond with JSON ONLY, no markdown code block`;

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  let noteId: string | null = null;
  let userId: string | null = null;

  try {
    // Get note_id from query params (set by process-audio callback URL)
    const url = new URL(req.url);
    noteId = url.searchParams.get("note_id");

    const secret = url.searchParams.get("secret");

    if (!noteId || !secret) {
      await logApiCall(supabase, {
        functionName: "on-transcription-done",
        noteId: null, userId: null,
        status: "error", statusCode: 400,
        errorMessage: "note_id and secret query params are required",
        durationMs: Date.now() - startTime,
      });
      return new Response(
        JSON.stringify({ error: "note_id and secret query params are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify webhook secret to prevent unauthorized calls
    if (secret !== WEBHOOK_SECRET) {
      console.error("Invalid webhook secret for note:", noteId);
      await logApiCall(supabase, {
        functionName: "on-transcription-done",
        noteId, userId: null,
        status: "error", statusCode: 401,
        errorMessage: "Invalid webhook secret",
        durationMs: Date.now() - startTime,
      });
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Fetch note to get user_id for logging
    const { data: noteData } = await supabase
      .from("notes")
      .select("user_id, duration_sec")
      .eq("id", noteId)
      .maybeSingle();
    userId = noteData?.user_id || null;
    const audioDurationSec = noteData?.duration_sec || null;

    // Parse Deepgram result payload (forwarded from process-audio)
    const rawBody = await req.text();
    console.log("[DEBUG] raw body length:", rawBody.length);
    console.log("[DEBUG] raw body preview:", rawBody.substring(0, 2000));
    let deepgramResult;
    try {
      deepgramResult = JSON.parse(rawBody);
    } catch (parseErr) {
      console.error("[DEBUG] JSON parse error:", parseErr);
      throw new Error(`Failed to parse body: ${parseErr}`);
    }
    console.log("Deepgram result received for note:", noteId);
    console.log("[DEBUG] deepgramResult top-level keys:", Object.keys(deepgramResult || {}));

    // Extract Deepgram cost from metadata
    const deepgramCost = deepgramResult?.metadata?.billing_info?.total_amount || 0;
    console.log("[DEBUG] deepgramCost:", deepgramCost);
    console.log("[DEBUG] deepgramResult keys:", Object.keys(deepgramResult || {}));
    console.log("[DEBUG] results keys:", Object.keys(deepgramResult?.results || {}));

    // Extract transcript data from Deepgram response
    const channels = deepgramResult?.results?.channels;
    console.log("[DEBUG] channels count:", channels?.length || 0);
    if (!channels || channels.length === 0) {
      console.error("No channels in Deepgram response");
      await supabase.from("notes").update({ status: "error" }).eq("id", noteId);
      await logApiCall(supabase, {
        functionName: "on-transcription-done",
        noteId, userId,
        status: "error", statusCode: 400,
        errorMessage: "No transcription channels in Deepgram response",
        deepgramCost,
        durationMs: Date.now() - startTime,
        audioDurationSec,
      });
      return new Response(
        JSON.stringify({ error: "No transcription channels" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const alternative = channels[0].alternatives[0];
    const fullText = alternative.transcript || "";
    const paragraphs = alternative.paragraphs?.paragraphs || [];
    console.log("[DEBUG] fullText length:", fullText.length);
    console.log("[DEBUG] fullText preview:", fullText.substring(0, 200));

    // Build segments from paragraphs/utterances
    const segments: Array<{ start: number; end: number; text: string }> = [];

    if (deepgramResult?.results?.utterances) {
      for (const utterance of deepgramResult.results.utterances) {
        segments.push({
          start: utterance.start,
          end: utterance.end,
          text: utterance.transcript,
        });
      }
    } else if (paragraphs.length > 0) {
      for (const para of paragraphs) {
        for (const sentence of para.sentences || []) {
          segments.push({
            start: sentence.start,
            end: sentence.end,
            text: sentence.text,
          });
        }
      }
    }

    console.log("[DEBUG] segments count:", segments.length);

    // Save transcript to DB
    console.log("[DEBUG] inserting transcript...");
    const { error: transcriptError } = await supabase.from("transcripts").insert({
      note_id: noteId,
      segments: segments,
      full_text: fullText,
      raw_response: deepgramResult,
    });
    if (transcriptError) {
      console.error("[DEBUG] transcript insert error:", JSON.stringify(transcriptError));
    } else {
      console.log("[DEBUG] transcript inserted OK");
    }

    // Update note status to summarizing
    await supabase
      .from("notes")
      .update({ status: "summarizing" })
      .eq("id", noteId);

    console.log("[DEBUG] note status updated to summarizing");

    // Skip summarization if transcript is empty
    if (!fullText || fullText.trim().length === 0) {
      console.log("[DEBUG] empty transcript — inserting empty summary...");
      const { error: sumErr } = await supabase.from("summaries").insert({
        note_id: noteId,
        key_takeaways: [],
        detail: "ไม่พบเนื้อหาจากเสียง",
        action_items: [],
      });
      console.log("[DEBUG] empty summary insert:", sumErr ? JSON.stringify(sumErr) : "OK");
      const { error: noteErr } = await supabase
        .from("notes")
        .update({ status: "done", title: "โน้ตเปล่า" })
        .eq("id", noteId);
      console.log("[DEBUG] note update to done:", noteErr ? JSON.stringify(noteErr) : "OK");

      await logApiCall(supabase, {
        functionName: "on-transcription-done",
        noteId, userId,
        status: "ok", statusCode: 200,
        deepgramCost, openrouterCost: 0,
        durationMs: Date.now() - startTime,
        audioDurationSec,
        transcriptChars: 0,
        modelUsed: "none (empty transcript)",
      });

      return new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ─── OpenRouter LLM Summarization ─────────────────

    console.log("[DEBUG] calling OpenRouter with model:", OPENROUTER_MODEL);
    const openrouterResponse = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${OPENROUTER_API_KEY}`,
        "HTTP-Referer": "https://jodsi.app",
        "X-Title": "JodSi",
      },
      body: JSON.stringify({
        model: OPENROUTER_MODEL,
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: `Transcript:\n${fullText}` },
        ],
        temperature: 0.3,
        top_p: 0.8,
        max_tokens: 2048,
        response_format: { type: "json_object" },
      }),
    });

    if (!openrouterResponse.ok) {
      const errorText = await openrouterResponse.text();
      console.error("OpenRouter error:", errorText);
      await supabase.from("notes").update({ status: "error" }).eq("id", noteId);

      await logApiCall(supabase, {
        functionName: "on-transcription-done",
        noteId, userId,
        status: "error", statusCode: openrouterResponse.status,
        errorMessage: `OpenRouter: ${errorText}`,
        deepgramCost, openrouterCost: 0,
        durationMs: Date.now() - startTime,
        audioDurationSec,
        transcriptChars: fullText.length,
        modelUsed: OPENROUTER_MODEL,
      });

      return new Response(
        JSON.stringify({ error: "OpenRouter request failed", details: errorText }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log("[DEBUG] OpenRouter response OK, parsing...");
    const openrouterResult = await openrouterResponse.json();
    const generatedText =
      openrouterResult?.choices?.[0]?.message?.content || "{}";

    // Extract OpenRouter cost from usage
    const openrouterCost = openrouterResult?.usage?.total_cost || 0;

    let summary;
    try {
      summary = JSON.parse(generatedText);
    } catch {
      console.error("Failed to parse LLM JSON:", generatedText);
      summary = {
        title: "โน้ตไม่มีชื่อ",
        key_takeaways: [],
        detail: generatedText,
        action_items: [],
      };
    }

    // Save summary to DB
    await supabase.from("summaries").insert({
      note_id: noteId,
      key_takeaways: summary.key_takeaways || [],
      detail: summary.detail || "",
      action_items: summary.action_items || [],
    });

    // Update note with title and status = done
    await supabase
      .from("notes")
      .update({
        status: "done",
        title: summary.title || "โน้ตไม่มีชื่อ",
      })
      .eq("id", noteId);

    console.log("Processing complete for note:", noteId);

    await logApiCall(supabase, {
      functionName: "on-transcription-done",
      noteId, userId,
      status: "ok", statusCode: 200,
      deepgramCost,
      openrouterCost,
      durationMs: Date.now() - startTime,
      audioDurationSec,
      transcriptChars: fullText.length,
      modelUsed: OPENROUTER_MODEL,
    });

    return new Response(JSON.stringify({ success: true, note_id: noteId }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: unknown) {
    const errMsg = error instanceof Error ? error.message : String(error);
    console.error("Error in on-transcription-done:", errMsg);

    await logApiCall(supabase, {
      functionName: "on-transcription-done",
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
  openrouterCost?: number;
  durationMs: number;
  audioDurationSec?: number | null;
  transcriptChars?: number;
  modelUsed?: string;
  requestMeta?: Record<string, unknown>;
}

async function logApiCall(supabase: ReturnType<typeof createClient>, params: LogParams) {
  try {
    const totalCost = (params.deepgramCost || 0) + (params.openrouterCost || 0);
    await supabase.from("api_logs").insert({
      function_name: params.functionName,
      note_id: params.noteId,
      user_id: params.userId,
      status: params.status,
      status_code: params.statusCode,
      error_message: params.errorMessage || null,
      deepgram_cost: params.deepgramCost || 0,
      openrouter_cost: params.openrouterCost || 0,
      total_cost: totalCost,
      duration_ms: params.durationMs,
      audio_duration_sec: params.audioDurationSec || null,
      transcript_chars: params.transcriptChars || null,
      model_used: params.modelUsed || null,
      request_meta: params.requestMeta || null,
    });
  } catch (e) {
    console.error("Failed to log API call:", e);
  }
}
