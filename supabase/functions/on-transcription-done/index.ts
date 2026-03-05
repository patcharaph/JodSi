import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const OPENROUTER_API_KEY = Deno.env.get("OPENROUTER_API_KEY")!;
const OPENROUTER_MODEL = Deno.env.get("OPENROUTER_MODEL") || "google/gemini-flash-1.5";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const WEBHOOK_SECRET = Deno.env.get("WEBHOOK_SECRET")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `คุณคือผู้ช่วยสรุปโน้ตภาษาไทย กรุณาสรุปข้อความถอดเสียงเป็น JSON ตาม schema นี้:

{
  "title": "ชื่อโน้ตสั้นๆ ภาษาไทย (ไม่เกิน 50 ตัวอักษร)",
  "key_takeaways": ["ประเด็นสำคัญ 1", "ประเด็นสำคัญ 2", "..."],
  "detail": "รายละเอียดเพิ่มเติมเป็นย่อหน้าภาษาไทย",
  "action_items": ["สิ่งที่ต้องทำ 1", "สิ่งที่ต้องทำ 2", "..."]
}

กฎ:
- ตอบเป็น JSON เท่านั้น ห้ามมี markdown
- key_takeaways: 3-7 ข้อ จับประเด็นหลัก
- detail: สรุปรายละเอียดเป็นย่อหน้า 2-4 ประโยค
- action_items: สิ่งที่ต้องทำ (ถ้ามี) ถ้าไม่มีให้ใส่ array ว่าง
- ใช้ภาษาไทยทั้งหมด (ยกเว้นคำศัพท์เทคนิค)

ตอบเป็น JSON เท่านั้น ห้ามครอบด้วย markdown code block`;

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Get note_id from query params (set by process-audio callback URL)
    const url = new URL(req.url);
    const noteId = url.searchParams.get("note_id");

    const secret = url.searchParams.get("secret");

    if (!noteId || !secret) {
      return new Response(
        JSON.stringify({ error: "note_id and secret query params are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify webhook secret to prevent unauthorized calls
    if (secret !== WEBHOOK_SECRET) {
      console.error("Invalid webhook secret for note:", noteId);
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Parse Deepgram webhook payload
    const deepgramResult = await req.json();
    console.log("Deepgram callback received for note:", noteId);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Extract transcript data from Deepgram response
    const channels = deepgramResult?.results?.channels;
    if (!channels || channels.length === 0) {
      console.error("No channels in Deepgram response");
      await supabase.from("notes").update({ status: "error" }).eq("id", noteId);
      return new Response(
        JSON.stringify({ error: "No transcription channels" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const alternative = channels[0].alternatives[0];
    const fullText = alternative.transcript || "";
    const paragraphs = alternative.paragraphs?.paragraphs || [];

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

    // Save transcript to DB
    await supabase.from("transcripts").insert({
      note_id: noteId,
      segments: segments,
      full_text: fullText,
      raw_response: deepgramResult,
    });

    // Update note status to summarizing
    await supabase
      .from("notes")
      .update({ status: "summarizing" })
      .eq("id", noteId);

    // Skip summarization if transcript is empty
    if (!fullText || fullText.trim().length === 0) {
      await supabase.from("summaries").insert({
        note_id: noteId,
        key_takeaways: [],
        detail: "ไม่พบเนื้อหาจากเสียง",
        action_items: [],
      });
      await supabase
        .from("notes")
        .update({ status: "done", title: "โน้ตเปล่า" })
        .eq("id", noteId);
      return new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ─── OpenRouter LLM Summarization ─────────────────

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
          { role: "user", content: `ข้อความถอดเสียง:\n${fullText}` },
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
      return new Response(
        JSON.stringify({ error: "OpenRouter request failed", details: errorText }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const openrouterResult = await openrouterResponse.json();
    const generatedText =
      openrouterResult?.choices?.[0]?.message?.content || "{}";

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

    return new Response(JSON.stringify({ success: true, note_id: noteId }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Error in on-transcription-done:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
