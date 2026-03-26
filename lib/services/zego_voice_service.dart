import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

class ZegoVoiceService extends ChangeNotifier {
  static final ZegoVoiceService _instance = ZegoVoiceService._internal();
  factory ZegoVoiceService() => _instance;
  ZegoVoiceService._internal();

  // ZEGOCLOUD configuration - REPLACE WITH YOUR ACTUAL VALUES
  static const int appID = 1390967091; // Replace with your ZEGOCLOUD App ID
  static const String appSign = "11552a1db7c26772508de5585c686f49ab126eb5f1713d3c82c442391483a734"; // Replace with your App Sign

  // Connection state
  bool _isEngineInitialized = false;
  bool _isInRoom = false;
  bool _isConnected = false;
  bool _isMuted = false;
  String? _roomID;
  String? _userID;
  String? _partnerID;
  String? _partnerName;

  // Audio simulation for UI (since we don't have spectrum monitoring)
  Timer? _audioSimulationTimer;
  bool _isLocalAudioActive = false;
  bool _isRemoteAudioActive = false;
  double _localAudioLevel = 0.0;
  double _remoteAudioLevel = 0.0;
  bool _isInterruption = false;
  DateTime? _lastLocalSpeechTime;
  DateTime? _lastRemoteSpeechTime;
  final Duration _interruptionThreshold = const Duration(milliseconds: 500);

  // Remote user status
  bool _isRemoteUserOnline = false;
  bool _isRemoteUserMuted = false;

  // Callbacks
  Function(String)? onError;
  Function()? onPartnerConnected;
  Function()? onPartnerDisconnected;

  // Getters
  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  bool get isLocalAudioActive => _isLocalAudioActive;
  bool get isRemoteAudioActive => _isRemoteAudioActive;
  double get localAudioLevel => _localAudioLevel;
  double get remoteAudioLevel => _remoteAudioLevel;
  bool get isInterruption => _isInterruption;
  String? get partnerName => _partnerName;
  bool get isRemoteUserOnline => _isRemoteUserOnline;
  bool get isRemoteUserMuted => _isRemoteUserMuted;

  /// Initialize the ZEGO Express Engine
  Future<void> initializeEngine() async {
    if (_isEngineInitialized) return;

    try {
      developer.log('=== INITIALIZING ZEGO EXPRESS ENGINE ===');

      // Request microphone permission
      await _requestPermissions();

      // Create engine profile
      ZegoEngineProfile profile = ZegoEngineProfile(
        appID,
        ZegoScenario.StandardVoiceCall, // Optimized for voice calls
        enablePlatformView: false, // We don't need video
        appSign: appSign,
      );

      // Initialize engine
      await ZegoExpressEngine.createEngineWithProfile(profile);
      
      // Set up event handlers
      _setupEventHandlers();

      // Configure audio settings for voice calling
      await _configureAudioSettings();

      _isEngineInitialized = true;
      developer.log('ZEGO Express Engine initialized successfully');
    } catch (e) {
      developer.log('Failed to initialize ZEGO Express Engine: $e');
      rethrow;
    }
  }

  /// Configure audio settings for optimal voice calling
  Future<void> _configureAudioSettings() async {
    try {
      // Set audio config for voice calling with echo cancellation
      ZegoAudioConfig audioConfig = ZegoAudioConfig.preset(ZegoAudioConfigPreset.HighQuality);
      await ZegoExpressEngine.instance.setAudioConfig(audioConfig);

      // CRITICAL: Force disable speaker to prevent echo - use earpiece
      await ZegoExpressEngine.instance.setAudioRouteToSpeaker(false);
      _isSpeakerOn = false;

      // Enable microphone
      await ZegoExpressEngine.instance.muteMicrophone(false);

      // CRITICAL: Enable audio capture device
      await ZegoExpressEngine.instance.enableAudioCaptureDevice(true);
      
      // DISABLE headphone monitor to prevent echo feedback
      await ZegoExpressEngine.instance.enableHeadphoneMonitor(false);
      
      // Enable echo cancellation (AEC) with maximum strength
      await ZegoExpressEngine.instance.enableAEC(true);
      
      // Enable automatic gain control (AGC) to normalize audio levels
      await ZegoExpressEngine.instance.enableAGC(true);
      
      // Enable noise suppression (ANS) for cleaner audio
      await ZegoExpressEngine.instance.enableANS(true);
      
      // Enable sound level monitoring for real audio visualization
      await ZegoExpressEngine.instance.startSoundLevelMonitor();

      // Set audio capture volume (lower to reduce echo)
      await ZegoExpressEngine.instance.setCaptureVolume(80);

      developer.log('Audio settings configured for voice calling with enhanced echo prevention');
    } catch (e) {
      developer.log('Error configuring audio settings: $e');
    }
  }

  /// Set up ZEGO event handlers
  void _setupEventHandlers() {
    // Room state changes
    ZegoExpressEngine.onRoomStateChanged = (String roomID, ZegoRoomStateChangedReason reason, int errorCode, Map<String, dynamic> extendedData) {
      developer.log('Room state changed: $reason, errorCode: $errorCode');
      
      if (reason == ZegoRoomStateChangedReason.Logined) {
        _isInRoom = true;
        _isConnected = true;
        developer.log('Successfully joined room: $roomID');
        notifyListeners();
      } else if (reason == ZegoRoomStateChangedReason.LoginFailed) {
        _isConnected = false;
        developer.log('Failed to join room: $roomID, error: $errorCode');
        onError?.call('Failed to join voice room. Please try again.');
        notifyListeners();
      }
    };

    // User state changes
    ZegoExpressEngine.onRoomUserUpdate = (String roomID, ZegoUpdateType updateType, List<ZegoUser> userList) {
      developer.log('Room user update: $updateType, users: ${userList.length}');
      
      for (var user in userList) {
        if (user.userID != _userID) {
          if (updateType == ZegoUpdateType.Add) {
            _partnerID = user.userID;
            _partnerName = user.userName;
            _isRemoteUserOnline = true;
            developer.log('Partner joined: ${user.userName} (${user.userID})');
            onPartnerConnected?.call();
          } else if (updateType == ZegoUpdateType.Delete) {
            if (user.userID == _partnerID) {
              _isRemoteUserOnline = false;
              developer.log('Partner left: ${user.userName}');
              onPartnerDisconnected?.call();
            }
          }
        }
      }
      notifyListeners();
    };

    // Remote stream updates
    ZegoExpressEngine.onRoomStreamUpdate = (String roomID, ZegoUpdateType updateType, List<ZegoStream> streamList, Map<String, dynamic> extendedData) {
      developer.log('Remote stream update: $updateType, streams: ${streamList.length}');
      
      for (var stream in streamList) {
        if (updateType == ZegoUpdateType.Add) {
          // Start playing the remote stream
          ZegoExpressEngine.instance.startPlayingStream(stream.streamID);
          developer.log('Started playing remote stream: ${stream.streamID}');
        } else if (updateType == ZegoUpdateType.Delete) {
          // Stop playing the remote stream
          ZegoExpressEngine.instance.stopPlayingStream(stream.streamID);
          developer.log('Stopped playing remote stream: ${stream.streamID}');
        }
      }
    };

    // Audio state changes
    ZegoExpressEngine.onRemoteMicStateUpdate = (String streamID, ZegoRemoteDeviceState state) {
      developer.log('Remote mic state update: $streamID, state: $state');
      _isRemoteUserMuted = (state == ZegoRemoteDeviceState.Disable);
      notifyListeners();
    };

    // Audio volume level monitoring - using sound level callback
    ZegoExpressEngine.onCapturedSoundLevelUpdate = (double soundLevel) {
      _localAudioLevel = soundLevel / 100.0; // Convert to 0-1 range
      _isLocalAudioActive = _localAudioLevel > 0.1;
      if (_isLocalAudioActive) {
        _lastLocalSpeechTime = DateTime.now();
      }
      notifyListeners();
    };

    ZegoExpressEngine.onRemoteSoundLevelUpdate = (Map<String, double> soundLevels) {
      if (soundLevels.isNotEmpty) {
        final level = soundLevels.values.first / 100.0; // Convert to 0-1 range
        _remoteAudioLevel = level;
        _isRemoteAudioActive = _remoteAudioLevel > 0.1;
        if (_isRemoteAudioActive) {
          _lastRemoteSpeechTime = DateTime.now();
        }
        notifyListeners();
      }
    };

    // Error handling
    ZegoExpressEngine.onEngineStateUpdate = (ZegoEngineState state) {
      developer.log('Engine state update: $state');
    };

    // Room connection quality monitoring
    ZegoExpressEngine.onNetworkQuality = (String userID, ZegoStreamQualityLevel upstreamQuality, ZegoStreamQualityLevel downstreamQuality) {
      developer.log('Network quality - User: $userID, Up: $upstreamQuality, Down: $downstreamQuality');
    };

    developer.log('ZEGO event handlers set up successfully');
  }

  /// Join a voice room
  Future<void> joinRoom(String roomID, String userID, String userName, {String? token}) async {
    if (!_isEngineInitialized) {
      throw Exception('ZEGO Engine not initialized');
    }

    try {
      developer.log('=== JOINING VOICE ROOM ===');
      developer.log('Room ID: $roomID');
      developer.log('User ID: $userID');
      developer.log('User Name: $userName');

      _roomID = roomID;
      _userID = userID;

      // Create user info
      ZegoUser user = ZegoUser(userID, userName);

      // Room config
      ZegoRoomConfig roomConfig = ZegoRoomConfig.defaultConfig();
      roomConfig.isUserStatusNotify = true; // Get user status updates
      if (token != null) {
        roomConfig.token = token; // Use token if provided
      }

      // Join room
      await ZegoExpressEngine.instance.loginRoom(roomID, user, config: roomConfig);

      // Start publishing audio stream
      await _startPublishing();

      // Start real audio monitoring for UI
      _startRealAudioMonitoring();

      developer.log('Room join process initiated');
    } catch (e) {
      developer.log('Error joining room: $e');
      rethrow;
    }
  }

  /// Start publishing audio stream
  Future<void> _startPublishing() async {
    try {
      // Create stream ID
      String streamID = '${_userID}_audio_stream';
      
      // Start publishing
      await ZegoExpressEngine.instance.startPublishingStream(streamID);

      developer.log('Started publishing audio stream: $streamID');
    } catch (e) {
      developer.log('Error starting audio publishing: $e');
    }
  }

  /// Request microphone permissions
  Future<void> _requestPermissions() async {
    try {
      final microphoneStatus = await Permission.microphone.request();
      
      if (microphoneStatus != PermissionStatus.granted) {
        throw Exception('Microphone permission is required for voice calls');
      }
      
      developer.log('Microphone permission granted');
    } catch (e) {
      developer.log('Failed to request permissions: $e');
      rethrow;
    }
  }

  /// Toggle microphone mute/unmute
  Future<void> toggleMute() async {
    try {
      _isMuted = !_isMuted;
      await ZegoExpressEngine.instance.muteMicrophone(_isMuted);
      developer.log('Microphone ${_isMuted ? 'muted' : 'unmuted'}');
      notifyListeners();
    } catch (e) {
      developer.log('Error toggling mute: $e');
    }
  }

  /// Set mute state
  Future<void> setMuted(bool muted) async {
    if (_isMuted != muted) {
      await toggleMute();
    }
  }

  /// Toggle speaker mode (for echo control) - WARNING: May cause echo
  Future<void> toggleSpeaker() async {
    try {
      // SAFETY: Only allow speaker if user explicitly wants it (may cause echo)
      if (!_isSpeakerOn) {
        // Warning: enabling speaker can cause echo
        developer.log('WARNING: Enabling speaker may cause echo. Use headphones!');
      }
      
      await ZegoExpressEngine.instance.setAudioRouteToSpeaker(!_isSpeakerOn);
      _isSpeakerOn = !_isSpeakerOn;
      
      // If speaker is enabled, reduce capture volume more to minimize echo
      if (_isSpeakerOn) {
        await ZegoExpressEngine.instance.setCaptureVolume(60);
      } else {
        await ZegoExpressEngine.instance.setCaptureVolume(80);
      }
      
      developer.log('Speaker ${_isSpeakerOn ? 'enabled (echo risk)' : 'disabled (recommended)'}');
      notifyListeners();
    } catch (e) {
      developer.log('Error toggling speaker: $e');
    }
  }

  // Speaker state
  bool _isSpeakerOn = false;
  bool get isSpeakerOn => _isSpeakerOn;

  /// Start real audio monitoring for UI visualization
  void _startRealAudioMonitoring() {
    // Start interruption detection timer
    _audioSimulationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _detectInterruptions();
    });

    developer.log('Real audio monitoring started for UI');
  }

  /// Detect interruptions based on speaking patterns
  void _detectInterruptions() {
    bool previousInterruption = _isInterruption;

    // Check if both partners are speaking simultaneously
    if (_isLocalAudioActive && _isRemoteAudioActive) {
      if (_lastLocalSpeechTime != null && _lastRemoteSpeechTime != null) {
        final localRemoteTimeDiff = _lastLocalSpeechTime!
            .difference(_lastRemoteSpeechTime!)
            .abs();
        if (localRemoteTimeDiff < _interruptionThreshold) {
          _isInterruption = true;
        }
      }
    } else {
      _isInterruption = false;
    }

    // Notify listeners only if interruption state changed
    if (previousInterruption != _isInterruption) {
      notifyListeners();
    }
  }

  /// Get current audio statistics for debugging
  Map<String, dynamic> getAudioStats() {
    return {
      'localLevel': _localAudioLevel,
      'remoteLevel': _remoteAudioLevel,
      'localActive': _isLocalAudioActive,
      'remoteActive': _isRemoteAudioActive,
      'isInterruption': _isInterruption,
      'isConnected': _isConnected,
      'isInRoom': _isInRoom,
      'isMuted': _isMuted,
      'isRemoteUserOnline': _isRemoteUserOnline,
      'isRemoteUserMuted': _isRemoteUserMuted,
      'roomID': _roomID,
      'userID': _userID,
      'partnerID': _partnerID,
    };
  }

  /// Leave the current room
  Future<void> leaveRoom() async {
    try {
      if (_isInRoom && _roomID != null) {
        developer.log('Leaving room: $_roomID');
        
        // Stop publishing
        await ZegoExpressEngine.instance.stopPublishingStream();
        
        // Leave room
        await ZegoExpressEngine.instance.logoutRoom(_roomID!);
        
        _isInRoom = false;
        _isConnected = false;
        _roomID = null;
        _partnerID = null;
        _partnerName = null;
        _isRemoteUserOnline = false;
        
        developer.log('Successfully left room');
        notifyListeners();
      }
    } catch (e) {
      developer.log('Error leaving room: $e');
    }
  }

  /// Clean shutdown
  @override
  Future<void> dispose() async {
    _audioSimulationTimer?.cancel();

    // Stop sound level monitoring
    if (_isEngineInitialized) {
      try {
        await ZegoExpressEngine.instance.stopSoundLevelMonitor();
        developer.log('Sound level monitoring stopped');
      } catch (e) {
        developer.log('Error stopping sound level monitor: $e');
      }
    }

    // Leave room if still in one
    await leaveRoom();

    // Destroy engine
    if (_isEngineInitialized) {
      await ZegoExpressEngine.destroyEngine();
      _isEngineInitialized = false;
    }

    // Reset state
    _isConnected = false;
    _isLocalAudioActive = false;
    _isRemoteAudioActive = false;
    _localAudioLevel = 0.0;
    _remoteAudioLevel = 0.0;
    _isInterruption = false;

    super.dispose();
  }

  /// Force end session (for UI session end)
  Future<void> endSession() async {
    await dispose();
  }

  /// Diagnose audio pipeline for debugging
  Future<void> diagnoseAudioPipeline() async {
    developer.log('=== ZEGO AUDIO PIPELINE DIAGNOSTIC ===');
    developer.log('Engine initialized: $_isEngineInitialized');
    developer.log('In room: $_isInRoom');
    developer.log('Connected: $_isConnected');
    developer.log('Room ID: $_roomID');
    developer.log('User ID: $_userID');
    developer.log('Partner ID: $_partnerID');
    developer.log('Is muted: $_isMuted');
    developer.log('Local audio active: $_isLocalAudioActive');
    developer.log('Remote audio active: $_isRemoteAudioActive');
    developer.log('Remote user online: $_isRemoteUserOnline');
    developer.log('Remote user muted: $_isRemoteUserMuted');
    developer.log('=== DIAGNOSTIC COMPLETE ===');
  }
}