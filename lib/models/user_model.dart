/// Represents a user in the app (mirrors the Firestore `users/{uid}` document).
class UserModel {
  final String uid;
  final String displayName;
  final String? fcmToken;
  final bool isOnline;

  const UserModel({
    required this.uid,
    required this.displayName,
    this.fcmToken,
    this.isOnline = false,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      displayName: map['displayName'] as String? ?? '',
      fcmToken: map['fcmToken'] as String?,
      isOnline: map['isOnline'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'isOnline': isOnline,
        if (fcmToken != null) 'fcmToken': fcmToken,
      };
}
