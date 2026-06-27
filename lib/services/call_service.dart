import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CallService {
  CallService._();

  static final CallService instance = CallService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;
  String? get currentUserName => _auth.currentUser?.displayName;

  /// Creates a new call document in Firestore and sets its status to "ringing".
  Future<String> createCall({
    required String calleeId,
    required String calleeName,
  }) async {
    final callerId = currentUserId;
    final callerName = currentUserName ?? 'Unknown Caller';

    if (callerId == null) {
      throw Exception('User must be logged in to make a call.');
    }

    final callDoc = _firestore.collection('calls').doc();
    await callDoc.set({
      'callerId': callerId,
      'callerName': callerName,
      'calleeId': calleeId,
      'calleeName': calleeName,
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
    });

    print('Call document created with ID: ${callDoc.id}');
    return callDoc.id;
  }

  /// Listens for incoming calls targeting the current user that are in "ringing" status.
  Stream<QuerySnapshot<Map<String, dynamic>>> listenForIncomingCall() {
    final uid = currentUserId;
    if (uid == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('calls')
        .where('calleeId', isEqualTo: uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots();
  }

  /// Stream to listen to updates on a specific call document.
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToCall(String callId) {
    return _firestore.collection('calls').doc(callId).snapshots();
  }

  /// Sends the SDP offer for the call.
  Future<void> sendOffer(String callId, Map<String, dynamic> offer) async {
    print('Sending SDP Offer for call: $callId');
    await _firestore.collection('calls').doc(callId).update({
      'offer': offer,
    });
  }

  /// Sends the SDP answer for the call.
  Future<void> sendAnswer(String callId, Map<String, dynamic> answer) async {
    print('Sending SDP Answer for call: $callId');
    await _firestore.collection('calls').doc(callId).update({
      'answer': answer,
    });
  }

  /// Sends an ICE candidate to the appropriate subcollection.
  Future<void> sendIceCandidate(
    String callId,
    Map<String, dynamic> candidate,
    bool isCaller,
  ) async {
    final subcollection = isCaller ? 'callerCandidates' : 'calleeCandidates';
    print('Sending ICE candidate to $subcollection for call: $callId');
    await _firestore
        .collection('calls')
        .doc(callId)
        .collection(subcollection)
        .add(candidate);
  }

  /// Listens to ICE candidates sent by the remote peer.
  /// If the current user is the caller, they listen to 'calleeCandidates'.
  /// If the current user is the callee, they listen to 'callerCandidates'.
  Stream<QuerySnapshot<Map<String, dynamic>>> listenForRemoteIceCandidates(
    String callId,
    bool isCaller,
  ) {
    final subcollection = isCaller ? 'calleeCandidates' : 'callerCandidates';
    return _firestore
        .collection('calls')
        .doc(callId)
        .collection(subcollection)
        .snapshots();
  }

  /// Updates the call status to end the call (e.g. "rejected", "ended").
  Future<void> endCall(String callId, {String status = 'ended'}) async {
    print('Ending call: $callId with status: $status');
    await _firestore.collection('calls').doc(callId).update({
      'status': status,
    });
  }
}
