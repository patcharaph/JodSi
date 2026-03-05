import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const GEMINI_PROMPT = `คุณคือผู้ช่วยสรุปโน้ตภาษาไทย จากข้อความถอดเสียงด้านล่าง กรุณาสรุปเป็น JSON ตาม schema นี้:

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

ข้อความถอดเสียง:
`;

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Get note_id from query params (set by process-audio callback URL)
    const url = new URL(req.url);
    const noteId = url.searchParams.get("note_id");

    if (!noteId) {
      return new Response(
        JSON.stringify({ error: "note_id query param is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
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

    // ─── Gemini Summarization ──────────────────────────

    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`;

    const geminiResponse = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            parts: [{ text: GEMINI_PROMPT + fullText }],
          },
        ],
        generationConfig: {
          temperature: 0.3,
          topP: 0.8,
          maxOutputTokens: 2048,
          responseMimeType: "application/json",
        },
      }),
    });

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text();
      console.error("Gemini error:", errorText);
      await supabase.from("notes").update({ status: "error" }).eq("id", noteId);
      return new Response(
        JSON.stringify({ error: "Gemini request failed", details: errorText }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const geminiResult = await geminiResponse.json();
    const generatedText =
      geminiResult?.candidates?.[0]?.content?.parts?.[0]?.text || "{}";

    let summary;
    try {
      summary = JSON.parse(generatedText);
    } catch {
      console.error("Failed to parse Gemini JSON:", generatedText);
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
