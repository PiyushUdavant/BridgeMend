const express = require("express");
const multer = require("multer");
const {
  transcribeAudio,
  mergeTranscripts,
} = require("../services/transcriptionService");
const {
  analyzeTranscript,
  toAppCommunicationScores,
} = require("../services/analysisService");
const {
  formatTranscriptForAnalysis,
  normalizeGender,
} = require("../utils/transcriptFormatter");

const router = express.Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 25 * 1024 * 1024,
    files: 3,
  },
  fileFilter: (_req, file, cb) => {
    if (file.mimetype.startsWith("audio/") || file.mimetype === "video/webm") {
      cb(null, true);
    } else {
      cb(new Error(`Unsupported file type: ${file.mimetype}`));
    }
  },
});

function parsePartners(body) {
  if (body.partners) {
    try {
      const parsed =
        typeof body.partners === "string"
          ? JSON.parse(body.partners)
          : body.partners;
      if (Array.isArray(parsed) && parsed.length >= 2) {
        return parsed.map((p) => ({
          id: String(p.id),
          name: String(p.name || p.id),
          gender: normalizeGender(p.gender),
        }));
      }
    } catch {
      /* fall through */
    }
  }

  const aId = body.partnerAId || body.partnerA_id;
  const bId = body.partnerBId || body.partnerB_id;
  if (aId && bId) {
    return [
      {
        id: String(aId),
        name: String(body.partnerAName || "Partner A"),
        gender: normalizeGender(body.partnerAGender),
      },
      {
        id: String(bId),
        name: String(body.partnerBName || "Partner B"),
        gender: normalizeGender(body.partnerBGender),
      },
    ];
  }

  return null;
}

function parseTranscriptFromBody(body) {
  if (body.transcript && typeof body.transcript === "string") {
    return {
      fullText: body.transcript,
      segments: [],
    };
  }

  if (body.transcriptJson) {
    try {
      const parsed =
        typeof body.transcriptJson === "string"
          ? JSON.parse(body.transcriptJson)
          : body.transcriptJson;
      if (parsed.fullText) return parsed;
    } catch {
      /* ignore */
    }
  }

  return null;
}

async function handleCallAnalysis(req, res) {
    const startedAt = Date.now();

    try {
      const sessionId = req.body.sessionId;
      if (!sessionId) {
        return res.status(400).json({
          error: "sessionId is required",
        });
      }

      const partners = parsePartners(req.body);
      if (!partners || partners.length < 2) {
        return res.status(400).json({
          error:
            "Two partners are required (partners JSON array or partnerAId/partnerBId)",
        });
      }

      const metadata = {
        sessionId,
        partners,
        durationSeconds: req.body.durationSeconds
          ? Number(req.body.durationSeconds)
          : undefined,
        conflictTopic: req.body.conflictTopic || req.body.topic,
      };

      let transcript = parseTranscriptFromBody(req.body);
      const files = req.files || {};

      if (!transcript) {
        const mixed = files.audio?.[0];
        const trackA = files.partnerAAudio?.[0];
        const trackB = files.partnerBAudio?.[0];

        if (mixed) {
          transcript = await transcribeAudio(
            mixed.buffer,
            mixed.mimetype,
            metadata
          );
        } else if (trackA && trackB) {
          const [resultA, resultB] = await Promise.all([
            transcribeAudio(trackA.buffer, trackA.mimetype, {
              ...metadata,
              partners: [partners[0]],
            }),
            transcribeAudio(trackB.buffer, trackB.mimetype, {
              ...metadata,
              partners: [partners[1]],
            }),
          ]);

          transcript = mergeTranscripts(
            [
              {
                label: partners[0].name,
                speakerId: partners[0].id,
                transcript: resultA,
              },
              {
                label: partners[1].name,
                speakerId: partners[1].id,
                transcript: resultB,
              },
            ],
            partners
          );
        } else {
          return res.status(400).json({
            error:
              "Provide audio (field: audio) or partnerAAudio+partnerBAudio, or a transcript in the JSON body",
          });
        }
      }

      if (!transcript.fullText?.trim() && !transcript.segments?.length) {
        return res.status(422).json({
          error: "Transcription produced empty text; unable to analyze",
        });
      }

      transcript = formatTranscriptForAnalysis(transcript, partners);

      const analysis = await analyzeTranscript(
        transcript.fullTextForAnalysis || transcript.dialogueText || transcript.fullText,
        metadata
      );
      const partnerIds = partners.map((p) => p.id);
      const appScores = toAppCommunicationScores(analysis);

      console.log(
        `Call analysis complete sessionId=${sessionId} durationMs=${
          Date.now() - startedAt
        }`
      );

      return res.json({
        success: true,
        sessionId,
        transcript,
        analysis,
        appScores,
        meta: {
          processedAt: new Date().toISOString(),
          processingTimeMs: Date.now() - startedAt,
          partnerIds,
        },
      });
    } catch (error) {
      console.error("Call analysis failed:", error);
      let status = 500;
      if (error.message?.includes("GEMINI_API_KEY")) {
        status = 503;
      } else if (error.status === 429 || error.message?.includes("429")) {
        status = 429;
      }
      return res.status(status).json({
        error: "Call analysis failed",
        message: error.message,
      });
    }
}

const audioUpload = upload.fields([
  { name: "audio", maxCount: 1 },
  { name: "partnerAAudio", maxCount: 1 },
  { name: "partnerBAudio", maxCount: 1 },
]);

/**
 * POST /api/call/analyze
 *
 * Multipart (preferred after call ends):
 *   - audio: mixed recording OR
 *   - partnerAAudio + partnerBAudio: separate tracks
 *   - sessionId, partners (JSON) OR partnerAId, partnerAName, partnerBId, partnerBName
 *   - durationSeconds?, conflictTopic?
 */
router.post("/analyze", audioUpload, handleCallAnalysis);

/**
 * POST /api/call/analyze-text
 * JSON body when transcript is already available (skips STT).
 */
router.post("/analyze-text", handleCallAnalysis);

router.use((err, _req, res, next) => {
  if (err instanceof multer.MulterError) {
    return res.status(400).json({
      error: "Upload error",
      message: err.message,
    });
  }
  if (err) {
    return res.status(400).json({
      error: "Bad request",
      message: err.message,
    });
  }
  next();
});

module.exports = router;
