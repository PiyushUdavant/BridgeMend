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
    resolutionActions: {
      type: "object",
      properties: {
        conflictEscalators: {
          type: "array",
          items: {
            type: "object",
            properties: {
              partnerId: { type: "string" },
              partnerName: { type: "string" },
              behavior: { type: "string" },
              impact: { type: "string" },
              betterAlternative: { type: "string" },
            },
            required: [
              "partnerId",
              "partnerName",
              "behavior",
              "impact",
              "betterAlternative",
            ],
          },
        },
        partnerActionPlans: {
          type: "array",
          items: {
            type: "object",
            properties: {
              partnerId: { type: "string" },
              partnerName: { type: "string" },
              actions: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    title: { type: "string" },
                    description: { type: "string" },
                    whyItHelps: { type: "string" },
                  },
                  required: ["title", "description", "whyItHelps"],
                },
              },
            },
            required: ["partnerId", "partnerName", "actions"],
          },
        },
        sharedSolutions: {
          type: "array",
          items: {
            type: "object",
            properties: {
              title: { type: "string" },
              description: { type: "string" },
            },
            required: ["title", "description"],
          },
        },
        immediateRepairScript: {
          type: "object",
          properties: {
            title: { type: "string" },
            script: { type: "string" },
          },
          required: ["title", "script"],
        },
      },
      required: [
        "conflictEscalators",
        "partnerActionPlans",
        "sharedSolutions",
        "immediateRepairScript",
      ],
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
    "resolutionActions",
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
