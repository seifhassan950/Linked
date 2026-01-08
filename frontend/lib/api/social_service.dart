import 'api_client.dart';

class SocialProfile {
  final String userId;
  final String username;
  final String? bio;
  final String? avatarUrl;
  final int posts;
  final int followers;
  final int following;
  final bool isFollowing;
  final bool isSelf;

  const SocialProfile({
    required this.userId,
    required this.username,
    required this.bio,
    required this.avatarUrl,
    required this.posts,
    required this.followers,
    required this.following,
    required this.isFollowing,
    required this.isSelf,
  });

  factory SocialProfile.fromJson(Map<String, dynamic> json) {
    return SocialProfile(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      bio: json['bio']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      posts: (json['posts'] ?? 0) as int,
      followers: (json['followers'] ?? 0) as int,
      following: (json['following'] ?? 0) as int,
      isFollowing: json['is_following'] == true,
      isSelf: json['is_self'] == true,
    );
  }
}

class SocialService {
  SocialService(this._api);

  final ApiClient _api;

  Future<SocialProfile> getProfile(String userId) async {
    final data = await _api.getJson('/social/profile/$userId', auth: true);
    return SocialProfile.fromJson(data);
  }

  Future<void> follow(String userId) async {
    await _api.postJson('/social/follow/$userId', auth: true);
  }

  Future<void> unfollow(String userId) async {
    await _api.deleteJson('/social/follow/$userId', auth: true);
  }
}
