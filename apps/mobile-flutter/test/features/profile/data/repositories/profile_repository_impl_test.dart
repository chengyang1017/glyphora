import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glyphora_mobile/features/auth/domain/models/user_model.dart';
import 'package:glyphora_mobile/features/auth/domain/models/user_tag_model.dart';
import 'package:glyphora_mobile/features/auth/domain/repositories/user_backend_repository.dart';
import 'package:glyphora_mobile/features/profile/data/repositories/profile_repository_impl.dart';

void main() {
  group('ProfileRepositoryImpl', () {
    late _FakeUserBackendRepository userRepository;
    late ProfileRepositoryImpl repository;

    setUp(() {
      userRepository = _FakeUserBackendRepository();
      repository = ProfileRepositoryImpl(
        userRepository: userRepository,
        firestore: _ThrowingFirebaseFirestore(),
      );
    });

    test('getProfile delegates to backend repository', () async {
      const profile = UserModel(id: 'user-1', username: 'alice');
      userRepository.user = profile;

      final result = await repository.getProfile('user-1');

      expect(result, same(profile));
      expect(userRepository.lastUserId, 'user-1');
    });

    test(
      'updateTags copies payload and returns backend-confirmed user',
      () async {
        const confirmed = UserModel(id: 'user-1', username: 'alice');

        userRepository.updateResult = confirmed;

        final tags = <UserTagModel>[
          const UserTagModel(value: 'flutter'),
          const UserTagModel(value: 'nom'),
        ];

        final result = await repository.updateTags(
          userId: 'user-1',
          tags: tags,
        );

        expect(result, same(confirmed));

        expect(userRepository.lastUpdate, {
          'tags': [
            {
              'value': 'flutter',
              'languageCode': '',
              'scriptCode': '',
              'translations': [],
            },
            {
              'value': 'nom',
              'languageCode': '',
              'scriptCode': '',
              'translations': [],
            },
          ],
        });

        tags.add(const UserTagModel(value: 'changed-after-call'));

        expect(userRepository.lastUpdate!['tags'], [
          {
            'value': 'flutter',
            'languageCode': '',
            'scriptCode': '',
            'translations': [],
          },
          {
            'value': 'nom',
            'languageCode': '',
            'scriptCode': '',
            'translations': [],
          },
        ]);
      },
    );

    test('updateLanguages deep-copies language maps', () async {
      userRepository.updateResult = const UserModel(
        id: 'user-1',
        username: 'alice',
      );
      final languages = <Map<String, dynamic>>[
        {'name': 'Vietnamese', 'level': 80},
      ];

      await repository.updateLanguages(userId: 'user-1', languages: languages);

      expect(userRepository.lastUpdate, {
        'languages': [
          {'name': 'Vietnamese', 'level': 80},
        ],
      });
      languages.first['level'] = 10;
      expect(
        (userRepository.lastUpdate!['languages'] as List).first['level'],
        80,
      );
    });

    test('updateBirthday sends ISO birthday and showAge to backend', () async {
      userRepository.updateResult = const UserModel(
        id: 'user-1',
        username: 'alice',
      );
      final birthday = DateTime.utc(2000, 5, 6);

      await repository.updateBirthday(
        userId: 'user-1',
        birthday: birthday,
        showAge: false,
      );

      expect(userRepository.lastUpdate, {
        'birthday': birthday.toIso8601String(),
        'showAge': false,
      });
    });

    test('updateBirthday sends null when birthday is cleared', () async {
      userRepository.updateResult = const UserModel(
        id: 'user-1',
        username: 'alice',
      );

      await repository.updateBirthday(
        userId: 'user-1',
        birthday: null,
        showAge: true,
      );

      expect(userRepository.lastUpdate, {'birthday': null, 'showAge': true});
    });

    test(
      'updateNickname converts empty nickname to null for backend',
      () async {
        userRepository.updateResult = const UserModel(
          id: 'user-1',
          username: 'alice',
        );

        await repository.updateNickname(userId: 'user-1', nickname: '');

        expect(userRepository.lastUpdate, {'nickname': null});
      },
    );

    test('simple profile mutations send the expected backend fields', () async {
      userRepository.updateResult = const UserModel(
        id: 'user-1',
        username: 'alice',
      );

      await repository.updateAvatarUrl(
        userId: 'user-1',
        avatarUrl: 'https://example.com/avatar.png',
      );
      expect(userRepository.lastUpdate, {
        'avatarUrl': 'https://example.com/avatar.png',
      });

      await repository.updateUsername(userId: 'user-1', username: 'alice2');
      expect(userRepository.lastUpdate, {'username': 'alice2'});

      await repository.updateBio(userId: 'user-1', bio: 'hello');
      expect(userRepository.lastUpdate, {'bio': 'hello'});
    });

    test(
      'backend failure is rethrown instead of being hidden by mirror',
      () async {
        userRepository.updateError = StateError('backend failed');

        await expectLater(
          repository.updateBio(userId: 'user-1', bio: 'hello'),
          throwsA(isA<StateError>()),
        );
      },
    );
  });
}

final class _FakeUserBackendRepository implements UserBackendRepository {
  UserModel? user;
  UserModel? updateResult;
  Object? updateError;
  String? lastUserId;
  Map<String, dynamic>? lastUpdate;

  @override
  Future<UserModel?> getUser(String uid) async {
    lastUserId = uid;
    return user;
  }

  @override
  Future<UserModel> updateCurrentUser(Map<String, dynamic> data) async {
    lastUpdate = Map<String, dynamic>.from(data);
    final error = updateError;
    if (error != null) throw error;
    return updateResult!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A Firestore placeholder that makes every mirror access fail immediately.
/// ProfileRepositoryImpl intentionally swallows mirror failures, which lets
/// these tests verify that PostgreSQL/backend results remain authoritative.
final class _ThrowingFirebaseFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw StateError('Firestore mirror unavailable in unit test');
  }
}
