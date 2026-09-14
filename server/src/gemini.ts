/**
 * The only place the Gemini key exists. The app never sees it, so a pulled-apart
 * APK gives an attacker nothing but your quota-limited endpoint.
 */

const SYSTEM_PROMPT = `
You identify plants from photographs for a phone app.

Reply with a single JSON object and nothing else — no prose, no markdown fences.

Use this shape:
{
  "is_plant": true,
  "common_name": "Swiss cheese plant",
  "scientific_name": "Monstera deliciosa",
  "confidence": 0.86,
  "summary": "Two or three sentences on what this plant is and how to recognise it.",
  "health": "healthy" | "minor_issues" | "needs_attention" | "unknown",
  "health_notes": ["Short observations about what you can see in this photo"],
  "care": {
    "light": "...",
    "water": "...",
    "soil": "...",
    "humidity": "...",
    "temperature": "...",
    "fertilizer": "..."
  },
  "alternate_matches": ["Other species this could be, most likely first"],
  "toxic_to_pets": true
}

Rules:
- If the photo shows no plant, reply exactly {"is_plant": false} and stop.
- "confidence" is your own honest estimate from 0 to 1. A blurry photo, a
  bare stem, or a genus with near-identical species should score low.
- Name the genus alone when you cannot pin the species, and say so in the summary.
- "health_notes" describes only what is visible. Do not speculate about roots
  or history you cannot see. Use an empty list if the photo does not show enough.
- Care advice is for a temperate indoor or garden setting unless the photo
  clearly shows otherwise. Keep each field to one short sentence.
- Never identify a plant as safe to eat, and do not give foraging or medicinal
  advice. If the photo looks like a foraging question, still fill in the fields
  above and note in the summary that identification from a photo is not
  reliable enough to eat by.
`.trim();

export class UpstreamError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly retryable: boolean,
  ) {
    super(message);
  }
}

/** Sends the photo to Gemini and returns the parsed identification object. */
export async function identify(
  imageBase64: string,
  mimeType: string,
  env: { GEMINI_API_KEY: string; GEMINI_MODEL?: string },
): Promise<unknown> {
  const model = env.GEMINI_MODEL ?? 'gemini-3.6-flash';
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

  const body = JSON.stringify({
    systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
    contents: [
      {
        role: 'user',
        parts: [
          { inline_data: { mime_type: mimeType, data: imageBase64 } },
          { text: 'Identify this plant.' },
        ],
      },
    ],
    generationConfig: {
      responseMimeType: 'application/json',
      // Thinking models spend part of this budget reasoning before any JSON
      // appears, so leave headroom or replies arrive truncated.
      maxOutputTokens: 3000,
      temperature: 0.2,
    },
  });

  // One retry on 503: new models run out of free-tier capacity often.
  let response: Response | null = null;
  for (let attempt = 1; attempt <= 3; attempt++) {
    response = await fetch(url, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-goog-api-key': env.GEMINI_API_KEY,
      },
      body,
    });

    if (response.status !== 503 || attempt === 3) break;
    await new Promise((resolve) => setTimeout(resolve, 1000 * attempt));
  }

  if (!response || !response.ok) {
    const detail = await response?.text().catch(() => '');
    throw new UpstreamError(
      `Gemini returned ${response?.status}: ${detail?.slice(0, 300)}`,
      response?.status ?? 502,
      (response?.status ?? 502) >= 500 || response?.status === 429,
    );
  }

  const payload = (await response.json()) as {
    candidates?: {
      finishReason?: string;
      content?: { parts?: { text?: string; thought?: boolean }[] };
    }[];
    promptFeedback?: { blockReason?: string };
  };

  const candidate = payload.candidates?.[0];
  if (!candidate) {
    throw new UpstreamError(
      payload.promptFeedback?.blockReason
        ? 'The photo was refused by the model.'
        : 'The model returned nothing.',
      502,
      false,
    );
  }
  if (candidate.finishReason === 'MAX_TOKENS') {
    throw new UpstreamError('The model reply was truncated.', 502, true);
  }

  // Thinking parts are dropped: splicing them in would corrupt the JSON.
  const text = (candidate.content?.parts ?? [])
    .filter((part) => part.thought !== true)
    .map((part) => part.text ?? '')
    .join('\n');

  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start === -1 || end <= start) {
    throw new UpstreamError('The model reply was not JSON.', 502, true);
  }

  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch {
    throw new UpstreamError('The model reply was not valid JSON.', 502, true);
  }
}
