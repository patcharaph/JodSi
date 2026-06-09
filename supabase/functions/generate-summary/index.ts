import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const OPENROUTER_API_KEY = Deno.env.get("OPENROUTER_API_KEY")!;
const OPENROUTER_MODEL = Deno.env.get("OPENROUTER_MODEL") || "google/gemini-2.0-flash-001";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY")!;

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

  try {
    const { note_id, full_text, segments } = await req.json();

    if (!note_id || full_text === undefined) {
      return new Response(
        JSON.stringify({ error: "note_id and full_text are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Save transcript
    await supabase.from("transcripts").insert({
      note_id,
      segments: segments ?? [],
      full_text,
    });

    // Handle empty transcript
    if (!full_text || full_text.trim().length === 0) {
      await supabase.from("summaries").insert({
        note_id,
        key_takeaways: [],
        detail: "ไม่พบเนื้อหาจากเสียง",
        action_items: [],
      });
      await supabase
        .from("notes")
        .update({ status: "done", title: "โน้ตเปล่า" })
        .eq("id", note_id);
      return new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Generate summary via OpenRouter
    const openrouterResponse = await fetch(
      "https://openrouter.ai/api/v1/chat/completions",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${OPENROUTER_API_KEY}`,
          "HTTP-Referer": "https://jodsi.app",
          "X-Title": "JodSi",
        },
        body: JSON.stringify({
          model: OPENROUTER_MODEL,
          messages: [
            { role: "system", content: SYSTEM_PROMPT },
            { role: "user", content: `Transcript:\n${full_text}` },
          ],
          temperature: 0.3,
          top_p: 0.8,
          max_tokens: 2048,
          response_format: { type: "json_object" },
        }),
      }
    );

    if (!openrouterResponse.ok) {
      const errorText = await openrouterResponse.text();
      console.error("OpenRouter error:", errorText);
      await supabase.from("notes").update({ status: "error" }).eq("id", note_id);
      return new Response(
        JSON.stringify({ error: "OpenRouter request failed" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const openrouterResult = await openrouterResponse.json();
    const generatedText = openrouterResult?.choices?.[0]?.message?.content || "{}";

    let summary;
    try {
      summary = JSON.parse(generatedText);
    } catch {
      summary = {
        title: "โน้ตไม่มีชื่อ",
        key_takeaways: [],
        detail: generatedText,
        action_items: [],
      };
    }

    await supabase.from("summaries").insert({
      note_id,
      key_takeaways: summary.key_takeaways || [],
      detail: summary.detail || "",
      action_items: summary.action_items || [],
    });

    await supabase
      .from("notes")
      .update({ status: "done", title: summary.title || "โน้ตไม่มีชื่อ" })
      .eq("id", note_id);

    console.log(`generate-summary done for ${note_id} in ${Date.now() - startTime}ms`);

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error);
    console.error("generate-summary error:", msg);
    await supabase
      .from("notes")
      .update({ status: "error" })
      .eq("id", "unknown")
      .catch(() => {});
    return new Response(JSON.stringify({ error: msg }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
