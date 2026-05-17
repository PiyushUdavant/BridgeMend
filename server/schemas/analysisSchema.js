/**
 * Gemini-compatible JSON schemas (no additionalProperties).
 */

const PARTNER_SCORE_PROPERTIES = {
  overall: { type: "integer" },
  empathy: { type: "integer" },
  listening: { type: "integer" },
  reception: { type: "integer" },
  clarity: { type: "integer" },
  respect: { type: "integer" },
  responsiveness: { type: "integer" },
  openMindedness: { type: "integer" },
};

const ANALYSIS_RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    sessionSummary: { type: "string" },
    sessionEmotionalTone: { type: "string" },
    partnerEmotionalTones: {
      type: "array",
      items: {
        type: "object",
        properties: {
          partnerId: { type: "string" },
          tone: { type: "string" },
        },
        required: ["partnerId", "tone"],
      },
    },
    communicationPatterns: {
      type: "array",
      items: { type: "string" },
    },
    harmfulBehaviors: {
      type: "array",
      items: {
        type: "object",
        properties: {
          description: { type: "string" },
          severity: { type: "string" },
          observedIn: { type: "string" },
        },
        required: ["description", "severity", "observedIn"],
      },
    },
    responsibilityIndicators: {
      type: "array",
      items: {
        type: "object",
        properties: {
          partnerId: { type: "string" },
          indicator: { type: "string" },
        },
        required: ["partnerId", "indicator"],
      },
    },
    partnerScores: {
      type: "array",
      items: {
        type: "object",
        properties: {
          partnerId: { type: "string" },
          scores: {
            type: "object",
            properties: PARTNER_SCORE_PROPERTIES,
            required: Object.keys(PARTNER_SCORE_PROPERTIES),
          },
        },
        required: ["partnerId", "scores"],
      },
    },
    partnerStrengths: {
      type: "array",
      items: {
        type: "object",
        properties: {
          partnerId: { type: "string" },
          items: { type: "array", items: { type: "string" } },
        },
        required: ["partnerId", "items"],
      },
    },
    partnerImprovements: {
      type: "array",
      items: {
        type: "object",
        properties: {
          partnerId: { type: "string" },
          items: { type: "array", items: { type: "string" } },
        },
        required: ["partnerId", "items"],
      },
    },
    resolutionSteps: {
      type: "array",
      items: { type: "string" },
    },
    overallFeedback: { type: "string" },
    improvementSuggestions: {
      type: "array",
      items: { type: "string" },
    },
    suggestedBondingActivities: {
      type: "array",
      items: { type: "string" },
    },
    disclaimer: { type: "string" },
  },
  required: [
    "sessionSummary",
    "sessionEmotionalTone",
    "partnerEmotionalTones",
    "communicationPatterns",
    "harmfulBehaviors",
    "responsibilityIndicators",
    "partnerScores",
    "partnerStrengths",
    "partnerImprovements",
    "resolutionSteps",
    "overallFeedback",
    "improvementSuggestions",
    "suggestedBondingActivities",
    "disclaimer",
  ],
};

const TRANSCRIPT_RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    fullText: { type: "string" },
    segments: {
      type: "array",
      items: {
        type: "object",
        properties: {
          speakerLabel: { type: "string" },
          speakerGender: { type: "string" },
          speakerId: { type: "string" },
          text: { type: "string" },
          approximateOrder: { type: "integer" },
        },
        required: ["speakerLabel", "text"],
      },
    },
  },
  required: ["fullText", "segments"],
};

module.exports = {
  ANALYSIS_RESPONSE_SCHEMA,
  TRANSCRIPT_RESPONSE_SCHEMA,
};
