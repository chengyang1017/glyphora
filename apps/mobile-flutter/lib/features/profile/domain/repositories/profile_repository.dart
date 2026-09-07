import '../../../auth/domain/models/user_model.dart';
import '../../../auth/domain/models/user_tag_model.dart';

/// Domain boundary for profile reads and profile mutations.
///
/// PostgreSQL is the source of truth for authoritative profile reads and
/// mutations. Realtime projections may be backed by migration infrastructure,
/// but transport-specific types must not leak through this contract.
abstract interface class ProfileRepository {
  Future<UserModel?> getProfile(String userId);

  Stream<UserModel?> watchProfile(String userId);

  Future<UserModel> updateTags({
    required String userId,
    required List<UserTagModel> tags,
  });

  Future<UserModel> updateLanguages({
    required String userId,
    required List<Map<String, dynamic>> languages,
  });

  Future<UserModel> updateLocalizedNames({
    required String userId,
    required List<Map<String, dynamic>> localizedNames,
  });

  Future<UserModel> updateBirthday({
    required String userId,
    required DateTime? birthday,
    required bool showAge,
  });

  Future<UserModel> updateAvatarUrl({
    required String userId,
    required String avatarUrl,
  });

  Future<UserModel> updateNickname({
    required String userId,
    required String nickname,
  });

  Future<UserModel> updateUsername({
    required String userId,
    required String username,
  });

  Future<UserModel> updateBio({required String userId, required String bio});
}
