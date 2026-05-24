const { GoogleGenerativeAI } = require("@google/generative-ai");

const DEFAULT_MODEL = process.env.GEMINI_MODEL || "gemini-2.5-flash";

function getApiKey() {
  const key = process.env.GEMINI_API_KEY;
  if (!key) {
    throw new Error("GEMINI_API_KEY is not configured in environment");
  }
  return key;
}

function getModel(options = {}) {
  const genAI = new GoogleGenerativeAI(getApiKey());
  
  return genAI.getGenerativeModel({
    model: options.model || DEFAULT_MODEL,
    generationConfig: {
      temperature: options.temperature ?? 0.35,
      maxOutputTokens: options.maxOutputTokens ?? 8192,
      responseMimeType: "application/json",
      ...(options.responseSchema
        ? { responseSchema: options.responseSchema }
        : {}),
    },
  });
}

/**
 * @param {import('@google/generative-ai').Part[]} parts
 * @param {object} options
 * @returns {Promise<object>}
 */
async function generateStructuredJson(parts, options = {}) {
  const model = getModel({
    model: options.model,
    temperature: options.temperature,
    maxOutputTokens: options.maxOutputTokens,
    responseSchema: options.responseSchema,
  });

  const result = await model.generateContent({
    contents: [{ role: "user", parts }],
  });

  const text = result.response.text();
  if (!text) {
    throw new Error("Empty response from Gemini");
  }

  try {
    return JSON.parse(text);
  } catch (parseError) {
    const snippet = text.length > 400 ? `${text.slice(0, 400)}…` : text;
    throw new Error(
      `Gemini returned invalid JSON: ${parseError.message}. Snippet: ${snippet}`
    );
  }
}

module.exports = {
  getApiKey,
  getModel,
  generateStructuredJson,
  DEFAULT_MODEL,
};
