const OPENAI_ENDPOINT = "https://api.openai.com/v1/responses";

const responseSchema = {
  type: "object",
  properties: {
    reply: {
      type: "string",
      description: "A direct, motivating coaching response under 120 words.",
    },
    insight: {
      type: "string",
      description: "One concise performance insight suitable for the app dashboard.",
    },
    plan: {
      type: "array",
      description: "Empty for normal chat. For weekly_plan, one item per requested weekly session.",
      maxItems: 6,
      items: {
        type: "object",
        properties: {
          title: { type: "string" },
          subtitle: { type: "string" },
          dayOffset: { type: "integer", minimum: 0, maximum: 6 },
          estimatedMinutes: { type: "integer", minimum: 20, maximum: 120 },
          rationale: { type: "string" },
          exercises: {
            type: "array",
            minItems: 3,
            maxItems: 8,
            items: {
              type: "object",
              properties: {
                exerciseID: { type: "string" },
                sets: { type: "integer", minimum: 1, maximum: 4 },
                repMin: { type: "integer", minimum: 1, maximum: 30 },
                repMax: { type: "integer", minimum: 1, maximum: 40 },
                targetWeightKG: { type: "number", minimum: 0, maximum: 500 },
                restSeconds: { type: "integer", minimum: 60, maximum: 300 },
                targetRIR: { type: "integer", minimum: 1, maximum: 4 },
              },
              required: ["exerciseID", "sets", "repMin", "repMax", "targetWeightKG", "restSeconds", "targetRIR"],
              additionalProperties: false,
            },
          },
        },
        required: ["title", "subtitle", "dayOffset", "estimatedMinutes", "rationale", "exercises"],
        additionalProperties: false,
      },
    },
  },
  required: ["reply", "insight", "plan"],
  additionalProperties: false,
};

const systemPrompt = `You are Earned, a pragmatic adaptive strength and fitness coach.

Use only the profile, current plan, recent set logs, and exercise catalog supplied by the app. Be encouraging but specific. Do not diagnose injury, prescribe rehabilitation, provide medical advice, or use shame. If pain or a health concern is mentioned, advise the user to stop and consult a qualified clinician.

For normal chat, answer the question and return an empty plan array.

For weekly_plan mode:
- Return exactly profile.sessionsPerWeek training days.
- Use only exerciseID values present in exerciseCatalog.
- Respect profile.equipment and profile.constraints. Never include a movement the profile marks to avoid.
- Keep all load values in kilograms.
- Preserve successful movements and adjust conservatively from recent completed sets.
- Never increase a working load more than 10% week over week.
- Increase load only after two complete top-range exposures near the prescribed RIR; otherwise hold.
- Hold or reduce load when completion was low. Do not invent performance data.
- Keep most work at 2-3 repetitions in reserve. Do not require muscular failure.
- For strength, prioritize heavier 3-6 rep compound work with longer rest. For hypertrophy, use mostly 6-15 reps and sufficient weekly sets distributed across the week.
- Use 3-8 exercises per day, 1-4 working sets per exercise, and at least 60 seconds of rest.
- Cover chest, back, and legs across the week with at least 4-6 direct sets each, unless the supplied movement limits make a category unavailable.
- Keep direct weekly work at or below 20 sets per muscle and do not add load and volume aggressively at the same time.
- Spread hard sessions across the week and calculate enough time for every set, rest period, transition, and a short warm-up within profile.sessionMinutes.
- repMax must be greater than or equal to repMin.

The iPhone validates every proposal against its deterministic evidence-based engine. If uncertain, preserve the current plan and explain why instead of making a dramatic change.

Return only the structured response.`;

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return cors(new Response(null, { status: 204 }));
    if (request.method !== "POST") return json({ error: "POST required" }, 405);

    if (!env.OPENAI_API_KEY) {
      return json({ error: "OPENAI_API_KEY is not configured on the worker" }, 500);
    }

    if (env.APP_SHARED_SECRET) {
      const expected = `Bearer ${env.APP_SHARED_SECRET}`;
      if (request.headers.get("Authorization") !== expected) {
        return json({ error: "Unauthorized" }, 401);
      }
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return json({ error: "Invalid JSON" }, 400);
    }

    const compactContext = {
      mode: payload.mode === "weekly_plan" ? "weekly_plan" : "chat",
      message: String(payload.message || "").slice(0, 2000),
      profile: payload.profile || {},
      currentPlan: Array.isArray(payload.currentPlan) ? payload.currentPlan.slice(0, 6) : [],
      recentSessions: Array.isArray(payload.recentSessions) ? payload.recentSessions.slice(0, 8) : [],
      exerciseCatalog: Array.isArray(payload.exerciseCatalog) ? payload.exerciseCatalog.slice(0, 100) : [],
    };
    const safetyIdentifier = String(payload.safetyIdentifier || "")
      .toLowerCase()
      .replace(/[^a-z0-9_-]/g, "")
      .slice(0, 64);

    const openAIResponse = await fetch(OPENAI_ENDPOINT, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: env.OPENAI_MODEL || "gpt-5.6-terra",
        store: false,
        reasoning: { effort: "low" },
        ...(safetyIdentifier ? { safety_identifier: safetyIdentifier } : {}),
        input: [
          { role: "system", content: systemPrompt },
          { role: "user", content: JSON.stringify(compactContext) },
        ],
        text: {
          verbosity: "low",
          format: {
            type: "json_schema",
            name: "fitness_buddy_coach_response",
            strict: true,
            schema: responseSchema,
          },
        },
      }),
    });

    const body = await openAIResponse.json();
    if (!openAIResponse.ok) {
      return json({ error: body?.error?.message || "OpenAI request failed" }, openAIResponse.status);
    }

    const output = extractOutputText(body);
    if (!output) return json({ error: "The model returned no structured text" }, 502);

    try {
      return json(JSON.parse(output), 200);
    } catch {
      return json({ error: "The model response could not be parsed" }, 502);
    }
  },
};

function extractOutputText(response) {
  if (typeof response.output_text === "string" && response.output_text.length > 0) {
    return response.output_text;
  }
  for (const item of response.output || []) {
    for (const content of item.content || []) {
      if (content.type === "output_text" && typeof content.text === "string") return content.text;
      if (content.type === "refusal") return null;
    }
  }
  return null;
}

function json(value, status = 200) {
  return cors(new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  }));
}

function cors(response) {
  const result = new Response(response.body, response);
  result.headers.set("Access-Control-Allow-Origin", "*");
  result.headers.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
  result.headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  return result;
}
