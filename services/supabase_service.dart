import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Current logged-in user
  static String? get currentUserId {
    return _client.auth.currentUser?.id;
  }

  // -----------------------------
  // VIDEO
  // -----------------------------

  static Future<Map<String, dynamic>?> createVideo({
    required String title,
    String? description,
    String? videoUrl,
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('User is not logged in');
    }

    final result = await _client
        .from('videos')
        .insert({
          'uploader_id': userId,
          'title': title,
          'description': description,
          'video_url': videoUrl,
        })
        .select()
        .single();

    return result;
  }

  // -----------------------------
  // LIKE
  // -----------------------------

  static Future<void> likeVideo(int videoId) async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('User is not logged in');
    }

    await _client.from('video_likes').insert({
      'video_id': videoId,
      'user_id': userId,
    });
  }

  static Future<void> unlikeVideo(int videoId) async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('User is not logged in');
    }

    await _client
        .from('video_likes')
        .delete()
        .eq('video_id', videoId)
        .eq('user_id', userId);
  }

  // -----------------------------
  // VIEW
  // -----------------------------

  static Future<void> recordView(int videoId) async {
    final userId = currentUserId;

    if (userId == null) {
      return;
    }

    await _client.from('video_views').upsert(
      {
        'video_id': videoId,
        'user_id': userId,
      },
      onConflict: 'video_id,user_id',
    );
  }

  // -----------------------------
  // SHARE
  // -----------------------------

  static Future<void> recordShare(int videoId) async {
    final userId = currentUserId;

    if (userId == null) {
      return;
    }

    await _client.from('video_shares').upsert(
      {
        'video_id': videoId,
        'user_id': userId,
      },
      onConflict: 'video_id,user_id',
    );
  }

  // -----------------------------
  // COUNTS
  // -----------------------------

  static Future<int> getLikeCount(int videoId) async {
    final result = await _client
        .from('video_likes')
        .select('user_id')
        .eq('video_id', videoId);

    return (result as List).length;
  }

  static Future<int> getViewCount(int videoId) async {
    final result = await _client
        .from('video_views')
        .select('user_id')
        .eq('video_id', videoId);

    return (result as List).length;
  }

  static Future<int> getShareCount(int videoId) async {
    final result = await _client
        .from('video_shares')
        .select('user_id')
        .eq('video_id', videoId);

    return (result as List).length;
  }
}
