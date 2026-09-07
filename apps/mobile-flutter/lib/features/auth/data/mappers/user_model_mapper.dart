import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/user_model.dart';
import '../../domain/models/user_tag_model.dart';

final class UserModelMapper {
  const UserModelMapper._();

  static UserModel fromMap(Map<String, dynamic> data) {
    return UserModel(
      id: (data['uid'] ?? data['id'])?.toString() ?? '',
      username: data['username']?.toString() ?? '',
      email: data['email']?.toString(),
      displayName: data['displayName']?.toString(),
      photoUrl: data['photoUrl']?.toString(),
      nickname: data['nickname']?.toString(),
      avatar: (data['avatar'] ?? data['avatarUrl'] ?? data['photoUrl'])
          ?.toString(),
      bio: data['bio']?.toString(),
      friends: _stringList(data['friends']),
      friendRequests: _stringList(data['friendRequests']),
      tags: _stringList(data['tags']),
      tagDetails: _tagDetails(data['tagDetails']),
      languages: _languages(data['languages']),
      localizedNames: _localizedNames(data['localizedNames']),
      birthday: _dateTime(data['birthday']),
      showAge: data['showAge'] is bool ? data['showAge'] as bool : true,
      createdAt: _dateTime(data['createdAt']),
      lastActive: _dateTime(data['lastActive']),
    );
  }

  static Map<String, dynamic> toFirestoreMap(UserModel user) {
    final data = <String, dynamic>{
      'uid': user.id,
      'username': user.username,
      'email': user.email,
      'displayName': user.displayName,
      'photoUrl': user.photoUrl,
      'nickname': user.nickname,
      'avatar': user.avatar,
      'bio': user.bio,
      'friends': user.friends,
      'friendRequests': user.friendRequests,
      'tags': user.tags,
      'languages': user.languages,
      'localizedNames': user.localizedNames,
      'birthday': _timestamp(user.birthday),
      'showAge': user.showAge,
      'createdAt': _timestamp(user.createdAt),
      'lastActive': _timestamp(user.lastActive),
    };

    data.removeWhere((key, value) => value == null);
    return data;
  }

  static List<String>? _stringList(Object? value) {
    if (value is! List) {
      return null;
    }

    return value.map((item) => item.toString()).toList(growable: false);
  }

  static List<Map<String, dynamic>>? _languages(Object? value) {
    if (value is! List) {
      return null;
    }

    final result = value
        .map<Map<String, dynamic>>((item) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          if (item is String) {
            return {'name': item, 'level': 70};
          }
          return <String, dynamic>{};
        })
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    return result;
  }

  static List<UserTagModel>? _tagDetails(Object? value) {
    if (value is! List) {
      return null;
    }

    final result = value
        .whereType<Map>()
        .map((item) => UserTagModel.fromMap(Map<String, dynamic>.from(item)))
        .where((tag) => tag.value.isNotEmpty)
        .toList(growable: false);

    return result;
  }

  static List<Map<String, dynamic>>? _localizedNames(Object? value) {
    if (value is! List) {
      return null;
    }

    final result = value
        .map<Map<String, dynamic>>((item) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }

          return <String, dynamic>{};
        })
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    return result;
  }

  static DateTime? _dateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static Timestamp? _timestamp(DateTime? value) {
    return value == null ? null : Timestamp.fromDate(value);
  }
}
