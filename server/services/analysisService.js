const { generateStructuredJson } = require("./geminiClient");
const { ANALYSIS_RESPONSE_SCHEMA } = require("../schemas/analysisSchema");

const ANALYSIS_SYSTEM_PROMPT = `You are the AI analysis engine for Bridgemend (Mend), a conflict-resolution app for couples.

Analyze the complete conversation transcript between two partners who discussed a relationship conflict during a guided voice session.

The transcript uses chronological back-and-forth lines such as:
Male :: ...
Female :: ...
Each line is one speaker turn. Use this flow to understand who initiated topics, who interrupted, repeated demands, avoided accountability, escalated tension, validated feelings, or responded defensively.

Important rules:
- Do not give legal, medical, or clinical therapy advice.
- Do not declare one partner absolutely "guilty" or "at fault."
- Identify communication patterns, responsibility indicators, harmful behaviors, emotional tone, and practical resolution steps both can try.
- Be fair, balanced, and constructive toward both partners.
- Use neutral, non-judgmental language.
- All numeric scores must be integers from 0 to 100 (higher = healthier communication in that dimension).
- partnerScores, partnerStrengths, partnerImprovements, partnerEmotionalTones, responsibilityIndicators, and resolutionActions entries must use the exact partner ids provided in the request (not "A"/"B" unless those are the ids).
- harmfulBehaviors.observedIn must be a partner id, "both", or "unclear".
- suggestedBondingActivities should be warm, low-pressure reconnecting ideas (3–5 items).
- disclaimer must state this is AI-generated communication feedback, not professional therapy.

Resolution guidance rules:
  - The output must include a resolutionActions object.
  - resolutionActions must contain these exact sections:
    1. conflictEscalators
    2. partnerActionPlans
    3. sharedSolutions
    4. immediateRepairScript

  - resolutionActions.conflictEscalators must identify what each partner did that may have raised, prolonged, or intensified the conflict.
  - For conflictEscalators, explain:
    - the partnerId
    - the partnerName
    - the specific behavior
    - how it may have affected the other partner or the conversation
    - a better alternative response

  - resolutionActions.partnerActionPlans must include 2–3 practical actions for each partner.
  - Each partner action must include:
    - title
    - description
    - whyItHelps

  - resolutionActions.sharedSolutions must include 2–3 shared steps both partners can try together.
  - resolutionActions.immediateRepairScript must provide one short, calm script they can use immediately to restart the conversation.

  - Do not use insulting, blaming, or shaming language.
  - Do not say one partner is completely wrong or fully responsible.
  - Avoid the word "mistake" in user-facing content.
  - Use softer wording such as "what escalated the conflict", "what can improve", "may have escalated", "could improve", or "might have made the other partner feel".
  - Base all suggestions only on the transcript and provided metadata.
  - Do not invent facts that are not present in the transcript.
  - Keep the advice practical, direct, supportive, and simple enough to show inside a mobile app.

Return only JSON matching the schema.`;

/* 
  - The output must include a resolutionActions object.
  - resolutionActions must explain what each partner did that may have escalated the conflict.
  - Do not use insulting or blaming language.
  - Use phrases like "may have escalated", "could improve", "might have made the other partner feel", instead of harsh judgment.
  - For each partner, provide 2–3 specific actions they can take next.
  - Provide 2–3 shared solutions both partners can try together.
  - Provide one short repair script they can say immediately to restart the conversation calmly.
  - Base all suggestions only on the transcript and provided metadata.
  - Do not invent facts that are not present in the transcript.
  - Keep the advice practical, direct, and simple enough to show inside a mobile app.
*/

/**
 * @param {string} fullTranscriptText
 * @param {{ sessionId: string, partners: Array<{ id: string, name: string }>, durationSeconds?: number, conflictTopic?: string }} metadata
 */
async function analyzeTranscript(fullTranscriptText, metadata = {}) {
  const partnersBlock =
    metadata.partners
      ?.map((p) => {
        const g = p.gender ? `, gender: ${p.gender}` : "";
        return `- ${p.name} (id: ${p.id}${g})`;
      })
      .join("\n") || "- Partner A\n- Partner B";

  const contextLines = [
    `Session id: ${metadata.sessionId || "unknown"}`,
    `Partners:\n${partnersBlock}`,
  ];

  if (metadata.durationSeconds != null) {
    contextLines.push(`Call duration (seconds): ${metadata.durationSeconds}`);
  }
  if (metadata.conflictTopic) {
    contextLines.push(`Stated conflict topic: ${metadata.conflictTopic}`);
  }

  const parts = [
    {
      text: `${ANALYSIS_SYSTEM_PROMPT}

${contextLines.join("\n")}

--- TRANSCRIPT ---
${fullTranscriptText}
--- END TRANSCRIPT ---`,
    },
  ];

  return generateStructuredJson(parts, {
    responseSchema: ANALYSIS_RESPONSE_SCHEMA,
    temperature: 0.4,
  });
}

function listToMap(items, valueKey = "items") {
  const map = {};
  for (const row of items || []) {
    if (row?.partnerId) {
      map[row.partnerId] = row[valueKey] ?? row.indicator ?? row.tone ?? [];
    }
  }
  return map;
}

/**
 * Maps Gemini analysis to Mend app CommunicationScores shape (0–1 floats).
 * @param {object} analysis
 */
function toAppCommunicationScores(analysis) {
  const partnerScores = {};
  const strengthsMap = listToMap(analysis.partnerStrengths);
  const improvementsMap = listToMap(analysis.partnerImprovements);

  for (const entry of analysis.partnerScores || []) {
    const id = entry.partnerId;
    const s = entry.scores;
    if (!id || !s) continue;

    const toUnit = (v) => Math.max(0, Math.min(1, Number(v) / 100));

    partnerScores[id] = {
      empathy: toUnit(s.empathy),
      listening: toUnit(s.listening),
      reception: toUnit(s.reception),
      clarity: toUnit(s.clarity),
      respect: toUnit(s.respect),
      responsiveness: toUnit(s.responsiveness),
      openMindedness: toUnit(s.openMindedness),
      strengths: strengthsMap[id] || [],
      improvements: improvementsMap[id] || [],
    };
  }

  return {
    partnerScores,
    overallFeedback: analysis.overallFeedback || "",
    improvementSuggestions: analysis.improvementSuggestions || [],
  };
}

module.exports = {
  analyzeTranscript,
  toAppCommunicationScores,
  ANALYSIS_SYSTEM_PROMPT,
};
