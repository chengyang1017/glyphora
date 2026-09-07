import '../../../auth/domain/models/user_model.dart';

class ProfileState {
  const ProfileState({
    this.userProfile = const UserModel(id: '', username: ''),
    this.loadingProfile = true,
    this.uploadingAvatar = false,
  });

  final UserModel userProfile;
  final bool loadingProfile;
  final bool uploadingAvatar;

  String get avatarUrl => userProfile.avatarUrl;
  String get username => userProfile.username;
  String get nickname => userProfile.nicknameText;
  String get bio => userProfile.bioText;
  List<String> get tags => userProfile.tagsList;
  List<Map<String, dynamic>> get languages => userProfile.languageList;
  List<Map<String, dynamic>> get localizedNames =>
    userProfile.localizedNameList;
  DateTime? get birthday => userProfile.birthday;
  bool get showAge => userProfile.showAge;
  String get displayName => userProfile.profileDisplayName;

  ProfileState copyWith({
    UserModel? userProfile,
    bool? loadingProfile,
    bool? uploadingAvatar,
  }) {
    return ProfileState(
      userProfile: userProfile ?? this.userProfile,
      loadingProfile: loadingProfile ?? this.loadingProfile,
      uploadingAvatar: uploadingAvatar ?? this.uploadingAvatar,
    );
  }
}
