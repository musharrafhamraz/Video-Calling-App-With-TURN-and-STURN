import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/call_service.dart';
import '../theme/app_colors.dart';
import '../utils/webrtc_diagnostics.dart';
import '../widgets/glass_panel.dart';
import 'call_end_screen.dart';

class CallScreen extends StatefulWidget {
  final String targetUid;
  final String targetName;
  final String? callId;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.targetUid,
    required this.targetName,
    this.callId,
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  String? _activeCallId;
  String _status = 'Initializing...';
  bool _isAccepted = false;
  bool _isCaller = false;
  DateTime? _callStartTime;

  // Prevents double-dispose crashes
  bool _cleanupDone = false;

  StreamSubscription? _callDocSub;
  StreamSubscription? _remoteIceSub;

  // WebRTC
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  // ICE candidates buffered before _activeCallId is available
  final List<Map<String, dynamic>> _pendingLocalCandidates = [];

  // Diagnostics — logs connection type, codec, bitrate, resolution, audio quality
  WebRTCDiagnostics? _diagnostics;

  bool _isCameraEnabled = true;
  bool _isMicMuted = false;
  bool _isFrontCamera = true;

  @override
  void initState() {
    super.initState();
    _activeCallId = widget.callId;

    _initWebRTC().then((_) {
      if (_activeCallId == null) {
        // Caller flow
        _isCaller = true;
        if (mounted) setState(() => _status = 'Calling...');
        _initiateCall();
      } else {
        // Callee flow — start ICE listening immediately so we don't miss candidates
        _isCaller = false;
        if (mounted) setState(() => _status = 'Incoming call...');
        _listenToRemoteIceCandidates(_activeCallId!, isCaller: false);
        _listenToCallDoc(_activeCallId!, isCaller: false);
      }
    });
  }

  @override
  void dispose() {
    _doCleanup();
    super.dispose();
  }

  // ── WebRTC Init ───────────────────────────────────────────────────────────

  Future<void> _initWebRTC() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    await [Permission.camera, Permission.microphone].request();

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        'sampleRate': 48000,
      },
      'video': {
        'facingMode': _isFrontCamera ? 'user' : 'environment',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
        'frameRate': {'ideal': 30},
      },
    });

    _localRenderer.srcObject = _localStream;
    if (mounted) setState(() {});

    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.relay.metered.ca:80'},
        {
          'urls': 'turn:global.relay.metered.ca:80',
          'username': '17d8d31aab6c7fd2b51468db',
          'credential': '/KH9UHSVfNiW6hE5',
        },
        {
          'urls': 'turn:global.relay.metered.ca:80?transport=tcp',
          'username': '17d8d31aab6c7fd2b51468db',
          'credential': '/KH9UHSVfNiW6hE5',
        },
        {
          'urls': 'turn:global.relay.metered.ca:443',
          'username': '17d8d31aab6c7fd2b51468db',
          'credential': '/KH9UHSVfNiW6hE5',
        },
        {
          'urls': 'turns:global.relay.metered.ca:443?transport=tcp',
          'username': '17d8d31aab6c7fd2b51468db',
          'credential': '/KH9UHSVfNiW6hE5',
        },
      ],
      'sdpSemantics': 'unified-plan',
    });

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    // ── Bitrate & quality control via RTCRtpSender.setParameters() ──
    await _configureSenderParameters();

    // ── ICE & connection state logging ──
    _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      print('[WebRTC] ICE Connection State: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        if (mounted) setState(() => _status = 'Connection failed');
      } else if (state ==
          RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        if (mounted) setState(() => _status = 'Reconnecting...');
      } else if (state ==
          RTCIceConnectionState.RTCIceConnectionStateConnected) {
        // Connection established — start diagnostics
        _diagnostics ??= WebRTCDiagnostics(_peerConnection!);
        _diagnostics!.start(intervalSeconds: 5);
      }
    };

    _peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      print('[WebRTC] Peer Connection State: $state');
    };

    // Buffer ICE candidates if call ID isn't known yet (happens during offer creation)
    _peerConnection?.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      final callId = _activeCallId;
      if (callId != null) {
        CallService.instance.sendIceCandidate(callId, candidate.toMap(), _isCaller);
      } else {
        // Buffer until we have the call ID
        _pendingLocalCandidates.add(candidate.toMap());
      }
    };

    // Fallback for some implementations
    _peerConnection?.onAddStream = (stream) {
      _remoteRenderer.srcObject = stream;
      if (mounted) setState(() {});
    };

    // Capture remote video + audio streams
    _peerConnection?.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
        if (mounted) setState(() {});
      }
    };
  }

  /// Configure video sender with explicit bitrate limits and degradation preference.
  Future<void> _configureSenderParameters() async {
    if (_peerConnection == null) return;
    try {
      final senders = await _peerConnection!.getSenders();
      for (final sender in senders) {
        if (sender.track?.kind == 'video') {
          final params = sender.parameters;
          // Prefer maintaining resolution over framerate when bandwidth is limited
          params.degradationPreference =
              RTCDegradationPreference.MAINTAIN_RESOLUTION;
          if (params.encodings == null || params.encodings!.isEmpty) {
            params.encodings = [RTCRtpEncoding()];
          }
          params.encodings![0].maxBitrate = 1500000; // 1.5 Mbps cap
          params.encodings![0].minBitrate = 500000; // 500 kbps floor
          await sender.setParameters(params);
          print('[WebRTC] Video sender configured: '
              'maxBitrate=1.5Mbps, minBitrate=500kbps, '
              'degradation=MAINTAIN_RESOLUTION');
        }
      }
    } catch (e) {
      print('[WebRTC] Warning: could not configure sender parameters: $e');
    }
  }

  // ── Call Signaling ────────────────────────────────────────────────────────

  Future<void> _initiateCall() async {
    try {
      final callId = await CallService.instance.createCall(
        calleeId: widget.targetUid,
        calleeName: widget.targetName,
      );

      if (!mounted) return;
      setState(() => _activeCallId = callId);

      // Flush any ICE candidates that were generated before callId was set
      for (final c in _pendingLocalCandidates) {
        await CallService.instance.sendIceCandidate(callId, c, true);
      }
      _pendingLocalCandidates.clear();

      // Create and send SDP offer
      final offer = await _peerConnection?.createOffer();
      if (offer != null) {
        await _peerConnection?.setLocalDescription(offer);
        await CallService.instance.sendOffer(callId, offer.toMap());
      }

      // Start listeners
      _listenToCallDoc(callId, isCaller: true);
      _listenToRemoteIceCandidates(callId, isCaller: true);
    } catch (e) {
      if (mounted) setState(() => _status = 'Call initialization failed.');
    }
  }

  void _listenToCallDoc(String callId, {required bool isCaller}) {
    _callDocSub?.cancel();
    _callDocSub =
        CallService.instance.listenToCall(callId).listen((snapshot) async {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data();
      if (data == null) return;

      final status = data['status'] as String? ?? 'ringing';
      final answer = data['answer'] as Map<String, dynamic>?;

      if (status == 'rejected' || status == 'ended') {
        _navigateToEndScreen();
        return;
      }

      if (mounted) {
        setState(() {
          if (status == 'accepted') {
            if (!_isAccepted) _callStartTime = DateTime.now();
            _isAccepted = true;
            _status = 'Connected';
          } else if (status == 'ringing') {
            _status = isCaller ? 'Ringing...' : 'Incoming Call...';
          }
        });
      }

      // Caller: once callee sends answer, set remote description
      if (isCaller && status == 'accepted' && answer != null) {
        final currentDesc = await _peerConnection?.getRemoteDescription();
        if (currentDesc == null) {
          final sessionDesc =
              RTCSessionDescription(answer['sdp'], answer['type']);
          await _peerConnection?.setRemoteDescription(sessionDesc);
        }
      }
    });
  }

  void _listenToRemoteIceCandidates(String callId, {required bool isCaller}) {
    _remoteIceSub?.cancel();
    _remoteIceSub = CallService.instance
        .listenForRemoteIceCandidates(callId, isCaller)
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;
          final candidate = RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          );
          _peerConnection?.addCandidate(candidate);
        }
      }
    });
  }

  Future<void> _acceptCall() async {
    final callId = _activeCallId;
    if (callId == null) return;

    try {
      // Get the call document with the offer
      final doc = await CallService.instance.listenToCall(callId).first;
      final data = doc.data();
      if (data == null) return;

      final offer = data['offer'] as Map<String, dynamic>?;
      if (offer != null) {
        final sessionDesc = RTCSessionDescription(offer['sdp'], offer['type']);
        await _peerConnection?.setRemoteDescription(sessionDesc);

        final answer = await _peerConnection?.createAnswer();
        if (answer != null) {
          await _peerConnection?.setLocalDescription(answer);
          await CallService.instance.sendAnswer(callId, answer.toMap());
        }
      }

      // Mark as accepted in Firestore
      await CallService.instance.endCall(callId, status: 'accepted');

      if (mounted) {
        setState(() {
          _callStartTime = DateTime.now();
          _isAccepted = true;
          _status = 'Connected';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Error accepting call.');
    }
  }

  Future<void> _declineOrEndCall() async {
    final callId = _activeCallId;
    if (callId != null) {
      final endStatus =
          _isAccepted ? 'ended' : (_isCaller ? 'ended' : 'rejected');
      try {
        await CallService.instance.endCall(callId, status: endStatus);
      } catch (_) {}
    }
    _navigateToEndScreen();
  }

  // Navigates to CallEndScreen, ensuring cleanup only happens once
  void _navigateToEndScreen() {
    if (!mounted) return;
    _doCleanup();
    final duration = _callStartTime != null
        ? DateTime.now().difference(_callStartTime!)
        : Duration.zero;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallEndScreen(
          peerName: widget.targetName,
          duration: duration,
        ),
      ),
    );
  }

  // Safe, idempotent cleanup — safe to call multiple times
  void _doCleanup() {
    if (_cleanupDone) return;
    _cleanupDone = true;

    // Stop diagnostics logging
    _diagnostics?.stop();
    _diagnostics = null;

    _callDocSub?.cancel();
    _remoteIceSub?.cancel();
    _callDocSub = null;
    _remoteIceSub = null;

    _localStream?.getTracks().forEach((track) {
      try {
        track.stop();
      } catch (_) {}
    });
    try {
      _localStream?.dispose();
    } catch (_) {}
    try {
      _peerConnection?.dispose();
    } catch (_) {}
    try {
      _localRenderer.dispose();
    } catch (_) {}
    try {
      _remoteRenderer.dispose();
    } catch (_) {}
  }

  // ── Media Controls ────────────────────────────────────────────────────────

  void _toggleMic() {
    final audioTracks = _localStream?.getAudioTracks() ?? [];
    if (audioTracks.isNotEmpty) {
      final track = audioTracks[0];
      track.enabled = !track.enabled;
      setState(() => _isMicMuted = !track.enabled);
    }
  }

  void _toggleCamera() {
    final videoTracks = _localStream?.getVideoTracks() ?? [];
    if (videoTracks.isNotEmpty) {
      final track = videoTracks[0];
      track.enabled = !track.enabled;
      setState(() => _isCameraEnabled = track.enabled);
    }
  }

  Future<void> _switchCamera() async {
    final videoTracks = _localStream?.getVideoTracks() ?? [];
    if (videoTracks.isNotEmpty) {
      await Helper.switchCamera(videoTracks[0]);
      setState(() => _isFrontCamera = !_isFrontCamera);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Full-screen remote video (or gradient background while waiting)
          if (_isAccepted)
            Positioned.fill(
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.background,
                      AppColors.primaryContainer.withOpacity(0.2),
                    ],
                  ),
                ),
              ),
            ),

          // Local video PiP (picture-in-picture)
          if (_isCameraEnabled)
            Positioned(
              top: 80,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 120,
                  height: 180,
                  color: AppColors.surfaceContainerLowest,
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: _isFrontCamera,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

          // Top bar (shown only when connected)
          if (_isAccepted)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GlassPanel(
                borderRadius: BorderRadius.zero,
                padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top,
                    bottom: 16,
                    left: 16,
                    right: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      const Icon(Icons.videocam_rounded,
                          color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Connect',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                  color: AppColors.primaryFixed,
                                  fontWeight: FontWeight.bold)),
                    ]),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.targetName,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: AppColors.onSurface)),
                        Row(children: [
                          Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                  color: AppColors.secondary,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text('Active',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: AppColors.secondary)),
                        ]),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Ringing / incoming call UI
          if (!_isAccepted)
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            width: 2),
                        boxShadow: [
                          BoxShadow(
                              color:
                                  AppColors.primaryContainer.withOpacity(0.2),
                              blurRadius: 40,
                              spreadRadius: 10)
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          color: AppColors.surfaceContainerHigh,
                          child: const Icon(Icons.person,
                              size: 60, color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(widget.targetName,
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_status,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
            ),

          // Bottom call controls
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: _buildControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    if (_isAccepted) {
      // Connected controls
      return GlassPanel(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        borderRadius: BorderRadius.circular(32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _controlBtn(
                icon: _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: 'Mute',
                isActive: !_isMicMuted,
                onTap: _toggleMic),
            _controlBtn(
                icon: !_isCameraEnabled
                    ? Icons.videocam_off_rounded
                    : Icons.videocam_rounded,
                label: 'Camera',
                isActive: _isCameraEnabled,
                onTap: _toggleCamera),
            // End call — prominent centre button
            _endCallBtn('End', _declineOrEndCall),
            _controlBtn(
                icon: Icons.flip_camera_ios_rounded,
                label: 'Flip',
                isActive: true,
                onTap: _switchCamera),
            _controlBtn(
                icon: Icons.more_vert_rounded,
                label: 'More',
                isActive: true,
                onTap: () {}),
          ],
        ),
      );
    }

    if (widget.isIncoming && !_isAccepted) {
      // Incoming — decline / accept
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _actionBtn(
              icon: Icons.call_end_rounded,
              label: 'Decline',
              color: AppColors.error,
              iconColor: AppColors.onError,
              onTap: _declineOrEndCall),
          _actionBtn(
              icon: Icons.call_rounded,
              label: 'Accept',
              color: AppColors.secondary,
              iconColor: AppColors.onSecondary,
              onTap: _acceptCall),
        ],
      );
    }

    // Outgoing — cancel
    return Center(
      child: _actionBtn(
          icon: Icons.call_end_rounded,
          label: 'Cancel',
          color: AppColors.error,
          iconColor: AppColors.onError,
          onTap: _declineOrEndCall),
    );
  }

  Widget _endCallBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AppColors.error.withOpacity(0.3), blurRadius: 12)
              ]),
          child: const Icon(Icons.call_end_rounded,
              color: AppColors.onError, size: 32),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.error, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.3), blurRadius: 12)
              ]),
          child: Icon(icon, color: iconColor, size: 32),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ]),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withOpacity(0.1)
                : AppColors.error.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
                color: isActive
                    ? Colors.white.withOpacity(0.2)
                    : AppColors.error.withOpacity(0.5)),
          ),
          child: Icon(icon,
              color: isActive ? AppColors.onSurface : AppColors.error,
              size: 24),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.onSurfaceVariant)),
      ]),
    );
  }
}
