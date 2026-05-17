/**
 * Gender-aware dialogue formatting for couple call transcripts.
 */

const MALE = "Male";
const FEMALE = "Female";

function normalizeGender(raw) {
  if (!raw) return "Unknown";
  const g = String(raw).trim().toLowerCase();
  if (g === "male" || g === "m") return MALE;
  if (g === "female" || g === "f") return FEMALE;
  if (g.includes("non-binary") || g === "nonbinary") return "Non-Binary";
  if (g.includes("prefer not")) return "Unknown";
  return "Unknown";
}

/**
 * When one partner is Male and one is Female, use gender labels in dialogue.
 */
function usesGenderDialogueLabels(partners) {
  if (!partners || partners.length < 2) return false;
  const normalized = partners.map((p) => normalizeGender(p.gender));
  return normalized.includes(MALE) && normalized.includes(FEMALE);
}

function partnerById(partners, id) {
  if (!id) return null;
  return partners.find((p) => p.id === id) || null;
}

function labelForPartner(partner, genderDialogueMode) {
  if (!partner) return "Unknown";
  const g = normalizeGender(partner.gender);
  if (genderDialogueMode && (g === MALE || g === FEMALE)) {
    return g;
  }
  return partner.name || "Unknown";
}

/**
 * Infer Male/Female label from free-text speaker label + partner list.
 */
function inferLabelFromSpeakerHint(speakerLabel, partners, genderDialogueMode) {
  if (!speakerLabel) return null;
  const lower = String(speakerLabel).toLowerCase();

  if (genderDialogueMode) {
    if (lower.includes("male") && !lower.includes("female")) return MALE;
    if (lower.includes("female")) return FEMALE;
  }

  for (const p of partners) {
    if (p.name && lower.includes(p.name.toLowerCase())) {
      return labelForPartner(p, genderDialogueMode);
    }
  }

  if (lower.includes("partner a") || lower === "speaker 1") {
    return labelForPartner(partners[0], genderDialogueMode);
  }
  if (lower.includes("partner b") || lower === "speaker 2") {
    return labelForPartner(partners[1], genderDialogueMode);
  }

  return null;
}

/**
 * @param {object} segment
 * @param {Array<{id:string,name:string,gender?:string}>} partners
 * @param {boolean} genderDialogueMode
 */
function resolveSegmentLabel(segment, partners, genderDialogueMode) {
  const byId = partnerById(partners, segment.speakerId);
  if (byId) {
    return labelForPartner(byId, genderDialogueMode);
  }

  if (segment.speakerGender) {
    const g = normalizeGender(segment.speakerGender);
    if (genderDialogueMode && (g === MALE || g === FEMALE)) return g;
  }

  const fromHint = inferLabelFromSpeakerHint(
    segment.speakerLabel,
    partners,
    genderDialogueMode
  );
  if (fromHint) return fromHint;

  if (segment.speakerLabel) {
    return segment.speakerLabel;
  }

  return "Unknown";
}

/**
 * Format one line: "Male :: hello there"
 */
function formatDialogueLine(label, text) {
  const clean = String(text || "").trim();
  if (!clean) return "";
  return `${label} :: ${clean}`;
}

/**
 * Build chronological back-and-forth transcript for Gemini analysis.
 * @param {{ segments?: Array, fullText?: string }} transcript
 * @param {Array<{id:string,name:string,gender?:string}>} partners
 */
function formatTranscriptForAnalysis(transcript, partners) {
  const genderDialogueMode = usesGenderDialogueLabels(partners);
  const segments = [...(transcript.segments || [])].sort(
    (a, b) => (a.approximateOrder ?? 0) - (b.approximateOrder ?? 0)
  );

  const formattedSegments = segments.map((seg, index) => {
    const dialogueLabel = resolveSegmentLabel(seg, partners, genderDialogueMode);
    return {
      ...seg,
      dialogueLabel,
      speakerGender: normalizeGender(
        seg.speakerGender ||
          (dialogueLabel === MALE || dialogueLabel === FEMALE
            ? dialogueLabel
            : partnerById(partners, seg.speakerId)?.gender)
      ),
      approximateOrder: seg.approximateOrder ?? index,
    };
  });

  const dialogueLines = formattedSegments
    .map((s) => formatDialogueLine(s.dialogueLabel, s.text))
    .filter(Boolean);

  const dialogueText = dialogueLines.join("\n");

  const partnerLegend = partners
    .map((p) => {
      const g = normalizeGender(p.gender);
      const role =
        genderDialogueMode && (g === MALE || g === FEMALE)
          ? `${g} voice`
          : p.name;
      return `- ${role}: ${p.name} (partner id: ${p.id}, gender: ${g})`;
    })
    .join("\n");

  const fullTextForAnalysis = [
    "CONVERSATION TRANSCRIPT (chronological, back-and-forth):",
    "",
    dialogueText || transcript.fullText || "",
    "",
    "PARTNER REFERENCE (map scores to these ids):",
    partnerLegend,
  ].join("\n");

  return {
    ...transcript,
    segments: formattedSegments,
    dialogueText,
    dialogueFormat: genderDialogueMode ? "male_female" : "partner_name",
    fullText: dialogueText || transcript.fullText || "",
    fullTextForAnalysis,
  };
}

module.exports = {
  normalizeGender,
  usesGenderDialogueLabels,
  formatTranscriptForAnalysis,
  formatDialogueLine,
  MALE,
  FEMALE,
};
