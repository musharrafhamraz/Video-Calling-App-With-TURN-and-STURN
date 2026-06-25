/// Represents a call document in Firestore `calls/{callId}`.
///
/// The full SDP / ICE fields will be added in Phase 3 (WebRTC signaling).
class CallModel {
  final String callId;
  final String callerId;
  final String calleeId;

  /// 'ringing' | 'active' | 'ended'
  final String status;

  const CallModel({
    required this.callId,
    required this.callerId,
    required this.calleeId,
    required this.status,
  });

  factory CallModel.fromMap(String callId, Map<String, dynamic> map) {
    return CallModel(
      callId: callId,
      callerId: map['callerId'] as String? ?? '',
      calleeId: map['calleeId'] as String? ?? '',
      status: map['status'] as String? ?? 'ended',
    );
  }

  Map<String, dynamic> toMap() => {
        'callerId': callerId,
        'calleeId': calleeId,
        'status': status,
      };
}
