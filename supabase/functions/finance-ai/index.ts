import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Anthropic from "npm:@anthropic-ai/sdk@0.125.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type FinanceAiRequest = {
  message?: string;
  mode?: string;
  locale?: string;
  timezone?: string;
  currencyCode?: string;
  currencySymbol?: string;
  categories?: Array<{ id: number; name: string; isExpense: boolean }>;
  accounts?: Array<{ id: number; name: string; isDefault: boolean }>;
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const body = (await req.json()) as FinanceAiRequest;
    validateRequest(body);

    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
      return json({ error: "ANTHROPIC_API_KEY is not configured" }, 500);
    }

    const response = await new Anthropic({ apiKey }).messages.create({
      model: "claude-sonnet-5",
      max_tokens: 16000,
      output_config: { effort: "low" }, // short extraction task
      messages: [{ role: "user", content: buildPrompt(body) }],
    });

    if (response.stop_reason === "refusal") {
      return json({
        intent: "unsupported",
        confidence: 0,
        message:
          "I can help with adding transactions and basic spending summaries.",
      });
    }

    const text =
      response.content.find(
        (b): b is Anthropic.TextBlock => b.type === "text",
      )?.text ?? "{}";
    const parsed = JSON.parse(text);
    const validated = validateAiResponse(parsed);

    return json(validated);
  } catch (error) {
    if (error instanceof Anthropic.APIError) {
      return json({ error: `Claude request failed: ${error.status}` }, 502);
    }
    return json(
      {
        intent: "unsupported",
        confidence: 0,
        message:
          error instanceof Error
            ? error.message
            : "I can help with adding transactions and basic spending summaries.",
      },
      400,
    );
  }
});

function validateRequest(body: FinanceAiRequest) {
  if (!body.message || !body.message.trim()) {
    throw new Error("Message is required.");
  }
  if (!Array.isArray(body.categories) || body.categories.length === 0) {
    throw new Error("Categories are required.");
  }
  if (!Array.isArray(body.accounts) || body.accounts.length === 0) {
    throw new Error("Accounts are required.");
  }
}

function buildPrompt(body: FinanceAiRequest) {
  const today = new Date().toISOString();
  return `
You are the finance parser for Coin Manager.
Return JSON only. Do not include markdown.

Today: ${today}
Timezone: ${body.timezone ?? "local"}
Locale: ${body.locale ?? "en-US"}
Currency: ${body.currencyCode ?? "USD"} ${body.currencySymbol ?? "$"}

Supported intents:
1. add_transaction
2. summary_request
3. unsupported

For add_transaction, return:
{
  "intent": "add_transaction",
  "confidence": 0.0-1.0,
  "message": "short review instruction. Never say the transaction was added, saved, or completed.",
  "transaction": {
    "title": "string",
    "amount": number,
    "isExpense": boolean,
    "categoryId": number or null,
    "accountId": number or null,
    "date": "ISO-8601 datetime",
    "isRecurring": boolean,
    "needsCategoryReview": boolean,
    "needsAccountReview": boolean
  }
}

For summary_request, return:
{
  "intent": "summary_request",
  "confidence": 0.0-1.0,
  "message": "short acknowledgement",
  "summary": {
    "metric": "total_spending" | "total_income" | "net_balance" | "category_spending" | "top_category" | "upcoming_recurring",
    "startDate": "ISO-8601 datetime",
    "endDate": "ISO-8601 datetime",
    "categoryId": number or null
  }
}

Use only these categories:
${JSON.stringify(body.categories)}

Use only these accounts:
${JSON.stringify(body.accounts)}

If you are unsure about category or account, set the id to null and mark the matching needsReview flag true.
If the user asks for anything outside adding transactions or basic summaries, return unsupported.

User message:
${body.message}
`;
}

function validateAiResponse(value: Record<string, unknown>) {
  const intent = value.intent;
  if (
    intent !== "add_transaction" &&
    intent !== "summary_request" &&
    intent !== "unsupported"
  ) {
    throw new Error("Invalid AI intent.");
  }

  if (intent === "add_transaction") {
    const transaction = value.transaction as Record<string, unknown> | undefined;
    if (
      !transaction ||
      typeof transaction.title !== "string" ||
      typeof transaction.amount !== "number" ||
      typeof transaction.isExpense !== "boolean" ||
      typeof transaction.date !== "string"
    ) {
      throw new Error("Invalid transaction response.");
    }
  }

  if (intent === "summary_request") {
    const summary = value.summary as Record<string, unknown> | undefined;
    if (
      !summary ||
      typeof summary.metric !== "string" ||
      typeof summary.startDate !== "string" ||
      typeof summary.endDate !== "string"
    ) {
      throw new Error("Invalid summary response.");
    }
  }

  return value;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
