const express = require("express");
const http = require("http");
const socketIo = require("socket.io");
const cors = require("cors");
const helmet = require("helmet");
const crypto = require('crypto');
require("dotenv").config();

// ZEGOCLOUD App credentials
const APP_ID = 1390967091;
const SERVER_SECRET = "c47a44d5ff4b82d828282ff1d4d510af";

// ZEGOCLOUD Token Generator Functions
function generateToken(userID, effectiveTimeInSeconds = 86400) {
  if (!userID) {
    throw new Error('userID is required');
  }

  const payload = {
    iss: APP_ID,
    exp: Math.floor(Date.now() / 1000) + effectiveTimeInSeconds,
    userId: userID,
    iat: Math.floor(Date.now() / 1000),
  };

  const header = {
    alg: 'HS256',
    typ: 'JWT'
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));

  const signature = crypto
    .createHmac('sha256', SERVER_SECRET)
    .update(`${encodedHeader}.${encodedPayload}`)
    .digest('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');

  return `${encodedHeader}.${encodedPayload}.${signature}`;
}

function base64UrlEncode(str) {
  return Buffer.from(str)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

function validateToken(token) {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return false;

    const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString());
    const now = Math.floor(Date.now() / 1000);
    
    return payload.exp > now && payload.iss === APP_ID;
  } catch (error) {
    return false;
  }
}

const app = express();
const server = http.createServer(app);

// Configure CORS for Socket.IO
const io = socketIo(server, {
  cors: {
    origin: "*", // In production, specify your app's domain
    methods: ["GET", "POST"],
    credentials: true,
  },
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({ status: "OK", timestamp: new Date().toISOString() });
});

// ZEGOCLOUD token generation endpoint
app.post("/zego-token", (req, res) => {
  try {
    const { userId, roomId } = req.body;

    // Validate input
    if (!userId || !roomId) {
      return res.status(400).json({
        error: "userId and roomId are required",
      });
    }

    // Generate token (valid for 24 hours)
    const token = generateToken(userId, 86400);

    console.log(`Generated ZEGO token for user ${userId} in room ${roomId}`);

    res.json({
      token,
      userId,
      roomId,
      expiresIn: 86400, // 24 hours in seconds
    });
  } catch (error) {
    console.error("Error generating ZEGO token:", error);
    res.status(500).json({
      error: "Failed to generate token",
      message: error.message,
    });
  }
});

// Token validation endpoint
app.post("/zego-token/validate", (req, res) => {
  try {
    const { token } = req.body;

    if (!token) {
      return res.status(400).json({
        error: "token is required",
      });
    }

    const isValid = validateToken(token);

    res.json({
      valid: isValid,
    });
  } catch (error) {
    console.error("Error validating ZEGO token:", error);
    res.status(500).json({
      error: "Failed to validate token",
      message: error.message,
    });
  }
});

// Store active sessions and participants
const sessions = new Map();
const participants = new Map();

io.on("connection", (socket) => {
  console.log(`Client connected: ${socket.id}`);

  // Join a therapy session
  socket.on("join-session", (data) => {
    const { sessionId, participantId, participantName } = data;

    console.log(
      `${participantName} (${participantId}) joining session ${sessionId}`
    );

    // Store participant info
    participants.set(socket.id, {
      id: participantId,
      name: participantName,
      sessionId,
      socketId: socket.id,
    });

    // Join socket room
    socket.join(sessionId);

    // Initialize session if doesn't exist
    if (!sessions.has(sessionId)) {
      sessions.set(sessionId, {
        id: sessionId,
        participants: new Map(),
        createdAt: new Date(),
      });
    }

    const session = sessions.get(sessionId);
    session.participants.set(participantId, {
      id: participantId,
      name: participantName,
      socketId: socket.id,
      joinedAt: new Date(),
    });

    // Notify participant they joined successfully
    socket.emit("session-joined", {
      sessionId,
      participantId,
      participantCount: session.participants.size,
    });

    // If two participants, notify both that partner is available
    if (session.participants.size === 2) {
      const participantList = Array.from(session.participants.values());
      const partner = participantList.find((p) => p.id !== participantId);

      // Notify current participant about partner
      socket.emit("partner-connected", {
        partnerId: partner.id,
        partnerName: partner.name,
      });

      // Notify partner about current participant
      socket.to(partner.socketId).emit("partner-connected", {
        partnerId: participantId,
        partnerName: participantName,
      });

      console.log(`Session ${sessionId} is ready with both partners`);
    }
  });

  // WebRTC signaling: offer
  socket.on("offer", (data) => {
    const { sessionId, targetId, offer } = data;
    const participant = participants.get(socket.id);

    if (!participant) return;

    console.log(
      `Offer from ${participant.id} to ${targetId} in session ${sessionId}`
    );

    // Find target participant's socket
    const session = sessions.get(sessionId);
    if (session) {
      const target = session.participants.get(targetId);
      if (target) {
        socket.to(target.socketId).emit("offer", {
          fromId: participant.id,
          fromName: participant.name,
          offer,
        });
      }
    }
  });

  // WebRTC signaling: answer
  socket.on("answer", (data) => {
    const { sessionId, targetId, answer } = data;
    const participant = participants.get(socket.id);

    if (!participant) return;

    console.log(
      `Answer from ${participant.id} to ${targetId} in session ${sessionId}`
    );

    // Find target participant's socket
    const session = sessions.get(sessionId);
    if (session) {
      const target = session.participants.get(targetId);
      if (target) {
        socket.to(target.socketId).emit("answer", {
          fromId: participant.id,
          fromName: participant.name,
          answer,
        });
      }
    }
  });

  // WebRTC signaling: ICE candidate
  socket.on("ice-candidate", (data) => {
    const { sessionId, targetId, candidate } = data;
    const participant = participants.get(socket.id);

    if (!participant) return;

    // Find target participant's socket
    const session = sessions.get(sessionId);
    if (session) {
      const target = session.participants.get(targetId);
      if (target) {
        socket.to(target.socketId).emit("ice-candidate", {
          fromId: participant.id,
          candidate,
        });
      }
    }
  });

  // Session end
  socket.on("end-session", (data) => {
    const { sessionId } = data;
    const participant = participants.get(socket.id);

    if (!participant) return;

    console.log(`${participant.name} ending session ${sessionId}`);

    // Notify partner
    socket.to(sessionId).emit("partner-disconnected", {
      partnerId: participant.id,
      partnerName: participant.name,
    });

    // Clean up
    handleDisconnect(socket);
  });

  // Handle disconnection
  socket.on("disconnect", () => {
    console.log(`Client disconnected: ${socket.id}`);
    handleDisconnect(socket);
  });

  function handleDisconnect(socket) {
    const participant = participants.get(socket.id);

    if (participant) {
      const { sessionId, id: participantId, name } = participant;

      // Remove from session
      const session = sessions.get(sessionId);
      if (session) {
        session.participants.delete(participantId);

        // Notify remaining participants
        socket.to(sessionId).emit("partner-disconnected", {
          partnerId: participantId,
          partnerName: name,
        });

        // Clean up empty sessions
        if (session.participants.size === 0) {
          sessions.delete(sessionId);
          console.log(
            `Session ${sessionId} deleted - no participants remaining`
          );
        }
      }

      // Remove participant
      participants.delete(socket.id);
    }
  }
});

// Cleanup old sessions (run every hour)
setInterval(() => {
  const now = new Date();
  const maxAge = 24 * 60 * 60 * 1000; // 24 hours

  for (const [sessionId, session] of sessions.entries()) {
    if (now - session.createdAt > maxAge && session.participants.size === 0) {
      sessions.delete(sessionId);
      console.log(`Cleaned up old session: ${sessionId}`);
    }
  }
}, 60 * 60 * 1000);

const PORT = process.env.PORT || 3000;
server.listen(PORT, "0.0.0.0", () => {
  console.log(`Mend signaling server running on port ${PORT}`);
  console.log(`Health check available at: http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on("SIGTERM", () => {
  console.log("SIGTERM received, shutting down gracefully");
  server.close(() => {
    console.log("Server closed");
    process.exit(0);
  });
});
