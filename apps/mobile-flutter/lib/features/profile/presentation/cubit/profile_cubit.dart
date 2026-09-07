import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/models/user_model.dart';
import '../../../post/domain/models/post_model.dart';
import '../../../post/domain/repositories/post_repository.dart';
import '../../application/models/local_profile_image.dart';
import '../../application/ports/profile_media_repository.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required PostRepository postRepository,
    required ProfileRepository profileRepository,
    required ProfileMediaRepository mediaRepository,
  }) : _postRepository = postRepository,
       _profileRepository = profileRepository,
       _mediaRepository = mediaRepository,
       super(const ProfileState());

  final PostRepository _postRepository;
  final ProfileRepository _profileRepository;
  final ProfileMediaRepository _mediaRepository;

  Future<void> loadProfile(String uid) async {
    emit(state.copyWith(loadingProfile: true));

    try {
      final profile = await _profileRepository.getProfile(uid);
      if (profile != null) {
        emit(state.copyWith(userProfile: profile));
      }
    } catch (error) {
      debugPrint('加载资料失败: $error');
    } finally {
      emit(state.copyWith(loadingProfile: false));
    }
  }

  Stream<List<PostModel>> watchUserPosts(String uid) {
    return _postRepository.watchUserPosts(uid);
  }

  int totalLikesOf(List<PostModel> posts) {
    return posts.fold<int>(0, (total, post) => total + post.likeCount);
  }

  Future<void> updateTags(String uid, List<String> newTags) {
    final copiedTags = List<String>.from(newTags);
    return _commitOptimistic(
      optimistic: state.userProfile.copyWith(tags: copiedTags),
      persist: () =>
          _profileRepository.updateTags(userId: uid, tags: copiedTags),
    );
  }

  Future<void> updateLanguages(
    String uid,
    List<Map<String, dynamic>> newLanguages,
  ) {
    final copiedLanguages = newLanguages
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);

    return _commitOptimistic(
      optimistic: state.userProfile.copyWith(languages: copiedLanguages),
      persist: () => _profileRepository.updateLanguages(
        userId: uid,
        languages: copiedLanguages,
      ),
    );
  }

  Future<void> updateLocalizedNames(
    String uid,
    List<Map<String, dynamic>> newLocalizedNames,
  ) {
    final copiedLocalizedNames = newLocalizedNames
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);

    return _commitOptimistic(
      optimistic: state.userProfile.copyWith(
        localizedNames: copiedLocalizedNames,
      ),
      persist: () => _profileRepository.updateLocalizedNames(
        userId: uid,
        localizedNames: copiedLocalizedNames,
      ),
    );
  }

  Future<void> updateBirthday(
    String uid,
    DateTime? newBirthday,
    bool newShowAge,
  ) {
    return _commitOptimistic(
      optimistic: state.userProfile.copyWith(
        birthday: newBirthday,
        clearBirthday: newBirthday == null,
        showAge: newShowAge,
      ),
      persist: () => _profileRepository.updateBirthday(
        userId: uid,
        birthday: newBirthday,
        showAge: newShowAge,
      ),
    );
  }

  Future<void> updateAvatar(String uid, File imageFile) async {
    if (state.uploadingAvatar) {
      return;
    }

    emit(state.copyWith(uploadingAvatar: true));

    final previousProfile = state.userProfile;
    final oldAvatarUrl = previousProfile.avatarUrl;
    String? uploadedAvatarUrl;

    try {
      uploadedAvatarUrl = await _mediaRepository.uploadAvatar(
        userId: uid,
        image: LocalProfileImage(path: imageFile.path),
      );

      final updatedProfile = await _profileRepository.updateAvatarUrl(
        userId: uid,
        avatarUrl: uploadedAvatarUrl,
      );
      emit(state.copyWith(userProfile: updatedProfile));

      if (_isRemoteAvatar(oldAvatarUrl) && oldAvatarUrl != uploadedAvatarUrl) {
        try {
          await _mediaRepository.deleteAvatar(oldAvatarUrl);
        } catch (error) {
          debugPrint('删除旧头像失败: $error');
        }
      }
    } catch (error) {
      emit(state.copyWith(userProfile: previousProfile));

      if (uploadedAvatarUrl != null) {
        try {
          await _mediaRepository.deleteAvatar(uploadedAvatarUrl);
        } catch (cleanupError) {
          debugPrint('清理未提交头像失败: $cleanupError');
        }
      }
      rethrow;
    } finally {
      emit(state.copyWith(uploadingAvatar: false));
    }
  }

  Future<void> updateNickname(String uid, String newNickname) {
    return _commitOptimistic(
      optimistic: state.userProfile.copyWith(nickname: newNickname),
      persist: () =>
          _profileRepository.updateNickname(userId: uid, nickname: newNickname),
    );
  }

  Future<void> updateUsername(String uid, String newUsername) {
    return _commitOptimistic(
      optimistic: state.userProfile.copyWith(username: newUsername),
      persist: () =>
          _profileRepository.updateUsername(userId: uid, username: newUsername),
    );
  }

  Future<void> updateBio(String uid, String newBio) {
    return _commitOptimistic(
      optimistic: state.userProfile.copyWith(bio: newBio),
      persist: () => _profileRepository.updateBio(userId: uid, bio: newBio),
    );
  }

  Future<void> _commitOptimistic({
    required UserModel optimistic,
    required Future<UserModel> Function() persist,
  }) async {
    final previous = state.userProfile;
    emit(state.copyWith(userProfile: optimistic));

    try {
      final confirmed = await persist();
      emit(state.copyWith(userProfile: confirmed));
    } catch (_) {
      emit(state.copyWith(userProfile: previous));
      rethrow;
    }
  }

  bool _isRemoteAvatar(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }
}
