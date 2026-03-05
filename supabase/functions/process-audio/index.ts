import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const DEEPGRAM_API_KEY = Deno.env.get("DEEPGRAM_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

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

  try {
    const { note_id, audio_url } = await req.json();

    if (!note_id || !audio_url) {
      return new Response(
        JSON.stringify({ error: "note_id and audio_url are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Update note status to transcribing
    await supabase
      .from("notes")
      .update({ status: "transcribing" })
      .eq("id", note_id);

    // Build Deepgram callback URL
    const callbackUrl = `${SUPABASE_URL}/functions/v1/on-transcription-done?note_id=${note_id}`;

    // Send audio to Deepgram with callback
    const deepgramUrl = new URL("https://api.deepgram.com/v1/listen");
    deepgramUrl.searchParams.set("model", "nova-2");
    deepgramUrl.searchParams.set("language", "th");
    deepgramUrl.searchParams.set("punctuate", "true");
    deepgramUrl.searchParams.set("paragraphs", "true");
    deepgramUrl.searchParams.set("utterances", "true");
    deepgramUrl.searchParams.set("smart_format", "true");
    deepgramUrl.searchParams.set("callback", callbackUrl);

    const deepgramResponse = await fetch(deepgramUrl.toString(), {
      method: "POST",
      headers: {
        Authorization: `Token ${DEEPGRAM_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ url: audio_url }),
    });

    if (!deepgramResponse.ok) {
      const errorText = await deepgramResponse.text();
      console.error("Deepgram error:", errorText);

      await supabase
        .from("notes")
        .update({ status: "error" })
        .eq("id", note_id);

      return new Response(
        JSON.stringify({ error: "Deepgram request failed", details: errorText }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const deepgramResult = await deepgramResponse.json();
    console.log("Deepgram callback registered:", deepgramResult);

    return new Response(
      JSON.stringify({ success: true, note_id }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error in process-audio:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
