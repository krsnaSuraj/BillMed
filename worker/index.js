// BillMed Bank Statement Parser — Cloudflare Worker
// API key is stored as environment variable, never exposed to app

export default {
  async fetch(request, env) {
    // Handle CORS
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
        },
      });
    }

    if (request.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Only POST allowed' }), { status: 405 });
    }

    try {
      const { pdf_base64, password, filename } = await request.json();
      const apiKey = env.GEMINI_API_KEY;

      if (!apiKey) {
        return new Response(JSON.stringify({ status: 'FAILED', message: 'Server config error' }), { status: 500 });
      }

      // Gemini prompt
      const prompt = `You are a bank statement parser. Extract all transactions from this bank statement PDF (provided as base64).

Return ONLY a JSON object with this exact structure:
{
  "status": "VERIFIED" | "AMBER" | "FAILED",
  "message": "any message about the extraction",
  "opening_balance": number,
  "closing_balance": number,
  "transactions": [
    {
      "date": "YYYY-MM-DD",
      "description": "transaction description",
      "debit": number (0 if credit),
      "credit": number (0 if debit),
      "balance": number
    }
  ]
}

Rules:
1. Parse EVERY transaction in the statement
2. Verify golden rule: opening_balance + sum(credits) - sum(debits) == closing_balance
3. If verified, set status to "VERIFIED"
4. If small discrepancy, set status to "AMBER"
5. If can't verify, set status to "FAILED"
6. Return ONLY valid JSON, no other text`;

      // Call Gemini API
      const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`;

      const response = await fetch(geminiUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{
            parts: [
              { text: prompt },
              { inline_data: { mime_type: "application/pdf", data: pdf_base64 } }
            ]
          }],
          generationConfig: {
            temperature: 0.1,
            topP: 0.95,
            maxOutputTokens: 8192,
          }
        }),
      });

      if (!response.ok) {
        const errText = await response.text();
        return new Response(JSON.stringify({
          status: 'FAILED',
          message: `Gemini API error: ${response.status}`
        }), { status: 200 });
      }

      const geminiResult = await response.json();
      const text = geminiResult?.candidates?.[0]?.content?.parts?.[0]?.text || '';

      // Extract JSON from response (handle markdown wrapping)
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        return new Response(JSON.stringify({
          status: 'FAILED',
          message: 'Could not parse Gemini response'
        }), { status: 200 });
      }

      const parsed = JSON.parse(jsonMatch[0]);
      return new Response(JSON.stringify(parsed), {
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      });

    } catch (e) {
      return new Response(JSON.stringify({
        status: 'FAILED',
        message: `Worker error: ${e.message}`
      }), { status: 200 });
    }
  }
};
