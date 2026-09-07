import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/discover_user.dart';
import '../../domain/repositories/discover_repository.dart';

final class FirestoreDiscoverRepository implements DiscoverRepository {
  FirestoreDiscoverRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<DiscoverUser>> watchAllUsers(String currentUserId) {
    return _firestore
        .collection('users')
        .where('uid', isNotEqualTo: currentUserId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(_userFromDocument).toList(growable: false),
        );
  }

  DiscoverUser _userFromDocument(QueryDocumentSnapshot document) {
    final rawData = document.data();
    final data = rawData is Map<String, dynamic>
        ? rawData
        : const <String, dynamic>{};
    final username = data['username']?.toString() ?? '用户';
    final nickname = data['nickname']?.toString() ?? '';
    final localizedNamesRaw = data['localizedNames'];

    final localizedNames = localizedNamesRaw is List
        ? localizedNamesRaw
              .whereType<Map>()
              .map(
                (item) =>
                    Map<String, dynamic>.from(item),
              )
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final avatarUrl =
        data['avatar']?.toString() ??
        data['avatarUrl']?.toString() ??
        data['photoUrl']?.toString() ??
        '';

    return DiscoverUser(
      id: document.id,
      username: username,
      nickname: nickname,
      avatarUrl: avatarUrl,
      localizedNames: localizedNames,
    );
  }
}
