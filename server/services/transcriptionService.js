const { generateStructuredJson } = require("./geminiClient");
const { TRANSCRIPT_RESPONSE_SCHEMA } = require("../schemas/analysisSchema");
const {
  normalizeGender,
  usesGenderDialogueLabels,
  formatDialogueLine,
  MALE,
  FEMALE,
} = require("../utils/transcriptFormatter");

function buildTranscriptionPrompt(context) {
  const partners = context.partners || [];
  const genderMode = usesGenderDialogueLabels(partners);

  const partnerLines = partners
    .map((p) => {
      const g = normalizeGender(p.gender);
      return `- ${p.name} (partner id: ${p.id}, registered gender: ${g})`;
    })
    .join("\n");

  const labelRules = genderMode
    ? `SPEAKER LABELS (required for this couple):
- This call is between one Male and one Female partner.
- Set speakerLabel to exactly "${MALE}" or "${FEMALE}" on every segment.
- Set speakerGender to the same value ("Male" or "Female").
- Distinguish voices by pitch/timbre and conversational turn-taking.
- Assign speakerId to the matching partner id when you are confident which person spoke.`
    : `SPEAKER LABELS:
- Use each partner's display name as speakerLabel when voice identity is clear.
- Set speakerId when confident. Include speakerGender when audible cues support it.`;

  return `You are a speech-to-text and two-speaker diarization engine for Bridgemend, a couples conflict-resolution app.

The audio is a LIVE conversation between exactly TWO partners speaking back and forth (not a monologue).

YOUR TASKS:
1. Listen for speaker changes and split into separate segments in true chronological order.
2. Transcribe each utterance accurately without summarizing.
3. Preserve natural turn-taking: Male speaks, then Female responds, then Male, etc. (order may start with either).
4. Never merge both speakers into one segment.
5. If words are unclear, use [unclear] inline.

${labelRules}

OUTPUT fullText:
- Must use this exact line format with double colon and space: "Label :: utterance"
- One utterance per line, ordered as the conversation happened.
${genderMode ? `- Example:\n${MALE} :: I felt hurt when plans changed.\n${FEMALE} :: I hear you, work overwhelmed me.\n${MALE} :: I need to feel prioritized.` : ""}

Each segment in segments[] must include: speakerLabel, text, approximateOrder (0, 1, 2...), and speakerGender when known.

REGISTERED PARTNERS:
${partnerLines || "(none provided)"}

Session id: ${context.sessionId || "unknown"}

Return only JSON matching the schema.`;
}

/**
 * @param {Buffer} audioBuffer
 * @param {string} mimeType
 * @param {{ partners: Array<{ id: string, name: string, gender?: string }>, sessionId?: string }} context
 */
async function transcribeAudio(audioBuffer, mimeType, context = {}) {
  const parts = [
    {
      inlineData: {
        data: audioBuffer.toString("base64"),
        mimeType: mimeType || "audio/wav",
      },
    },
    {
      text: buildTranscriptionPrompt(context),
    },
  ];

  return generateStructuredJson(parts, {
    responseSchema: TRANSCRIPT_RESPONSE_SCHEMA,
    temperature: 0.15,
  });
}

/**
 * Merge separate per-partner tracks using gender/name labels.
 */
function mergeTranscripts(trackResults, partners = []) {
  const genderMode = usesGenderDialogueLabels(partners);
  const segments = [];
  let order = 0;

  for (const track of trackResults) {
    const partner =
      partners.find((p) => p.id === track.speakerId) || null;
    const defaultLabel =
      track.label ||
      (partner
        ? genderMode &&
          (normalizeGender(partner.gender) === MALE ||
            normalizeGender(partner.gender) === FEMALE)
          ? normalizeGender(partner.gender)
          : partner.name
        : "Unknown");

    const segs = track.transcript?.segments || [];
    for (const seg of segs) {
      segments.push({
        speakerLabel: defaultLabel,
        speakerGender: partner ? normalizeGender(partner.gender) : undefined,
        speakerId: track.speakerId || seg.speakerId,
        text: seg.text,
        approximateOrder: order++,
      });
    }
  }

  segments.sort((a, b) => a.approximateOrder - b.approximateOrder);

  const fullText = segments
    .map((s) => formatDialogueLine(s.speakerLabel, s.text))
    .filter(Boolean)
    .join("\n");

  return { fullText, segments };
}

module.exports = {
  transcribeAudio,
  mergeTranscripts,
  buildTranscriptionPrompt,
};
