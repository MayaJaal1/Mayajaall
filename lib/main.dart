import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

// ═══════════════════════════════════════════════════════
// CONFIG
// ═══════════════════════════════════════════════════════
const String webClientId = '96139047750-5ooi0pbvch98qu447somuurh6k6fmhcj.apps.googleusercontent.com';
const String oneSignalAppId = '06b99c2b-b3b4-413b-b6cc-480a624f4e25';
const String kBackendBaseUrl = 'https://www.mayajaal.online';
const int kAppCurrentVersionCode = 2;

const Color kGreen = Color(0xFF00FF66);
const Color kNeonCyan = Color(0xFF00F0FF);
const Color kNeonPurple = Color(0xFF9D00FF);
const Color kBg = Color(0xFF000000);
const Color kCardBg = Color(0xFF031408);
const Color kDimGreen = Color(0xFF4FBF8B);
const Color kGold = Color(0xFFFFD700);
const Color kSilver = Color(0xFFC0C0C0);
const Color kBronze = Color(0xFFCD7F32);
const Color kRed = Color(0xFFFF3B3B);

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<String> languageNotifier = ValueNotifier('English');
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ═══════════════════════════════════════════════════════
// TRANSLATIONS
// ═══════════════════════════════════════════════════════
final Map<String, Map<String, String>> localizedStrings = {
  'English': {
    'app_title': 'MAYA JAAL',
    'paste_hint': 'Paste Stream URL',
    'watch_history': '> WATCH HISTORY',
    'no_history': 'no history yet',
    'settings': 'SETTINGS',
    'dark_theme': 'Dark Theme',
    'language': 'Language',
    'download_location': 'Download Location',
    'clear_history': 'Clear History',
    'logout': 'Logout',
    'uploader': 'UPLOADER',
    'filename': 'FILE NAME',
  },
  'Hindi': {
    'app_title': 'माया जाल',
    'paste_hint': 'यहाँ लिंक पेस्ट करें...',
    'watch_history': '> देखने का इतिहास',
    'no_history': 'अभी कोई इतिहास नहीं है',
    'settings': 'सेटिंग्स',
    'dark_theme': 'डार्क थीम',
    'language': 'भाषा (Language)',
    'download_location': 'डाउनलोड स्थान',
    'clear_history': 'इतिहास साफ़ करें',
    'logout': 'लॉग आउट',
    'uploader': 'अपलोडर',
    'filename': 'फ़ाइल का नाम',
  },
};

String tr(String key) {
  final lang = languageNotifier.value;
  return localizedStrings[lang]?[key] ?? localizedStrings['English']?[key] ?? key;
}

// ═══════════════════════════════════════════════════════
// HAPTIC HELPER
// ═══════════════════════════════════════════════════════
class Haptic {
  static Future<void> light() async {
    try { await HapticFeedback.lightImpact(); } catch (_) {}
  }
  static Future<void> medium() async {
    try { await HapticFeedback.mediumImpact(); } catch (_) {}
  }
  static Future<void> heavy() async {
    try { await HapticFeedback.heavyImpact(); } catch (_) {}
  }
  static Future<void> selection() async {
    try { await HapticFeedback.selectionClick(); } catch (_) {}
  }
}

// ═══════════════════════════════════════════════════════
// CYBER RANK SYSTEM
// ═══════════════════════════════════════════════════════
class CyberRank {
  static const List<Map<String, dynamic>> ranks = [
    {'name': 'Neon Rookie', 'emoji': '🥉', 'color': kSilver, 'min': 0},
    {'name': 'Cyber Trader', 'emoji': '🥈', 'color': kNeonCyan, 'min': 1000},
    {'name': 'Matrix Master', 'emoji': '🥇', 'color': kGreen, 'min': 10000},
    {'name': 'Quantum Elite', 'emoji': '💎', 'color': kNeonPurple, 'min': 100000},
    {'name': 'MayaJaal Legend', 'emoji': '👑', 'color': kGold, 'min': 1000000},
  ];

  static Map<String, dynamic> get(int views) {
    Map<String, dynamic> current = ranks[0];
    for (final r in ranks) {
      if (views >= (r['min'] as int)) current = r;
    }
    return current;
  }

  static Map<String, dynamic>? next(int views) {
    for (final r in ranks) {
      if (views < (r['min'] as int)) return r;
    }
    return null;
  }

  static int getIndex(int views) {
    int idx = 0;
    for (int i = 0; i < ranks.length; i++) {
      if (views >= (ranks[i]['min'] as int)) idx = i;
    }
    return idx;
  }
}

// ═══════════════════════════════════════════════════════
// AD TRACKER
// ═══════════════════════════════════════════════════════
class AdTracker {
  static const String _kCountKey = 'ads_watched_count';
  static const String _kLastTimeKey = 'ads_last_reset_time';

  static Future<int> getWatchedCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_kCountKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> increment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_kCountKey) ?? 0;
      final newCount = current + 1;
      if (newCount >= 7) {
        await prefs.setInt(_kCountKey, 0);
        await prefs.setInt(_kLastTimeKey, DateTime.now().millisecondsSinceEpoch);
      } else {
        await prefs.setInt(_kCountKey, newCount);
      }
    } catch (_) {}
  }

  static Future<bool> isAdFreeWindow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTime = prefs.getInt(_kLastTimeKey) ?? 0;
      if (lastTime == 0) return false;
      final diff = DateTime.now().millisecondsSinceEpoch - lastTime;
      return diff < 24 * 60 * 60 * 1000;
    } catch (_) {
      return false;
    }
  }

  static Future<int> hoursRemaining() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTime = prefs.getInt(_kLastTimeKey) ?? 0;
      if (lastTime == 0) return 0;
      final diff = DateTime.now().millisecondsSinceEpoch - lastTime;
      final remaining = 24 * 60 * 60 * 1000 - diff;
      return remaining > 0 ? (remaining / (60 * 60 * 1000)).ceil() : 0;
    } catch (_) {
      return 0;
    }
  }
}

// ═══════════════════════════════════════════════════════
// MAYAJAAL FIREBASE ACCOUNT SERVICE
// ═══════════════════════════════════════════════════════
class MayaJaalAccount {
  static String? cachedUid;
  static String? cachedEmail;
  static String? cachedName;
  static String? cachedPhoto;
  static String? cachedApiKey;

  static DatabaseReference get _rtdb => FirebaseDatabase.instance.ref();

  static Future<void> init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      cachedUid = user.uid;
      cachedEmail = user.email;
      cachedName = user.displayName;
      cachedPhoto = user.photoURL;
      await syncUserToRTDB(user);
      await loadApiKey();
    }
  }

  static bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;

  static Future<void> syncUserToRTDB(User user) async {
    try {
      final ref = _rtdb.child('users/${user.uid}');
      final snap = await ref.once();
      final data = snap.snapshot.value as Map?;

      final updates = <String, dynamic>{
        'email': (user.email ?? '').toLowerCase(),
        'name': user.displayName ?? 'User',
        'photoURL': user.photoURL ?? '',
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      };

      if (data == null) {
        updates['createdAt'] = DateTime.now().millisecondsSinceEpoch;
        updates['subscribersCount'] = 0;
        updates['dashboard'] = {
          'totalLinks': 0,
          'totalViews': 0,
          'todayViews': 0,
          'todayConversions': 0,
          'totalIncome': 0,
          'todayIncome': 0,
          'viewsByDay': {},
          'linksByDay': {},
        };
        updates['withdrawal'] = {
          'upi': '',
          'bank_account': '',
          'ifsc': '',
          'gmail': '',
          'enabled': false,
        };
      }

      await ref.update(updates);
      debugPrint('✅ User synced to RTDB: ${user.uid}');
    } catch (e) {
      debugPrint('RTDB sync error: $e');
    }
  }

  static Future<String> loadApiKey() async {
    if (cachedUid == null) return '';
    try {
      final ref = _rtdb.child('users/$cachedUid/apiKey');
      final snap = await ref.once();
      var key = snap.snapshot.value as String?;

      if (key == null || key.length < 12) {
        key = _generateKey();
        await ref.set(key);
      }
      cachedApiKey = key;
      return key;
    } catch (e) {
      debugPrint('API key error: $e');
      return '';
    }
  }

  static String _generateKey() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = math.Random.secure();
    return List.generate(24, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static Future<UserCredential?> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(serverClientId: webClientId);
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );
    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  static Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    cachedUid = null;
    cachedEmail = null;
    cachedName = null;
    cachedPhoto = null;
    cachedApiKey = null;
  }

  static Future<Map<String, dynamic>> getDashboard() async {
    if (cachedUid == null) return {};
    try {
      final snap = await _rtdb.child('users/$cachedUid/dashboard').once();
      return Map<String, dynamic>.from((snap.snapshot.value ?? {}) as Map);
    } catch (e) {
      return {};
    }
  }

  static Stream<Map<String, dynamic>> getDashboardStream() {
    if (cachedUid == null) return const Stream.empty();
    return _rtdb.child('users/$cachedUid/dashboard').onValue.map((event) {
      final val = event.snapshot.value;
      if (val == null || val is! Map) return <String, dynamic>{};
      return Map<String, dynamic>.from(val);
    });
  }

  static Future<Map<String, dynamic>> getWithdrawalInfo() async {
    if (cachedUid == null) return {};
    try {
      final snap = await _rtdb.child('users/$cachedUid/withdrawal').once();
      final val = snap.snapshot.value;
      if (val == null || val is! Map) return {};
      return Map<String, dynamic>.from(val);
    } catch (e) {
      return {};
    }
  }

  static Future<void> saveWithdrawalInfo(Map<String, dynamic> data) async {
    if (cachedUid == null) return;
    try {
      await _rtdb.child('users/$cachedUid/withdrawal').update(data);
    } catch (e) {
      debugPrint('Save withdrawal info error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getUserLinks({int limit = 20}) async {
    if (cachedUid == null) return [];
    try {
      final snap = await _rtdb.child('links').orderByChild('ownerUid').equalTo(cachedUid!).once();
      final val = snap.snapshot.value;
      if (val == null) return [];
      final map = Map<String, dynamic>.from(val as Map);
      final arr = map.entries.map((e) {
        final d = Map<String, dynamic>.from(e.value as Map);
        d['id'] = e.key;
        return d;
      }).toList();
      arr.sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));
      return arr.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  // ✅ UPDATED EARNING RATES
  static double calcEarnings(int views) {
    views = math.max(0, views);
    if (views <= 0) return 0;
    if (views <= 1000) return _r2(views * 0.0015);
    if (views <= 2000) return _r2(1.50 + (views - 1000) * 0.0025);
    
    // 2000 se upar $2.00 per 1k views (i.e., 0.002 per view)
    return _r2(4.00 + (views - 2000) * 0.002);
  }

  static Map<String, dynamic> getTierInfo(int views) {
    views = math.max(0, views);
    if (views < 1000) {
      return {'tier': 1, 'rate': 1.50, 'next': 1000 - views};
    }
    if (views < 2000) {
      return {'tier': 2, 'rate': 2.50, 'next': 2000 - views};
    }
    return {
      'tier': 3 + (views ~/ 2000),
      'rate': 2.00,
      'next': 2000 - (views % 2000),
    };
  }

  static double _r2(num n) => (n * 100).round() / 100;
}

// ═══════════════════════════════════════════════════════
// FIREBASE SERVICE
// ═══════════════════════════════════════════════════════
class FirebaseService {
  static DatabaseReference get _rtdb => FirebaseDatabase.instance.ref();

  static Future<void> sendNotification({
    required String toUid,
    required String title,
    required String message,
    String type = 'general',
  }) async {
    try {
      final id = _rtdb.child('users/$toUid/notifications').push().key;
      if (id == null) return;
      await _rtdb.child('users/$toUid/notifications/$id').set({
        'title': title,
        'message': message,
        'type': type,
        'time': DateTime.now().millisecondsSinceEpoch,
        'read': false,
      });
    } catch (e) {
      debugPrint('sendNotification error: $e');
    }
  }

  static Stream<List<Map<String, dynamic>>> getNotifications(String uid) {
    return _rtdb.child('users/$uid/notifications').onValue.map((event) {
      final val = event.snapshot.value;
      if (val == null) return <Map<String, dynamic>>[];
      final map = Map<String, dynamic>.from(val as Map);
      final list = map.entries.map((e) {
        final d = Map<String, dynamic>.from(e.value as Map);
        d['id'] = e.key;
        return d;
      }).toList();
      list.sort((a, b) => (b['time'] ?? 0).compareTo(a['time'] ?? 0));
      return list;
    });
  }

  static Future<void> markNotificationRead(String uid, String notifId) async {
    try {
      await _rtdb.child('users/$uid/notifications/$notifId/read').set(true);
    } catch (_) {}
  }

  static Future<void> markAllRead(String uid) async {
    try {
      final snap = await _rtdb.child('users/$uid/notifications').once();
      final val = snap.snapshot.value as Map?;
      if (val == null) return;
      final updates = <String, dynamic>{};
      for (final id in val.keys) {
        updates['$id/read'] = true;
      }
      if (updates.isNotEmpty) {
        await _rtdb.child('users/$uid/notifications').update(updates);
      }
    } catch (_) {}
  }

  static Stream<int> getUnreadCount(String uid) {
    return _rtdb.child('users/$uid/notifications').onValue.map((event) {
      final val = event.snapshot.value;
      if (val == null) return 0;
      final map = Map<String, dynamic>.from(val as Map);
      int count = 0;
      for (final v in map.values) {
        if (v is Map && v['read'] != true) count++;
      }
      return count;
    });
  }

  static Future<Map<String, dynamic>?> getProfile(String uid) async {
    try {
      final snap = await _rtdb.child('users/$uid').once();
      final val = snap.snapshot.value;
      if (val == null) return null;
      return Map<String, dynamic>.from(val as Map);
    } catch (e) {
      return null;
    }
  }

  static Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _rtdb.child('users/$uid').update(data);
    } catch (e) {
      debugPrint('updateProfile error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();

    try {
      final snap = await _rtdb.child('users').once();
      final val = snap.snapshot.value;
      if (val == null) return [];

      final users = Map<String, dynamic>.from(val as Map);
      final results = <Map<String, dynamic>>[];

      users.forEach((uid, data) {
        if (data is! Map) return;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final email = (data['email'] ?? '').toString().toLowerCase();
        if (name.contains(q) || email.contains(q)) {
          final d = Map<String, dynamic>.from(data);
          d['uid'] = uid;
          results.add(d);
        }
      });

      return results.take(30).toList();
    } catch (e) {
      debugPrint('searchUsers error: $e');
      return [];
    }
  }

  static Future<bool> isSubscribed(String subscriberUid, String channelUid) async {
    try {
      final snap = await _rtdb.child('subscriptions/$channelUid/$subscriberUid').once();
      return snap.snapshot.value != null;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> toggleSubscription(String subscriberUid, String channelUid) async {
    try {
      final ref = _rtdb.child('subscriptions/$channelUid/$subscriberUid');
      final snap = await ref.once();
      final isSubbed = snap.snapshot.value != null;

      if (isSubbed) {
        await ref.remove();
        await _rtdb.child('userSubs/$subscriberUid/$channelUid').remove();

        await _rtdb.child('users/$channelUid').runTransaction((data) {
          if (data == null) return Transaction.success(null);
          final map = Map<String, dynamic>.from(data as Map);
          final subs = (map['subscribersCount'] ?? 0) as int;
          map['subscribersCount'] = math.max(0, subs - 1);
          return Transaction.success(map);
        });

        return false;
      } else {
        await ref.set(DateTime.now().millisecondsSinceEpoch);
        await _rtdb.child('userSubs/$subscriberUid/$channelUid').set(DateTime.now().millisecondsSinceEpoch);

        await _rtdb.child('users/$channelUid').runTransaction((data) {
          if (data == null) return Transaction.success(null);
          final map = Map<String, dynamic>.from(data as Map);
          final subs = (map['subscribersCount'] ?? 0) as int;
          map['subscribersCount'] = subs + 1;
          return Transaction.success(map);
        });

        await sendNotification(
          toUid: channelUid,
          title: '🔔 New Subscriber!',
          message: 'Someone subscribed to your channel.',
          type: 'subscribe',
        );

        return true;
      }
    } catch (e) {
      debugPrint('toggleSubscription error: $e');
      return false;
    }
  }

  static Stream<int> getSubscriberCount(String channelUid) {
    return _rtdb.child('users/$channelUid/subscribersCount').onValue.map((e) {
      return (e.snapshot.value ?? 0) as int;
    });
  }

  static Future<List<String>> getUserSubscriptions(String subscriberUid) async {
    try {
      final snap = await _rtdb.child('userSubs/$subscriberUid').once();
      final val = snap.snapshot.value;
      if (val == null) return [];
      return (val as Map).keys.map((k) => k.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getUserVideos(String uid, {int limit = 30}) async {
    try {
      final snap = await _rtdb.child('links').orderByChild('ownerUid').equalTo(uid).once();
      final val = snap.snapshot.value;
      if (val == null) return [];
      final map = Map<String, dynamic>.from(val as Map);
      final list = map.entries.map((e) {
        final d = Map<String, dynamic>.from(e.value as Map);
        d['id'] = e.key;
        return d;
      }).toList();
      list.sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));
      return list.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getRelatedVideos({
    required String currentVideoId,
    String? currentOwnerUid,
    List<String> recentIds = const [],
    int limit = 10,
  }) async {
    try {
      final snap = await _rtdb.child('links').once();
      final val = snap.snapshot.value;
      if (val == null) return [];
      final map = Map<String, dynamic>.from(val as Map);
      final all = map.entries.map((e) {
        final d = Map<String, dynamic>.from(e.value as Map);
        d['id'] = e.key;
        return d;
      }).where((v) => v['id'] != currentVideoId).toList();

      final result = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      for (final id in recentIds) {
        if (result.length >= limit) break;
        try {
          final found = all.firstWhere((v) => v['id'] == id);
          if (!seenIds.contains(found['id'])) {
            result.add(found);
            seenIds.add(found['id'] as String);
          }
        } catch (_) {}
      }

      if (currentOwnerUid != null && currentOwnerUid.isNotEmpty) {
        for (final v in all) {
          if (result.length >= limit) break;
          if (v['ownerUid'] == currentOwnerUid && !seenIds.contains(v['id'])) {
            result.add(v);
            seenIds.add(v['id'] as String);
          }
        }
      }

      final sorted = List<Map<String, dynamic>>.from(all)
        ..sort((a, b) => ((b['views'] ?? 0) as int).compareTo((a['views'] ?? 0) as int));
      for (final v in sorted) {
        if (result.length >= limit) break;
        if (!seenIds.contains(v['id'])) {
          result.add(v);
          seenIds.add(v['id'] as String);
        }
      }

      return result.take(limit).toList();
    } catch (e) {
      debugPrint('getRelatedVideos error: $e');
      return [];
    }
  }

  static Stream<Map<String, int>> getVideoStatsStream(String videoId) {
    return _rtdb.child('links/$videoId').onValue.map((event) {
      final val = event.snapshot.value;
      if (val == null || val is! Map) {
        return {'views': 0, 'likes': 0, 'unlikes': 0, 'shares': 0};
      }

      int countMap(dynamic d) {
        if (d == null || d is! Map) return 0;
        return d.length;
      }

      return {
        'views': (val['views'] ?? 0) as int,
        'likes': countMap(val['likes']),
        'unlikes': countMap(val['unlikes']),
        'shares': countMap(val['shares']),
      };
    });
  }

  static Stream<bool> isLikedStream(String videoId, String uid) {
    return _rtdb.child('links/$videoId/likes/$uid').onValue.map((e) {
      return e.snapshot.value != null;
    });
  }

  static Stream<bool> isUnlikedStream(String videoId, String uid) {
    return _rtdb.child('links/$videoId/unlikes/$uid').onValue.map((e) {
      return e.snapshot.value != null;
    });
  }

  static Future<bool> toggleLike(String videoId, String uid, String ownerUid, String videoTitle) async {
    try {
      final likeRef = _rtdb.child('links/$videoId/likes/$uid');
      final unlikeRef = _rtdb.child('links/$videoId/unlikes/$uid');

      final likeSnap = await likeRef.once();
      final isLiked = likeSnap.snapshot.value != null;

      if (isLiked) {
        await likeRef.remove();
        return false;
      } else {
        await likeRef.set(DateTime.now().millisecondsSinceEpoch);
        await unlikeRef.remove();

        if (ownerUid.isNotEmpty && ownerUid != uid) {
          await sendNotification(
            toUid: ownerUid,
            title: '❤️ New Like!',
            message: 'Someone liked your video: $videoTitle',
            type: 'like',
          );
        }
        return true;
      }
    } catch (e) {
      debugPrint('toggleLike error: $e');
      return false;
    }
  }

  static Future<bool> toggleDislike(String videoId, String uid) async {
    try {
      final unlikeRef = _rtdb.child('links/$videoId/unlikes/$uid');
      final likeRef = _rtdb.child('links/$videoId/likes/$uid');

      final snap = await unlikeRef.once();
      final isUnliked = snap.snapshot.value != null;

      if (isUnliked) {
        await unlikeRef.remove();
        return false;
      } else {
        await unlikeRef.set(DateTime.now().millisecondsSinceEpoch);
        await likeRef.remove();
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<void> recordShare(String videoId) async {
    try {
      final id = _rtdb.child('links/$videoId/shares').push().key;
      if (id != null) {
        await _rtdb.child('links/$videoId/shares/$id').set(DateTime.now().millisecondsSinceEpoch);
      }
    } catch (_) {}
  }
}

// ═══════════════════════════════════════════════════════
// DEVICE ID HELPER
// ═══════════════════════════════════════════════════════
class DeviceIdHelper {
  static String? _cached;
  static Future<String> get() async {
    if (_cached != null) return _cached!;
    try {
      final prefs = await SharedPreferences.getInstance();
      String? stored = prefs.getString('mj_device_id');
      if (stored != null && stored.isNotEmpty) {
        _cached = stored;
        return stored;
      }
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        stored = 'and-${a.id}-${a.model}'.replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '');
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        stored = 'ios-${i.identifierForVendor ?? 'unknown'}';
      } else {
        stored = 'dev-${DateTime.now().millisecondsSinceEpoch}';
      }
      await prefs.setString('mj_device_id', stored!);
      _cached = stored;
      return stored!;
    } catch (_) {
      _cached = 'dev-${DateTime.now().millisecondsSinceEpoch}';
      return _cached!;
    }
  }
}

// ═══════════════════════════════════════════════════════
// WATCH HISTORY HELPER
// ═══════════════════════════════════════════════════════
class WatchHistory {
  static Future<List<String>> getRecentIds({int limit = 10}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('watch_history_v2');
      if (raw == null) return [];
      final List decoded = jsonDecode(raw);
      return decoded
          .take(limit)
          .map((e) => (e['id'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}

// ═══════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDI5hgBbaUeTpXcPIlAnq5yDjIenfY-ylM",
        authDomain: "mayajaal-app.firebaseapp.com",
        databaseURL: "https://mayajaal-app-default-rtdb.asia-southeast1.firebasedatabase.app",
        projectId: "mayajaal-app",
        storageBucket: "mayajaal-app.firebasestorage.app",
        messagingSenderId: "96139047750",
        appId: "1:96139047750:android:7dbfb9487d023c20012b47",
      ),
    );
    debugPrint("✅ Firebase Initialized");
    await MayaJaalAccount.init();
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }

  try {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(oneSignalAppId);
    OneSignal.Notifications.requestPermission(true);
  } catch (e) {
    debugPrint("OneSignal Init Error: $e");
  }

  runApp(const MyApp());
}

// ═══════════════════════════════════════════════════════
// MATRIX RAIN
// ═══════════════════════════════════════════════════════
class MatrixRain extends StatefulWidget {
  final double opacity;
  const MatrixRain({super.key, this.opacity = 0.7});
  @override
  State<MatrixRain> createState() => _MatrixRainState();
}

class _MatrixRainState extends State<MatrixRain> {
  late Timer _timer;
  final List<double> _yPositions = [];
  final List<double> _speeds = [];
  final List<String> _letters = [];
  final math.Random _r = math.Random();
  static const _chars = 'アイウエオカキクケコサシスセソタチツテトナニヌネノ0123456789ABCDEFXYZ@#%&*';

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 32; i++) {
      _yPositions.add(-_r.nextInt(600).toDouble());
      _speeds.add(4 + _r.nextDouble() * 6);
      _letters.add(_chars[_r.nextInt(_chars.length)]);
    }
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _yPositions.length; i++) {
          _yPositions[i] += _speeds[i];
          if (_yPositions[i] > 950) {
            _yPositions[i] = -_r.nextInt(200).toDouble();
            _letters[i] = _chars[_r.nextInt(_chars.length)];
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(builder: (context, c) {
        final colWidth = c.maxWidth / _yPositions.length;
        return Stack(
          children: List.generate(_yPositions.length, (i) {
            return Positioned(
              left: i * colWidth,
              top: _yPositions[i],
              child: Text(
                _letters[i],
                style: TextStyle(
                  color: kGreen.withOpacity(widget.opacity),
                  fontSize: 13,
                  fontFamily: 'monospace',
                  shadows: const [Shadow(color: kGreen, blurRadius: 6)],
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════
// PROFESSIONAL LOADING SCREEN
// ═══════════════════════════════════════════════════════
class ProfessionalLoader extends StatefulWidget {
  final String message;
  const ProfessionalLoader({super.key, this.message = 'LOADING...'});

  @override
  State<ProfessionalLoader> createState() => _ProfessionalLoaderState();
}

class _ProfessionalLoaderState extends State<ProfessionalLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _pulse;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _pulse = Tween<double>(begin: 0.85, end: 1.1)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
    _rotate = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _c, curve: Curves.linear));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const MatrixRain(opacity: 0.35),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _rotate,
                      builder: (c, _) => Transform.rotate(
                        angle: _rotate.value * 2 * math.pi,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                kGreen.withOpacity(0.0),
                                kGreen,
                                kNeonCyan,
                                kGreen.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (c, _) => Transform.scale(
                        scale: _pulse.value,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                            border: Border.all(color: kGreen, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: kGreen.withOpacity(0.6),
                                blurRadius: 25,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/icon/logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => const Icon(
                                Icons.change_history,
                                color: kGreen,
                                size: 50,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  widget.message,
                  style: const TextStyle(
                    color: kGreen,
                    fontSize: 14,
                    fontFamily: 'monospace',
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: kGreen, blurRadius: 10)],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(kGreen),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// SPLASH SCREEN
// ═══════════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _a = Tween<double>(begin: 0.9, end: 1.1)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const MatrixRain(opacity: 0.65),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _a,
                  builder: (c, _) => Transform.scale(
                    scale: _a.value,
                    child: Container(
                      width: 125,
                      height: 125,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: kGreen.withOpacity(0.6),
                            blurRadius: 28,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/icon/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            color: Colors.black,
                            child: const Icon(
                              Icons.movie_filter,
                              size: 70,
                              color: kGreen,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'MAYAJAAL LOADING...',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: kGreen,
                    fontFamily: 'monospace',
                    letterSpacing: 4,
                    shadows: [
                      Shadow(color: kGreen.withOpacity(0.85), blurRadius: 16)
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '> initializing quantum cipher...',
                  style: TextStyle(
                    fontSize: 11,
                    color: kGreen.withOpacity(0.7),
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// MY APP
// ═══════════════════════════════════════════════════════
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;
  Uri? _initialLink;
  bool _linkReady = false;
  String? _pendingVideoTargetUrl;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _initialLink = initial;
        debugPrint('Initial deep link: $initial');
      }
    } catch (e) {
      debugPrint('Initial link error: $e');
    }
    if (mounted) setState(() => _linkReady = true);

    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('Deep link received: $uri');
      if (!mounted) return;
      _handleDeepLink(uri);
    }, onError: (e) => debugPrint('Link stream error: $e'));
  }

  void _handleDeepLink(Uri uri) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    if (uri.path.startsWith('/v/') ||
        uri.path.startsWith('/s/') ||
        uri.host == 'watch' ||
        uri.scheme == 'mayajaall') {
      String videoId = '';
      final token =
          uri.queryParameters['t'] ?? uri.queryParameters['s'] ?? '';

      if (uri.path.startsWith('/v/') || uri.path.startsWith('/s/')) {
        videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      } else if (uri.queryParameters['v'] != null) {
        videoId = uri.queryParameters['v']!;
      }
      if (videoId.isEmpty) return;

      final targetUrl = token.isNotEmpty
          ? 'https://www.mayajaal.online/v/$videoId?t=$token'
          : 'https://www.mayajaal.online/v/$videoId';

      if (!MayaJaalAccount.isLoggedIn) {
        _pendingVideoTargetUrl = targetUrl;
        navigator.push(MaterialPageRoute(
          builder: (_) => LoginScreen(
            onLoginSuccess: () {
              final target = _pendingVideoTargetUrl;
              _pendingVideoTargetUrl = null;
              if (target == null) return;
              navigatorKey.currentState?.push(MaterialPageRoute(
                builder: (_) => StreamPreviewScreen(targetUrl: target),
              ));
            },
          ),
        ));
        return;
      }

      navigator.push(MaterialPageRoute(
        builder: (_) => StreamPreviewScreen(targetUrl: targetUrl),
      ));
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_linkReady) {
      return const MaterialApp(
        home: SplashScreen(),
        debugShowCheckedModeBanner: false,
      );
    }

    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, mode, _) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              title: 'MayaJaal',
              debugShowCheckedModeBanner: false,
              themeMode: ThemeMode.dark,
              theme: _buildPureDarkTheme(),
              darkTheme: _buildPureDarkTheme(),
              home: const AuthGate(),
            );
          },
        );
      },
    );
  }

  ThemeData _buildPureDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      dialogBackgroundColor: const Color(0xFF021206),
      colorScheme: const ColorScheme.dark(
        primary: kGreen,
        surface: Color(0xFF021206),
      ),
      useMaterial3: true,
      fontFamily: 'monospace',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: kGreen,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// AUTH GATE
// ═══════════════════════════════════════════════════════
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            MayaJaalAccount.cachedUid = user.uid;
            MayaJaalAccount.cachedEmail = user.email;
            MayaJaalAccount.cachedName = user.displayName;
            MayaJaalAccount.cachedPhoto = user.photoURL;
            await MayaJaalAccount.syncUserToRTDB(user);
            await MayaJaalAccount.loadApiKey();
          });
          // ✅ Permission screen removed, directly to Home
          return const MainNavigationHolder();
        }
        return const LoginScreen();
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
// LOGIN SCREEN (Same to Same as Image)
// ═══════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  const LoginScreen({super.key, this.onLoginSuccess});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  String _error = '';

  late AnimationController _magicController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _magicController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 40.0).animate(
      CurvedAnimation(parent: _magicController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _magicController.dispose();
    super.dispose();
  }

  Future<void> _triggerMagic() async {
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.heavyImpact();
    } catch (_) {}
    await _magicController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
  }

  Future<void> _handleGoogle() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final result = await MayaJaalAccount.signInWithGoogle();
      if (result == null) {
        setState(() => _loading = false);
        return;
      }
      await _triggerMagic();
      if (!mounted) return;
      widget.onLoginSuccess?.call();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = '❌ ${_fbError(e.code)}');
    } catch (e) {
      setState(() => _error = '❌ Google Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fbError(String code) {
    switch (code) {
      case 'invalid-credential':
        return 'Email ya password galat hai';
      case 'too-many-requests':
        return 'Bohot zyada attempts, thodi der baad try karein';
      case 'network-request-failed':
        return 'Internet connection check karein';
      default:
        return code.replaceAll('-', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Matrix Background
          const MatrixRain(opacity: 0.2),
          
          // 2. Laptop Mockup Effect
          Positioned(
            bottom: 80,
            right: -40,
            child: Opacity(
              opacity: 0.6,
              child: Transform.rotate(
                angle: -0.05,
                child: Container(
                  width: 340,
                  height: 220,
                  decoration: BoxDecoration(
                    color: const Color(0xFF021206),
                    border: Border.all(color: kGreen.withOpacity(0.5), width: 2),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: kGreen.withOpacity(0.2), blurRadius: 40, spreadRadius: 10)
                    ]
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 22,
                        color: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 4, backgroundColor: Colors.redAccent.withOpacity(0.8)),
                            const SizedBox(width: 6),
                            CircleAvatar(radius: 4, backgroundColor: Colors.amber.withOpacity(0.8)),
                            const SizedBox(width: 6),
                            CircleAvatar(radius: 4, backgroundColor: kGreen.withOpacity(0.8)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Center(
                              child: Icon(Icons.play_circle_outline, color: kGreen.withOpacity(0.3), size: 80),
                            ),
                            Positioned(
                              bottom: 10,
                              left: 10,
                              right: 10,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(color: kGreen.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: 0.6,
                                  child: Container(
                                    decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(2)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo & Brand
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kGreen, width: 2.5),
                          boxShadow: [
                            BoxShadow(color: kGreen.withOpacity(0.6), blurRadius: 20, spreadRadius: 2),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.asset(
                            'assets/icon/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(
                              Icons.change_history,
                              color: kGreen,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Maya',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontFamily: 'sans-serif',
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Text(
                        'Jaal',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: kGreen,
                          fontFamily: 'sans-serif',
                          letterSpacing: 0.5,
                          shadows: [Shadow(color: kGreen, blurRadius: 15)],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Headline Text
                  const Text(
                    'Your Videos.\nYour Links.',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                      fontFamily: 'sans-serif',
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Text(
                    'Your Earnings.',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: kGreen,
                      height: 1.1,
                      fontFamily: 'sans-serif',
                      letterSpacing: -0.5,
                      shadows: [Shadow(color: kGreen, blurRadius: 10)],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Tagline
                  Text(
                    "World's Smartest Video Sharing\nPlatform",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.8),
                      fontFamily: 'monospace',
                      letterSpacing: 1.2,
                      height: 1.4,
                    ),
                  ),

                  const Spacer(),

                  // White Google Button
                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 10,
                        shadowColor: kGreen.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(31),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 3,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.network(
                                  'https://developers.google.com/identity/images/g-logo.png',
                                  height: 28,
                                  errorBuilder: (c, e, s) => const Icon(
                                    Icons.g_mobiledata,
                                    color: Colors.red,
                                    size: 34,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Sign in with Google',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'sans-serif',
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.arrow_forward, color: Colors.black, size: 24),
                                const SizedBox(width: 16),
                              ],
                            ),
                    ),
                  ),

                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        border: Border.all(color: Colors.redAccent),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _error,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// MAIN NAVIGATION HOLDER
// ═══════════════════════════════════════════════════════
class MainNavigationHolder extends StatefulWidget {
  const MainNavigationHolder({super.key});
  @override
  State<MainNavigationHolder> createState() => _MainNavigationHolderState();
}

class _MainNavigationHolderState extends State<MainNavigationHolder> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onMenuTap: () => _scaffoldKey.currentState?.openDrawer()),
      const ChannelScreen(),
      const GalleryScreen(),
      const HistoryScreen(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.black,
      drawer: const MoreDrawer(),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF000803),
          border: Border(
            top: BorderSide(color: kGreen.withOpacity(0.35), width: 1.2),
          ),
          boxShadow: [
            BoxShadow(
              color: kGreen.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: StreamBuilder<int>(
          stream: MayaJaalAccount.cachedUid != null
              ? FirebaseService.getUnreadCount(MayaJaalAccount.cachedUid!)
              : Stream.value(0),
          builder: (context, snapshot) {
            final unread = snapshot.data ?? 0;
            return BottomNavigationBar(
              currentIndex: _currentIndex,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: kGreen,
              unselectedItemColor: Colors.white54,
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 10,
              unselectedFontSize: 10,
              onTap: (index) {
                Haptic.selection();
                setState(() => _currentIndex = index);
              },
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home, color: kGreen),
                  label: 'Home',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.ondemand_video_outlined),
                  activeIcon: Icon(Icons.ondemand_video, color: kGreen),
                  label: 'Channel',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.photo_library_outlined),
                  activeIcon: Icon(Icons.photo_library, color: kGreen),
                  label: 'Gallery',
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.history_outlined),
                      if (unread > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            constraints: const BoxConstraints(minWidth: 14),
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  activeIcon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.history, color: kGreen),
                      if (unread > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            constraints: const BoxConstraints(minWidth: 14),
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: 'History',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// AD BANNER WIDGET
// ═══════════════════════════════════════════════════════
class AdBanner extends StatelessWidget {
  final String slot;
  final VoidCallback? onTap;
  const AdBanner({super.key, required this.slot, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        Haptic.medium();
        await AdTracker.increment();
        if (onTap != null) onTap!();
        if (!context.mounted) return;
        final count = await AdTracker.getWatchedCount();
        final remaining = 7 - count;
        if (remaining <= 0) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: kCardBg,
                content: Text(
                  '🎉 Ad-free unlocked for 24 hours!',
                  style: TextStyle(color: kGreen),
                ),
              ),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: kCardBg,
                content: Text(
                  '✅ Ad watched! $remaining more for 24h ad-free',
                  style: const TextStyle(color: kGreen, fontSize: 12),
                ),
              ),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF031408),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kGreen.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: kGreen,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'AD',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR AD HERE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Ad Slot: $slot · Tap to watch',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.campaign_outlined, color: kGreen, size: 26),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// FIRST TIME ADS POPUP
// ═══════════════════════════════════════════════════════
class FirstTimeAdsPopup {
  static Future<void> show(BuildContext context) async {
    final count = await AdTracker.getWatchedCount();
    final remaining = 7 - count;
    if (remaining <= 0) return;

    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF021206),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kGreen, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: kGreen.withOpacity(0.3),
                    blurRadius: 25,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                      border: Border.all(color: kGold, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: kGold.withOpacity(0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.workspace_premium,
                        color: kGold,
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'AD-FREE STREAMING',
                    style: TextStyle(
                      color: kGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      shadows: [Shadow(color: kGreen, blurRadius: 10)],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Watch $remaining ads to unlock 24 hours of ad-free streaming!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(7, (i) {
                      final watched = i < count;
                      return Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: watched ? kGreen : Colors.black,
                          border: Border.all(
                            color: watched ? kGreen : kGreen.withOpacity(0.4),
                            width: 1.5,
                          ),
                          boxShadow: watched
                              ? [BoxShadow(color: kGreen.withOpacity(0.5), blurRadius: 8)]
                              : null,
                        ),
                        child: watched
                            ? const Icon(Icons.check, color: Colors.black, size: 12)
                            : null,
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$count / 7 ads watched',
                    style: TextStyle(
                      color: kGreen.withOpacity(0.8),
                      fontSize: 10.5,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        Haptic.medium();
                        await AdTracker.increment();
                        if (c.mounted) Navigator.pop(c);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
                      ),
                      child: const Text(
                        '▶ WATCH AD NOW',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: GestureDetector(
                onTap: () {
                  Haptic.light();
                  Navigator.pop(context);
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white54,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// HOME SCREEN
// ═══════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;
  const HomeScreen({super.key, this.onMenuTap});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _linkController = TextEditingController();
  final FocusNode _linkFocus = FocusNode();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _linkController.dispose();
    _linkFocus.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    Haptic.medium();
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: kCardBg,
            content: Text(
              '❌ Clipboard khaali hai',
              style: TextStyle(color: Colors.orangeAccent),
            ),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      _linkController.text = text;
      _linkController.selection = TextSelection.fromPosition(
        TextPosition(offset: text.length),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: kCardBg,
          content: Text(
            '✅ Link pasted',
            style: TextStyle(color: kGreen),
          ),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('Paste error: $e');
    }
  }

  void _showNotificationsSheet(BuildContext context) {
    final uid = MayaJaalAccount.cachedUid;
    if (uid == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111714),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active, color: kGreen),
                      const SizedBox(width: 8),
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          color: kGreen,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => FirebaseService.markAllRead(uid),
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(color: kGreen, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: FirebaseService.getNotifications(uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: kGreen),
                        );
                      }
                      final list = snapshot.data ?? [];
                      if (list.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 60,
                                color: kGreen.withOpacity(0.4),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Koi notification nahi hai',
                                style: TextStyle(
                                  color: kGreen.withOpacity(0.6),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: list.length,
                        itemBuilder: (c, i) {
                          final n = list[i];
                          final isRead = n['read'] == true;
                          final time = n['time'] as int? ?? 0;
                          final dt = DateTime.fromMillisecondsSinceEpoch(time);
                          final ago = _timeAgo(dt);

                          return GestureDetector(
                            onTap: () {
                              if (!isRead) {
                                FirebaseService.markNotificationRead(
                                  uid,
                                  n['id'] as String,
                                );
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isRead
                                    ? Colors.black.withOpacity(0.3)
                                    : const Color(0xFF03220E),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isRead
                                      ? kGreen.withOpacity(0.2)
                                      : kGreen.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: kGreen.withOpacity(0.5),
                                      ),
                                    ),
                                    child: Icon(
                                      _notifIcon(
                                        n['type']?.toString() ?? 'general',
                                      ),
                                      color: kGreen,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          n['title'] ?? '',
                                          style: TextStyle(
                                            color: kGreen,
                                            fontSize: 13.5,
                                            fontWeight: isRead
                                                ? FontWeight.w500
                                                : FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          n['message'] ?? '',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          ago,
                                          style: TextStyle(
                                            color: kGreen.withOpacity(0.5),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _notifIcon(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'subscribe':
        return Icons.person_add;
      case 'share':
        return Icons.share;
      case 'upload':
        return Icons.upload;
      default:
        return Icons.notifications;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _searchAndPlay() {
    final input = _linkController.text.trim();
    if (input.isEmpty) {
      Haptic.heavy();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste a stream URL first!'),
          backgroundColor: kCardBg,
        ),
      );
      return;
    }
    Haptic.medium();
    _linkController.clear();
    _linkFocus.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StreamPreviewScreen(targetUrl: input),
      ),
    );
  }

  Widget _catCard(IconData icon, String title, String subtitle) {
    return GestureDetector(
      onTap: () => Haptic.light(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kGreen.withOpacity(0.4), width: 1.2),
          boxShadow: [
            BoxShadow(color: kGreen.withOpacity(0.08), blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kGreen, size: 26),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, color: kGreen, size: 26),
                      onPressed: () {
                        Haptic.light();
                        widget.onMenuTap?.call();
                      },
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: kGreen, width: 1.5),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.asset(
                                'assets/icon/logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => const Icon(
                                  Icons.change_history,
                                  color: kGreen,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'MayaJaal',
                            style: TextStyle(
                              color: kGreen,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              shadows: [Shadow(color: kGreen, blurRadius: 12)],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: kGreen, size: 24),
                      onPressed: () {
                        Haptic.light();
                        showSearch(context: context, delegate: UserSearchDelegate());
                      },
                    ),
                    StreamBuilder<int>(
                      stream: MayaJaalAccount.cachedUid != null
                          ? FirebaseService.getUnreadCount(MayaJaalAccount.cachedUid!)
                          : Stream.value(0),
                      builder: (context, snapshot) {
                        final unread = snapshot.data ?? 0;
                        return Stack(children: [
                          IconButton(
                            icon: const Icon(
                              Icons.notifications_none,
                              color: kGreen,
                              size: 24,
                            ),
                            onPressed: () {
                              Haptic.light();
                              _showNotificationsSheet(context);
                            },
                          ),
                          if (unread > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1.5,
                                  ),
                                ),
                                constraints: const BoxConstraints(minWidth: 18),
                                child: Text(
                                  unread > 99 ? '99+' : '$unread',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ]);
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: AdBanner(slot: 'home-top'),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 18,
                      child: Text(
                        'MOVIES\nWEB SERIES\nLIVE TV\n& MORE',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 18,
                      child: Text(
                        'Your\nStreaming\nUniverse',
                        style: TextStyle(
                          color: const Color(0xFF66FF99).withOpacity(0.85),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          height: 1.2,
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (c, _) => Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: kGreen.withOpacity(0.25),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: kGreen.withOpacity(0.6),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              Container(
                                width: 95,
                                height: 95,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: kGreen, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kGreen.withOpacity(0.5),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.asset(
                                    'assets/icon/logo.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => Container(
                                      color: Colors.black,
                                      child: const Icon(
                                        Icons.movie_filter,
                                        size: 50,
                                        color: kGreen,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF011206),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: kGreen.withOpacity(0.6), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: kGreen.withOpacity(0.2), blurRadius: 25),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 14, top: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF03220E),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kGreen.withOpacity(0.7)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link, color: kGreen, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'MATRIX NEURAL STREAM NODE',
                                style: TextStyle(
                                  color: kGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF031A0B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kGreen.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.link_rounded,
                                color: kGreen,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: _linkController,
                                      focusNode: _linkFocus,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        hintText: 'Paste Stream URL',
                                        hintStyle: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tap paste or enter link',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 9.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: _pasteFromClipboard,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: kGreen.withOpacity(0.6),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.content_paste_rounded,
                                    color: kGreen,
                                    size: 20,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _searchAndPlay,
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: kGreen,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: kGreen.withOpacity(0.6),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.black,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _catCard(
                        Icons.movie_creation_outlined,
                        'Movies',
                        'Latest',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _catCard(
                        Icons.live_tv_rounded,
                        'Web Series',
                        'Binge',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _catCard(Icons.tv_rounded, 'Live TV', 'Sports'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _catCard(Icons.star_rounded, 'Favorites', 'Saved'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: AdBanner(slot: 'home-middle'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF031A0B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kGreen.withOpacity(0.55)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: kGreen,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Secure Quantum Stream Pipeline Active',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: kGreen, size: 14),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: AdBanner(slot: 'home-bottom'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  '>   CONNECT   •   STREAM   •   ENJOY   <',
                  style: TextStyle(
                    color: Color(0xBF00FF66),
                    fontSize: 10.5,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// MORE DRAWER
// ═══════════════════════════════════════════════════════
class MoreDrawer extends StatefulWidget {
  const MoreDrawer({super.key});

  @override
  State<MoreDrawer> createState() => _MoreDrawerState();
}

class _MoreDrawerState extends State<MoreDrawer>
    with TickerProviderStateMixin {
  late AnimationController _snakeController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _snakeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _snakeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    Haptic.heavy();
    await MayaJaalAccount.signOut();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _launchURL(String url) async {
    Haptic.light();
    try {
      final target = Uri.parse(url);
      if (!await launchUrl(target, mode: LaunchMode.externalApplication)) {
        await launchUrl(target, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Launch error: $e');
      try {
        await launchUrl(Uri.parse(url));
      } catch (_) {}
    }
  }

  void _shareApp() {
    Haptic.light();
    Share.share(
      '🚀 Experience Matrix-speed streaming on MayaJaal App!\nDownload: https://www.mayajaal.online/download.html',
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: kGreen, width: 1.5),
        ),
        title: Row(
          children: const [
            Icon(Icons.info_outline, color: kGreen, size: 22),
            SizedBox(width: 8),
            Text(
              'ABOUT MAYAJAAL',
              style: TextStyle(
                color: kGreen,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MAYA JAAL',
                style: TextStyle(
                  color: kGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '— STREAM BEYOND LIMITS —',
                style: TextStyle(color: kDimGreen, fontSize: 10, letterSpacing: 2),
              ),
              SizedBox(height: 14),
              Text(
                'Version: v1.2.0 (Build 2)',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              SizedBox(height: 6),
              Text(
                'MayaJaal is a next-generation video streaming and monetization platform for creators. Convert, share, and earn effortlessly with Matrix-grade encryption and quantum-speed streaming.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
              ),
              SizedBox(height: 12),
              Text(
                '👥 18+ Platform · User-Generated Content',
                style: TextStyle(color: kGreen, fontSize: 11, height: 1.4),
              ),
              SizedBox(height: 14),
              Divider(color: Colors.white24),
              SizedBox(height: 8),
              Text(
                '© 2026 MayaJaal. All rights reserved.',
                style: TextStyle(color: kDimGreen, fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('CLOSE', style: TextStyle(color: kGreen)),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: kGreen, width: 1.5),
        ),
        title: Row(
          children: const [
            Icon(Icons.vpn_key, color: kGreen, size: 22),
            SizedBox(width: 8),
            Text(
              'YOUR API KEY',
              style: TextStyle(
                color: kGreen,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ye API key Telegram bot me use karein — /api YOUR_KEY',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kGreen.withOpacity(0.5)),
                ),
                child: SelectableText(
                  MayaJaalAccount.cachedApiKey ?? 'Loading...',
                  style: const TextStyle(
                    color: kGreen,
                    fontFamily: 'monospace',
                    fontSize: 13,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Email: ${MayaJaalAccount.cachedEmail ?? 'N/A'}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final key = MayaJaalAccount.cachedApiKey ?? '';
              if (key.isNotEmpty) {
                Haptic.medium();
                await Clipboard.setData(ClipboardData(text: key));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: kCardBg,
                      content: Text(
                        '✅ API Key copied',
                        style: TextStyle(color: kGreen),
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('COPY', style: TextStyle(color: kGreen)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('CLOSE', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  void _showBotsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF021206),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.smart_toy, color: kGreen, size: 24),
                SizedBox(width: 10),
                Text(
                  'MAYAJAAL BOTS',
                  style: TextStyle(
                    color: kGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a bot to start earning',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
            ),
            const SizedBox(height: 18),
            _botCard(
              context,
              icon: Icons.upload_rounded,
              color: kNeonCyan,
              title: 'Upload Bot',
              subtitle: 'Upload videos & get your own link',
              url: 'https://t.me/Mayajaalfilebot',
            ),
            const SizedBox(height: 12),
            _botCard(
              context,
              icon: Icons.link_rounded,
              color: kNeonPurple,
              title: 'Converter Bot',
              subtitle: 'Convert links & earn from sharing',
              url: 'https://t.me/MayaJaalBulkConverterbot',
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _botCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String url,
  }) {
    return InkWell(
      onTap: () {
        Haptic.medium();
        Navigator.pop(context);
        _launchURL(url);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.5)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 1.5),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.5), blurRadius: 12),
                ],
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _staggered({required int index, required Widget child}) {
    final start = (index * 0.06).clamp(0.0, 0.6);
    return AnimatedBuilder(
      animation: _slideController,
      builder: (c, _) {
        final raw = (_slideController.value - start) / (1 - start);
        final v = raw.clamp(0.0, 1.0);
        final curve = Curves.easeOutCubic.transform(v);
        return Opacity(
          opacity: curve,
          child: Transform.translate(
            offset: Offset(-20 * (1 - curve), 0),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF011206),
                border: Border(
                  bottom: BorderSide(
                    color: kGreen.withOpacity(0.4),
                    width: 1.2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGreen, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: kGreen.withOpacity(0.5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/icon/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.change_history,
                          color: kGreen,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'MayaJaal',
                          style: TextStyle(
                            color: kGreen,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            shadows: [Shadow(color: kGreen, blurRadius: 10)],
                          ),
                        ),
                        Text(
                          'MORE OPTIONS',
                          style: TextStyle(
                            color: kGreen.withOpacity(0.7),
                            fontSize: 8.5,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: kGreen, size: 22),
                    onPressed: () {
                      Haptic.light();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _staggered(index: 0, child: _LivePulseCard()),
                  _staggered(
                    index: 1,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: kCardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kGreen.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: kGreen, width: 1.5),
                            ),
                            child: user?.photoURL != null
                                ? ClipOval(
                                    child: Image.network(
                                      user!.photoURL!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => const Icon(
                                        Icons.person,
                                        color: kGreen,
                                        size: 22,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.person, color: kGreen, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.displayName ?? user?.email ?? 'User',
                                  style: const TextStyle(
                                    color: kGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.verified,
                                      color: kGreen.withOpacity(0.7),
                                      size: 10,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'MayaJaal Verified',
                                      style: TextStyle(
                                        color: kGreen.withOpacity(0.7),
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _staggered(
                    index: 2,
                    child: _snakeItem(
                      context,
                      icon: Icons.account_balance_wallet,
                      color: kGold,
                      title: 'Earnings Dashboard',
                      subtitle: 'View your earnings and links',
                      onTap: () {
                        Haptic.medium();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EarningsScreen()),
                        );
                      },
                    ),
                  ),
                  _staggered(
                    index: 3,
                    child: _snakeItem(
                      context,
                      icon: Icons.account_balance,
                      color: kGreen,
                      title: 'Withdraw Earnings',
                      subtitle: 'Minimum \$5 · Bank / UPI',
                      onTap: () {
                        Haptic.medium();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const WithdrawScreen()),
                        );
                      },
                    ),
                  ),
                  _staggered(
                    index: 4,
                    child: _snakeItem(
                      context,
                      icon: Icons.bookmark,
                      color: kNeonCyan,
                      title: 'Saved Videos',
                      subtitle: 'Your bookmarked videos',
                      onTap: () {
                        Haptic.medium();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SavedVideosScreen()),
                        );
                      },
                    ),
                  ),
                  _staggered(
                    index: 5,
                    child: _snakeItem(
                      context,
                      icon: Icons.vpn_key,
                      color: kNeonPurple,
                      title: 'My API Key',
                      subtitle: 'View & copy for bot',
                      onTap: () {
                        Haptic.medium();
                        Navigator.pop(context);
                        _showApiKeyDialog(context);
                      },
                    ),
                  ),
                  _staggered(
                    index: 6,
                    child: _snakeItem(
                      context,
                      icon: Icons.smart_toy,
                      color: Colors.amberAccent,
                      title: 'MayaJaal Bots',
                      subtitle: 'Upload & Converter bots',
                      onTap: () {
                        Haptic.medium();
                        Navigator.pop(context);
                        _showBotsDialog(context);
                      },
                    ),
                  ),
                  _staggered(
                    index: 7,
                    child: _snakeItem(
                      context,
                      icon: Icons.share,
                      color: kNeonCyan,
                      title: 'Share MayaJaal App',
                      subtitle: 'Invite your friends',
                      onTap: () {
                        Navigator.pop(context);
                        _shareApp();
                      },
                    ),
                  ),
                  _staggered(
                    index: 8,
                    child: _snakeItem(
                      context,
                      icon: Icons.settings,
                      color: kGreen,
                      title: 'App Settings',
                      subtitle: 'Customize your experience',
                      onTap: () {
                        Haptic.medium();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),
                  ),
                  _staggered(
                    index: 9,
                    child: _snakeItem(
                      context,
                      icon: Icons.support_agent,
                      color: Colors.amberAccent,
                      title: 'Help & Support',
                      subtitle: 'mayajaalsupport@gmail.com',
                      onTap: () {
                        Navigator.pop(context);
                        _launchURL(
                          'mailto:mayajaalsupport@gmail.com?subject=MayaJaal%20Support',
                        );
                      },
                    ),
                  ),
                  _staggered(
                    index: 10,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, top: 18, bottom: 8),
                      child: Row(
                        children: [
                          Container(width: 14, height: 1.5, color: kGreen),
                          const SizedBox(width: 6),
                          const Text(
                            'JOIN US',
                            style: TextStyle(
                              color: kGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(height: 1, color: kGreen.withOpacity(0.3)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _staggered(
                    index: 11,
                    child: _socialItem(
                      context,
                      imageUrl:
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Instagram_logo_2016.svg/240px-Instagram_logo_2016.svg.png',
                      fallbackIcon: Icons.camera_alt,
                      color: const Color(0xFFE1306C),
                      title: 'Instagram Official',
                      subtitle: '@maya_jaal_official',
                      onTap: () {
                        Navigator.pop(context);
                        _launchURL('https://www.instagram.com/maya_jaal_official');
                      },
                    ),
                  ),
                  _staggered(
                    index: 12,
                    child: _socialItem(
                      context,
                      imageUrl:
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/0/09/YouTube_full-color_icon_%282017%29.svg/240px-YouTube_full-color_icon_%282017%29.svg.png',
                      fallbackIcon: Icons.play_circle_fill,
                      color: Colors.redAccent,
                      title: 'YouTube Channel',
                      subtitle: '@MayaJaalOfficial00',
                      onTap: () {
                        Navigator.pop(context);
                        _launchURL('https://www.youtube.com/@MayaJaalOfficial00');
                      },
                    ),
                  ),
                  _staggered(
                    index: 13,
                    child: _socialItem(
                      context,
                      imageUrl:
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/8/82/Telegram_logo.svg/240px-Telegram_logo.svg.png',
                      fallbackIcon: Icons.send_rounded,
                      color: const Color(0xFF229ED9),
                      title: 'Telegram Channel',
                      subtitle: '@MayaJaalOfficial',
                      onTap: () {
                        Navigator.pop(context);
                        _launchURL('https://t.me/MayaJaalOfficial');
                      },
                    ),
                  ),
                  _staggered(
                    index: 14,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, top: 18, bottom: 8),
                      child: Row(
                        children: [
                          Container(width: 14, height: 1.5, color: kNeonCyan),
                          const SizedBox(width: 6),
                          const Text(
                            'INFORMATION',
                            style: TextStyle(
                              color: kNeonCyan,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(height: 1, color: kNeonCyan.withOpacity(0.3)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _staggered(
                    index: 15,
                    child: _snakeItem(
                      context,
                      icon: Icons.info_outline,
                      color: kNeonCyan,
                      title: 'About MayaJaal',
                      subtitle: 'Version & info',
                      onTap: () {
                        Haptic.medium();
                        Navigator.pop(context);
                        _showAboutDialog(context);
                      },
                    ),
                  ),
                  _staggered(
                    index: 16,
                    child: _snakeItem(
                      context,
                      icon: Icons.privacy_tip_outlined,
                      color: kDimGreen,
                      title: 'Privacy Policy',
                      subtitle: 'Opens in browser',
                      onTap: () {
                        Navigator.pop(context);
                        _launchURL('https://www.mayajaal.online/privacy.html');
                      },
                    ),
                  ),
                  _staggered(
                    index: 17,
                    child: _snakeItem(
                      context,
                      icon: Icons.description_outlined,
                      color: kDimGreen,
                      title: 'Terms & Conditions',
                      subtitle: 'Opens in browser',
                      onTap: () {
                        Navigator.pop(context);
                        _launchURL('https://www.mayajaal.online/terms.html');
                      },
                    ),
                  ),
                  _staggered(
                    index: 18,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.logout, color: Colors.redAccent),
                          title: const Text(
                            'Logout Session',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _logout(context);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _snakeItem(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: AnimatedBuilder(
        animation: _snakeController,
        builder: (c, _) {
          return Stack(
            children: [
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.5)),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                title: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10.5,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  color: color,
                  size: 14,
                ),
                onTap: onTap,
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CustomPaint(
                      painter: SnakeBorderPainter(
                        progress: _snakeController.value,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _socialItem(
    BuildContext context, {
    required String imageUrl,
    required IconData fallbackIcon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.7), width: 1.2),
          ),
          padding: const EdgeInsets.all(5),
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => Icon(fallbackIcon, color: color, size: 22),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10.5,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: color, size: 14),
        onTap: onTap,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// LIVE PULSE CARD
// ═══════════════════════════════════════════════════════
class _LivePulseCard extends StatefulWidget {
  @override
  State<_LivePulseCard> createState() => _LivePulseCardState();
}

class _LivePulseCardState extends State<_LivePulseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _blink;
  double _currentEarning = 0;
  double _prevEarning = 0;
  bool _hasData = false;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MayaJaalAccount.cachedUid == null) return const SizedBox.shrink();

    return StreamBuilder<Map<String, dynamic>>(
      stream: MayaJaalAccount.getDashboardStream(),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final totalViews = (data['totalViews'] ?? 0) as int;
        final earning = MayaJaalAccount.calcEarnings(totalViews);
        if (earning != _currentEarning) {
          _prevEarning = _currentEarning;
          _currentEarning = earning;
          _hasData = true;
        }
        final up = _currentEarning >= _prevEarning;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [kGreen.withOpacity(0.12), Colors.black],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kGreen.withOpacity(0.5), width: 1.2),
            boxShadow: [BoxShadow(color: kGreen.withOpacity(0.15), blurRadius: 12)],
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _blink,
                builder: (c, _) => Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kGreen,
                    boxShadow: [
                      BoxShadow(
                        color: kGreen.withOpacity(0.7 * _blink.value),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVE PULSE',
                      style: TextStyle(
                        color: kGreen.withOpacity(0.8),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _hasData ? '\$${_currentEarning.toStringAsFixed(2)}' : '—',
                      style: const TextStyle(
                        color: kGreen,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: kGreen, blurRadius: 10)],
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasData)
                Icon(
                  up ? Icons.trending_up : Icons.trending_down,
                  color: up ? kGreen : Colors.orangeAccent,
                  size: 22,
                ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
// SNAKE BORDER PAINTER
// ═══════════════════════════════════════════════════════
class SnakeBorderPainter extends CustomPainter {
  final double progress;
  final Color color;

  SnakeBorderPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().first;
    final totalLength = metrics.length;

    final snakeLength = totalLength * 0.25;
    final startPos = (progress * totalLength) % totalLength;
    final endPos = startPos + snakeLength;

    final extractPath = Path();
    if (endPos <= totalLength) {
      extractPath.addPath(
        metrics.extractPath(startPos, endPos),
        Offset.zero,
      );
    } else {
      extractPath.addPath(
        metrics.extractPath(startPos, totalLength),
        Offset.zero,
      );
      extractPath.addPath(
        metrics.extractPath(0, endPos - totalLength),
        Offset.zero,
      );
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawPath(extractPath, paint);

    final corePaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(extractPath, corePaint);
  }

  @override
  bool shouldRepaint(covariant SnakeBorderPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
// ═══════════════════════════════════════════════════════
// CHANNEL SCREEN
// ═══════════════════════════════════════════════════════
class ChannelScreen extends StatelessWidget {
  const ChannelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('CHANNELS & NODES')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kGreen.withOpacity(0.4)),
            ),
            child: const ListTile(
              leading: Icon(Icons.bolt, color: kGreen, size: 32),
              title: Text(
                'Quantum Streaming Node',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Direct hardware pipeline active',
                style: TextStyle(color: kDimGreen, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kNeonCyan.withOpacity(0.4)),
            ),
            child: const ListTile(
              leading: Icon(Icons.cloud_done, color: kNeonCyan, size: 32),
              title: Text(
                'High Speed CDN Node',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Buffer acceleration: ENABLED',
                style: TextStyle(color: kNeonCyan, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kNeonPurple.withOpacity(0.4)),
            ),
            child: const ListTile(
              leading: Icon(Icons.security, color: kNeonPurple, size: 32),
              title: Text(
                'Encrypted Pipeline',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'AES-256 quantum cipher: ACTIVE',
                style: TextStyle(color: kNeonPurple, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// GALLERY SCREEN
// ═══════════════════════════════════════════════════════
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});
  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<AssetEntity> _allAssets = [];
  List<AssetEntity> _videos = [];
  List<AssetEntity> _images = [];
  bool _loading = true;
  bool _permissionDenied = false;
  String _selectedTab = 'all';

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth && !permission.hasAccess) {
        setState(() {
          _loading = false;
          _permissionDenied = true;
        });
        return;
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        onlyAll: true,
      );

      if (albums.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final recent = albums.first;
      final assets = await recent.getAssetListPaged(page: 0, size: 200);

      final videos = <AssetEntity>[];
      final images = <AssetEntity>[];

      for (final a in assets) {
        if (a.type == AssetType.video) {
          videos.add(a);
        } else if (a.type == AssetType.image) {
          images.add(a);
        }
      }

      if (mounted) {
        setState(() {
          _allAssets = assets;
          _videos = videos;
          _images = images;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Gallery error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _permissionDenied = true;
        });
      }
    }
  }

  List<AssetEntity> get _currentAssets {
    switch (_selectedTab) {
      case 'videos':
        return _videos;
      case 'images':
        return _images;
      default:
        return _allAssets;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('GALLERY'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kGreen),
            onPressed: () {
              Haptic.light();
              setState(() => _loading = true);
              _loadGallery();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : _permissionDenied
              ? _buildPermissionDenied()
              : Column(
                  children: [
                    _buildTabs(),
                    const SizedBox(height: 4),
                    Expanded(
                      child: _currentAssets.isEmpty
                          ? _buildEmpty()
                          : _buildGrid(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_library_outlined, color: kGreen, size: 80),
            const SizedBox(height: 16),
            const Text(
              'GALLERY PERMISSION NEEDED',
              style: TextStyle(color: kGreen, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please allow gallery access to view your photos and videos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => PhotoManager.openSetting(),
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('OPEN SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, color: kGreen.withOpacity(0.4), size: 80),
          const SizedBox(height: 12),
          Text(
            'Koi ${_selectedTab == 'videos' ? 'video' : _selectedTab == 'images' ? 'photo' : 'media'} nahi mila',
            style: TextStyle(color: kGreen.withOpacity(0.6), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF011206),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGreen.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          _tabButton('all', 'ALL', Icons.apps),
          _tabButton('videos', 'VIDEOS', Icons.videocam),
          _tabButton('images', 'PHOTOS', Icons.image),
        ],
      ),
    );
  }

  Widget _tabButton(String key, String label, IconData icon) {
    final active = _selectedTab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Haptic.selection();
          setState(() => _selectedTab = key);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF01240B) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: kGreen, width: 1.2) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: active ? kGreen : Colors.white54, size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: active ? kGreen : Colors.white54,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemCount: _currentAssets.length,
      itemBuilder: (context, index) => _buildTile(_currentAssets[index]),
    );
  }

  Widget _buildTile(AssetEntity asset) {
    final isVideo = asset.type == AssetType.video;
    return GestureDetector(
      onTap: () {
        Haptic.light();
        _openPreview(asset);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AssetEntityImage(
              asset,
              isOriginal: false,
              thumbnailSize: const ThumbnailSize.square(300),
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                color: kCardBg,
                child: const Icon(Icons.broken_image, color: kGreen),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kGreen.withOpacity(0.3), width: 1),
              ),
            ),
          ),
          if (isVideo)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: kGreen.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow, color: kGreen, size: 10),
                    const SizedBox(width: 2),
                    Text(
                      _formatDuration(asset.duration),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          if (isVideo)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: kGreen.withOpacity(0.9), shape: BoxShape.circle),
                child: const Icon(Icons.videocam, color: Colors.black, size: 10),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _openPreview(AssetEntity asset) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 5,
                child: AssetEntityImage(
                  asset,
                  isOriginal: true,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: kGreen, size: 60),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  Haptic.light();
                  Navigator.pop(c);
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                    border: Border.all(color: kGreen, width: 1.5),
                  ),
                  child: const Icon(Icons.close, color: kGreen, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// SAVED VIDEOS SCREEN (Naya Option)
// ═══════════════════════════════════════════════════════
class SavedVideosScreen extends StatefulWidget {
  const SavedVideosScreen({super.key});
  @override
  State<SavedVideosScreen> createState() => _SavedVideosScreenState();
}

class _SavedVideosScreenState extends State<SavedVideosScreen> {
  List<Map<String, dynamic>> _saved = [];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('saved_videos_v1');
    if (jsonStr != null) {
      try {
        final List decoded = jsonDecode(jsonStr);
        if (mounted) setState(() => _saved = decoded.cast<Map<String, dynamic>>());
      } catch (_) {}
    }
  }

  Future<void> _removeSaved(int index) async {
    Haptic.light();
    final prefs = await SharedPreferences.getInstance();
    setState(() => _saved.removeAt(index));
    await prefs.setString('saved_videos_v1', jsonEncode(_saved));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('SAVED VIDEOS')),
      body: _saved.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 60, color: kGreen.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  Text('No saved videos yet', style: TextStyle(color: kGreen.withOpacity(0.6))),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _saved.length,
              itemBuilder: (c, i) {
                final item = _saved[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kGreen.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.play_circle_fill, color: kGreen, size: 30),
                    title: Text(
                      item['title'] ?? 'Video',
                      style: const TextStyle(fontSize: 13, color: kGreen, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'By: ${item['uploader'] ?? 'Node'}',
                      style: TextStyle(fontSize: 11, color: kDimGreen.withOpacity(0.8)),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                      onPressed: () => _removeSaved(i),
                    ),
                    onTap: () {
                      Haptic.light();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StreamPreviewScreen(targetUrl: item['url']),
                        ),
                      ).then((_) => _loadSaved());
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// HISTORY SCREEN (With Thumbnail & Save Feature)
// ═══════════════════════════════════════════════════════
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final localJson = prefs.getString('watch_history_v2');
    if (localJson != null) {
      try {
        final List decoded = jsonDecode(localJson);
        if (mounted) setState(() => _history = decoded.cast<Map<String, dynamic>>());
      } catch (_) {}
    }
  }

  Future<void> _deleteItem(int index) async {
    Haptic.light();
    final prefs = await SharedPreferences.getInstance();
    setState(() => _history.removeAt(index));
    await prefs.setString('watch_history_v2', jsonEncode(_history));
  }

  Future<void> _clearAll() async {
    Haptic.medium();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('watch_history_v2');
    setState(() => _history = []);
  }

  Future<void> _saveItem(Map<String, dynamic> item) async {
    Haptic.medium();
    final prefs = await SharedPreferences.getInstance();
    final savedStr = prefs.getString('saved_videos_v1');
    List<Map<String, dynamic>> savedList = [];
    if (savedStr != null) {
      try {
        savedList = (jsonDecode(savedStr) as List).cast<Map<String, dynamic>>();
      } catch (_) {}
    }

    if (savedList.any((s) => s['url'] == item['url'])) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: kCardBg, content: Text('Already saved!', style: TextStyle(color: kGreen))),
        );
      }
      return;
    }

    savedList.insert(0, item);
    await prefs.setString('saved_videos_v1', jsonEncode(savedList));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: kCardBg, content: Text('✅ Video Saved!', style: TextStyle(color: kGreen))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('WATCH HISTORY'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.orangeAccent),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: kGreen.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  Text(tr('no_history'), style: TextStyle(color: kGreen.withOpacity(0.6))),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length,
              itemBuilder: (c, i) {
                final item = _history[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kGreen.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kGreen.withOpacity(0.5)),
                      ),
                      child: const Icon(Icons.play_circle_outline, color: kGreen, size: 28),
                    ),
                    title: Text(
                      item['title'] ?? 'Media Node',
                      style: const TextStyle(fontSize: 13, color: kGreen, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'By: ${item['uploader'] ?? 'Node'}',
                      style: TextStyle(fontSize: 11, color: kDimGreen.withOpacity(0.8)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.bookmark_add_outlined, size: 20, color: kNeonCyan),
                          onPressed: () => _saveItem(item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                          onPressed: () => _deleteItem(i),
                        ),
                      ],
                    ),
                    onTap: () {
                      Haptic.light();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StreamPreviewScreen(targetUrl: item['url']),
                        ),
                      ).then((_) => _loadHistory());
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// SETTINGS SCREEN
// ═══════════════════════════════════════════════════════
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkTheme = true;
  String _language = 'English';
  String _downloadLocation = 'Internal Storage / Mayajaall';

  final List<String> _languages = ['English', 'Hindi'];
  final List<String> _downloadLocations = [
    'Internal Storage / Mayajaall',
    'Internal Storage / Download',
    'Internal Storage / Movies'
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkTheme = prefs.getBool('dark_theme') ?? true;
      _language = prefs.getString('language') ?? 'English';
      _downloadLocation = prefs.getString('download_location') ?? 'Internal Storage / Mayajaall';
    });
  }

  Future<void> _saveDarkTheme(bool value) async {
    Haptic.selection();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_theme', value);
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
    setState(() => _darkTheme = value);
  }

  Future<void> _saveLanguage(String value) async {
    Haptic.selection();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', value);
    languageNotifier.value = value;
    setState(() => _language = value);
  }

  Future<void> _saveDownloadLocation(String value) async {
    Haptic.selection();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('download_location', value);
    setState(() => _downloadLocation = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(tr('settings'))),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.palette_outlined, color: kGreen),
            title: Text(tr('dark_theme'), style: const TextStyle(color: kGreen)),
            subtitle: Text(
              _darkTheme ? 'Matrix Cyber Neon' : 'Standard Light',
              style: TextStyle(color: kGreen.withOpacity(0.6), fontSize: 12),
            ),
            trailing: Switch(
              value: _darkTheme,
              activeColor: kGreen,
              onChanged: _saveDarkTheme,
            ),
          ),
          Divider(color: kGreen.withOpacity(0.2)),
          ListTile(
            leading: const Icon(Icons.language, color: kGreen),
            title: Text(tr('language'), style: const TextStyle(color: kGreen)),
            subtitle: Text(_language, style: TextStyle(color: kGreen.withOpacity(0.6), fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: kGreen),
            onTap: _showLanguageDialog,
          ),
          Divider(color: kGreen.withOpacity(0.2)),
          ListTile(
            leading: const Icon(Icons.download, color: kGreen),
            title: Text(tr('download_location'), style: const TextStyle(color: kGreen)),
            subtitle: Text(_downloadLocation, style: TextStyle(color: kGreen.withOpacity(0.6), fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: kGreen),
            onTap: _showDownloadLocationDialog,
          ),
          Divider(color: kGreen.withOpacity(0.2)),
          const SizedBox(height: 30),
          Center(
            child: Text('> MayaJaal v1.2.0 // Quantum Core',
              style: TextStyle(color: kGreen.withOpacity(0.5), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: kGreen.withOpacity(0.5))),
        title: Text(tr('language'), style: const TextStyle(color: kGreen)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _languages.map((l) {
            return RadioListTile<String>(
              title: Text(l, style: const TextStyle(color: kGreen)),
              value: l,
              groupValue: _language,
              activeColor: kGreen,
              onChanged: (val) {
                if (val != null) {
                  _saveLanguage(val);
                  Navigator.pop(c);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showDownloadLocationDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: kGreen.withOpacity(0.5))),
        title: Text(tr('download_location'), style: const TextStyle(color: kGreen)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _downloadLocations.map((loc) {
            return RadioListTile<String>(
              title: Text(loc, style: const TextStyle(color: kGreen, fontSize: 12)),
              value: loc,
              groupValue: _downloadLocation,
              activeColor: kGreen,
              onChanged: (val) {
                if (val != null) {
                  _saveDownloadLocation(val);
                  Navigator.pop(c);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// STREAM PREVIEW SCREEN (10-Sec Page)
// ═══════════════════════════════════════════════════════
class StreamPreviewScreen extends StatefulWidget {
  final String targetUrl;
  const StreamPreviewScreen({super.key, required this.targetUrl});
  @override
  State<StreamPreviewScreen> createState() => _StreamPreviewScreenState();
}

class _StreamPreviewScreenState extends State<StreamPreviewScreen>
    with TickerProviderStateMixin {
  bool _loading = true;
  String _streamUrl = '';
  String _videoTitle = 'MayaJaal Video';
  String _uploaderName = '@mayajaal';
  String _rawId = '';
  String _token = '';

  VideoPlayerController? _previewController; // ✅ In-App Thumbnail Controller
  bool _previewReady = false;

  int _countdown = 10;
  Timer? _countdownTimer;
  bool get _canProceed => _countdown <= 0;

  late AnimationController _snakeCtrl;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _snakeCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    if (!MayaJaalAccount.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: kCardBg, content: Text('Please login to watch videos', style: TextStyle(color: kGreen))),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      });
      return;
    }

    _fetchStreamMetadata();
  }

  void _initThumbnail(String url) {
    _previewController = VideoPlayerController.networkUrl(Uri.parse(url));
    _previewController!.initialize().then((_) {
      _previewController!.setLooping(true);
      _previewController!.setVolume(0); // Mute the preview
      _previewController!.play(); // Play in background as per user request
      if (mounted) setState(() => _previewReady = true);
    }).catchError((e) {
      debugPrint("Thumbnail init error: $e");
    });
  }

  void _warmupVideoStream() {
    if (_streamUrl.isEmpty) return;
    try {
      final uri = Uri.parse(_streamUrl);
      final client = HttpClient();
      client.getUrl(uri).then((req) {
        req.headers.set('Range', 'bytes=0-1048575');
        return req.close();
      }).then((resp) {
        resp.listen((_) {}).cancel();
      }).catchError((e) => debugPrint('Warmup: $e'));
    } catch (e) {}
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdown = 10;
    _warmupVideoStream();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
          if (_countdown <= 3 && _countdown > 0) Haptic.light();
        } else {
          Haptic.heavy();
          _countdownTimer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _snakeCtrl.dispose();
    _pulseController.dispose();
    _previewController?.dispose(); // Cleanup thumbnail controller
    super.dispose();
  }

  Future<void> _fetchStreamMetadata() async {
    try {
      final uri = Uri.parse(widget.targetUrl);
      _rawId = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'stream';
      _token = uri.queryParameters['t'] ?? uri.queryParameters['s'] ?? '';

      if (widget.targetUrl.endsWith('.mp4') || widget.targetUrl.endsWith('.m3u8')) {
        setState(() {
          _streamUrl = widget.targetUrl;
          _videoTitle = _rawId;
          _loading = false;
        });
        _initThumbnail(_streamUrl);
        _startCountdown();
        return;
      }

      final apiUrl = _token.isNotEmpty
          ? '$kBackendBaseUrl/api/stream-info/$_rawId?t=$_token'
          : '$kBackendBaseUrl/api/stream-info/$_rawId';

      final res = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && (data['url'] != null || data['video_url'] != null)) {
          setState(() {
            _streamUrl = data['url'] ?? data['video_url'];
            _videoTitle = data['title'] ?? data['file_name'] ?? _rawId;
            _uploaderName = data['uploader'] ?? '@mayajaal';
            _loading = false;
          });
          _initThumbnail(_streamUrl);
          _startCountdown();
          return;
        }
      }

      setState(() {
        _streamUrl = widget.targetUrl;
        _loading = false;
      });
      _initThumbnail(_streamUrl);
      _startCountdown();
    } catch (e) {
      setState(() {
        _streamUrl = widget.targetUrl;
        _loading = false;
      });
      _initThumbnail(_streamUrl);
      _startCountdown();
    }
  }

  void _shareStreamDirect() {
    Haptic.light();
    Share.share('🚀 Watch this stream on MayaJaal:\n${widget.targetUrl}');
  }

  Future<void> _saveWatchRecord() async {
    final prefs = await SharedPreferences.getInstance();
    final localJson = prefs.getString('watch_history_v2');
    List<Map<String, dynamic>> history = [];
    if (localJson != null) {
      try {
        final List decoded = jsonDecode(localJson);
        history = decoded.cast<Map<String, dynamic>>();
      } catch (_) {}
    }

    final item = {
      'url': widget.targetUrl,
      'title': _videoTitle,
      'uploader': _uploaderName,
      'id': _rawId,
      'time': DateTime.now().toIso8601String(),
    };

    history.removeWhere((h) => h['url'] == widget.targetUrl);
    history.insert(0, item);
    if (history.length > 50) history.removeLast();

    await prefs.setString('watch_history_v2', jsonEncode(history));
  }

  void _launchNativePlayer() {
    if (!_canProceed) return;
    Haptic.heavy();
    _saveWatchRecord();

    // ✅ STRICT NAVIGATION FIX: Push and wait for return to restart countdown
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NativeVideoPlayerScreen(
          videoUrl: _streamUrl,
          title: _videoTitle,
          uploader: _uploaderName,
          sourcePageUrl: widget.targetUrl,
          videoId: _rawId,
        ),
      ),
    ).then((_) {
      // When user comes back from the player, restart the 10s countdown
      if (mounted) {
        _startCountdown();
      }
    });
  }

  void _goToHome() {
    Haptic.heavy();
    // Go back to the very first screen (MainNavigationHolder)
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildCountdownCircle() {
    final progress = 1.0 - (_countdown / 10.0);
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 7,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(_canProceed ? kGreen : Colors.orangeAccent),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _canProceed ? Icons.check_circle_outline : Icons.timer,
                color: _canProceed ? kGreen : Colors.orangeAccent,
                size: 40,
              ),
              const SizedBox(height: 4),
              Text(
                _canProceed ? 'READY' : '$_countdown',
                style: TextStyle(
                  color: _canProceed ? kGreen : Colors.orangeAccent,
                  fontSize: _canProceed ? 18 : 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  shadows: [Shadow(color: (_canProceed ? kGreen : Colors.orangeAccent).withOpacity(0.7), blurRadius: 15)],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRedSnakePlayButton() {
    return AnimatedBuilder(
      animation: Listenable.merge([_snakeCtrl, _pulseAnimation]),
      builder: (c, _) => Transform.scale(
        scale: _pulseAnimation.value,
        child: GestureDetector(
          onTap: _launchNativePlayer,
          child: Container(
            width: double.infinity,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [BoxShadow(color: kRed.withOpacity(0.5), blurRadius: 22, spreadRadius: 1)],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: SnakeBorderPainter(progress: _snakeCtrl.value, color: kRed)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.play_arrow_rounded, color: kRed, size: 32),
                    SizedBox(width: 8),
                    Text(
                      'PLAY NOW',
                      style: TextStyle(color: kRed, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 2.5, shadows: [Shadow(color: kRed, blurRadius: 14)]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const ProfessionalLoader(message: 'DECRYPTING STREAM...');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const MatrixRain(opacity: 0.35),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  // Top Bar
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: kGreen, size: 22),
                        onPressed: () {
                          Haptic.light();
                          Navigator.pop(context); // ✅ Goes back to History/Home
                        },
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'STREAM READY',
                              style: TextStyle(color: kGreen, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 2, shadows: [Shadow(color: kGreen, blurRadius: 12)]),
                            ),
                            Text(
                              'MATRIX NEURAL STREAM',
                              style: TextStyle(color: kGreen.withOpacity(0.7), fontSize: 9, letterSpacing: 2.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kGreen.withOpacity(0.6))),
                        child: const Icon(Icons.verified_user_rounded, color: kGreen, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // ✅ Video Preview Box (Playing Live Video)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF011206),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _canProceed ? kGreen : Colors.orangeAccent.withOpacity(0.6), width: 1.8),
                      boxShadow: [BoxShadow(color: (_canProceed ? kGreen : Colors.orangeAccent).withOpacity(0.25), blurRadius: 30)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          alignment: Alignment.center,
                          children: [
                            // Live Video Frame
                            if (_previewReady && _previewController != null)
                              FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _previewController!.value.size.width,
                                  height: _previewController!.value.size.height,
                                  child: VideoPlayer(_previewController!),
                                ),
                              )
                            else
                              Container(
                                color: Colors.black,
                                child: Center(
                                  child: Image.asset(
                                    'assets/icon/logo.png',
                                    width: 75,
                                    height: 75,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Icon(Icons.movie_filter, color: kGreen, size: 55),
                                  ),
                                ),
                              ),
                              
                            // Dark Overlay
                            Container(color: Colors.black.withOpacity(0.4)),
                            
                            // Countdown
                            _buildCountdownCircle(),
                            
                            // HD Badge
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(5), border: Border.all(color: kGreen, width: 1)),
                                child: const Text('HD', style: TextStyle(color: kGreen, fontSize: 9.5, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  
                  // Play Button
                  if (_canProceed)
                    _buildRedSnakePlayButton()
                  else
                    Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(32)),
                      child: Center(
                        child: Text(
                          'UNLOCK IN $_countdown SEC',
                          style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2),
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 12),

                  // ✅ Home Button (Below Play Button)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _goToHome,
                      icon: const Icon(Icons.home, color: Colors.white54, size: 20),
                      label: const Text('GO TO HOME PAGE', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white24, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  
                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF031A0B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kGreen.withOpacity(0.35)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black, border: Border.all(color: kGreen.withOpacity(0.5))),
                              child: const Icon(Icons.video_collection_outlined, color: kGreen, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('FILE NAME', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9.5, letterSpacing: 1)),
                                  const SizedBox(height: 2),
                                  Text(_videoTitle, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(color: kGreen.withOpacity(0.15)),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black, border: Border.all(color: kGreen.withOpacity(0.5))),
                              child: const Icon(Icons.person_outline, color: kGreen, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('UPLOADER', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9.5, letterSpacing: 1)),
                                  const SizedBox(height: 2),
                                  Text(_uploaderName, style: const TextStyle(color: kGreen, fontSize: 13.5, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Share Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _shareStreamDirect,
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: kGreen, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.share, color: kGreen, size: 20),
                          SizedBox(width: 10),
                          Text('SHARE VIDEO', style: TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// NATIVE VIDEO PLAYER
// ═══════════════════════════════════════════════════════
class NativeVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String uploader;
  final String sourcePageUrl;
  final String videoId;

  const NativeVideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.uploader,
    required this.sourcePageUrl,
    required this.videoId,
  });

  @override
  State<NativeVideoPlayerScreen> createState() => _NativeVideoPlayerScreenState();
}

class _NativeVideoPlayerScreenState extends State<NativeVideoPlayerScreen> {
  late VideoPlayerController _controller;

  bool _isInitialized = false;
  bool _hasError = false;

  bool _isFullscreen = false;
  String _flashFeedback = '';
  Timer? _feedbackTimer;

  bool _showControls = true;
  Timer? _controlsTimer;

  double _playbackSpeed = 1.0;
  final List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  bool _isLongPressBoost = false;

  String _selectedQuality = 'Auto (1080p)';
  final List<String> _qualities = ['Auto (1080p)', '1080p FHD', '720p HD', '480p SD', '360p Low'];

  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  double _volume = 1.0;
  double _brightness = 1.0;
  double _brightnessStart = 1.0;
  double _volumeStart = 1.0;
  double _dragStartY = 0;
  bool _isAdjustingVolume = false;
  bool _isAdjustingBrightness = false;

  Map<String, int> _stats = {'views': 0, 'likes': 0, 'unlikes': 0, 'shares': 0};
  bool _isLiked = false;
  bool _isUnliked = false;
  bool _isSaved = false;
  String _ownerUid = '';

  StreamSubscription? _statsSub;
  StreamSubscription? _likeSub;
  StreamSubscription? _unlikeSub;

  bool _viewReported = false;
  Timer? _watchTimer;
  int _watchedSeconds = 0;

  List<Map<String, dynamic>> _relatedVideos = [];
  bool _relatedLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserPrefs();
    _initVideo();
    _startStatsListeners();
    _fetchOwner().then((_) => _loadRelatedVideos());
  }

  Future<void> _reportViewToBackend() async {
    if (_viewReported) return;
    _viewReported = true;

    try {
      final uri = Uri.parse(widget.sourcePageUrl);
      final token = uri.queryParameters['t'] ?? uri.queryParameters['s'] ?? '';
      final deviceId = await DeviceIdHelper.get();

      final url = token.isNotEmpty
          ? '$kBackendBaseUrl/api/view/${widget.videoId}?t=$token'
          : '$kBackendBaseUrl/api/view/${widget.videoId}';

      await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'playedSeconds': _watchedSeconds, 'deviceId': deviceId, 'token': token}),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('View report error: $e');
    }
  }

  void _startWatchTracking() {
    _watchTimer?.cancel();
    _watchTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_controller.value.isInitialized && _controller.value.isPlaying) {
        _watchedSeconds++;
        if (_watchedSeconds == 10 && !_viewReported) {
          _reportViewToBackend();
        }
      }
    });
  }

  void _startStatsListeners() {
    final uid = MayaJaalAccount.cachedUid;
    if (uid == null) return;

    _statsSub = FirebaseService.getVideoStatsStream(widget.videoId).listen((s) {
      if (mounted) setState(() => _stats = s);
    });

    _likeSub = FirebaseService.isLikedStream(widget.videoId, uid).listen((liked) {
      if (mounted) setState(() => _isLiked = liked);
    });

    _unlikeSub = FirebaseService.isUnlikedStream(widget.videoId, uid).listen((unliked) {
      if (mounted) setState(() => _isUnliked = unliked);
    });
  }

  Future<void> _fetchOwner() async {
    try {
      final snap = await FirebaseDatabase.instance.ref('links/${widget.videoId}/ownerUid').once();
      _ownerUid = snap.snapshot.value?.toString() ?? '';
    } catch (_) {}
  }

  Future<void> _loadRelatedVideos() async {
    try {
      final recentIds = await WatchHistory.getRecentIds(limit: 5);
      final related = await FirebaseService.getRelatedVideos(
        currentVideoId: widget.videoId,
        currentOwnerUid: _ownerUid,
        recentIds: recentIds,
        limit: 10,
      );
      if (mounted) {
        setState(() {
          _relatedVideos = related;
          _relatedLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _relatedLoading = false);
    }
  }

  Future<void> _loadUserPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isSaved = prefs.getBool('saved_${widget.videoId}') ?? false;
      });
    } catch (_) {}
  }

  Future<void> _initVideo() async {
    final headers = {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      'Referer': 'https://www.mayajaal.online/',
      'Accept': '*/*',
      'Accept-Encoding': 'identity',
      'Connection': 'keep-alive',
    };

    String realVideoUrl = widget.videoUrl;
    final isDirectUrl = widget.videoUrl.contains('.r2.dev') || widget.videoUrl.contains('cloudflarestorage') || widget.videoUrl.contains('.mp4');

    if (!isDirectUrl) {
      try {
        final uri = Uri.parse(widget.sourcePageUrl);
        final token = uri.queryParameters['t'] ?? uri.queryParameters['s'] ?? '';

        final apiResp = await http.get(
          Uri.parse('$kBackendBaseUrl/api/stream-info/${widget.videoId}?t=$token'),
          headers: {'User-Agent': 'MayaJaalApp/1.0'},
        ).timeout(const Duration(seconds: 8));

        if (apiResp.statusCode == 200) {
          final apiData = jsonDecode(apiResp.body);
          if (apiData['success'] == true && apiData['url'] != null) {
            realVideoUrl = apiData['url'];
          }
        }
      } catch (e) {
        debugPrint('⚠️ API fallback: $e');
      }
    }

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(realVideoUrl),
      httpHeaders: headers,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    try {
      await _controller.initialize();
      _controller.play();
      _controller.setPlaybackSpeed(_playbackSpeed);
      _controller.setVolume(_volume);

      _controller.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() => _isInitialized = true);
      _resetControlTimer();
      _startWatchTracking();
    } catch (e) {
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    _likeSub?.cancel();
    _unlikeSub?.cancel();
    _controlsTimer?.cancel();
    _feedbackTimer?.cancel();
    _watchTimer?.cancel();
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _resetControlTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onScreenTapped() {
    Haptic.light();
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetControlTimer();
  }

  void _showFeedback(String text) {
    _feedbackTimer?.cancel();
    setState(() => _flashFeedback = text);
    _feedbackTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _flashFeedback = '');
    });
  }

  void _onLongPressStart() {
    Haptic.light();
    setState(() {
      _isLongPressBoost = true;
      _controller.setPlaybackSpeed(2.0);
    });
    _showFeedback('▶▶ 2x');
  }

  void _onLongPressEnd() {
    if (_isLongPressBoost) {
      _controller.setPlaybackSpeed(_playbackSpeed);
      setState(() => _isLongPressBoost = false);
      _resetControlTimer();
    }
  }

  void _onDoubleTap(TapDownDetails details, double width) {
    final dx = details.localPosition.dx;
    if (dx < width * 0.35) {
      final newPos = _controller.value.position - const Duration(seconds: 10);
      _controller.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
      Haptic.medium();
      _showFeedback('◀◀ 10s');
    } else if (dx > width * 0.65) {
      final newPos = _controller.value.position + const Duration(seconds: 10);
      final maxPos = _controller.value.duration;
      _controller.seekTo(newPos > maxPos ? maxPos : newPos);
      Haptic.medium();
      _showFeedback('10s ▶▶');
    } else {
      setState(() {
        _controller.value.isPlaying ? _controller.pause() : _controller.play();
      });
      Haptic.light();
      _resetControlTimer();
    }
  }

  void _seekRelative(int seconds) {
    Haptic.medium();
    final newPos = _controller.value.position + Duration(seconds: seconds);
    final clamped = newPos < Duration.zero
        ? Duration.zero
        : (newPos > _controller.value.duration ? _controller.value.duration : newPos);
    _controller.seekTo(clamped);
    _showFeedback(seconds > 0 ? '+${seconds}s' : '${seconds}s');
    _resetControlTimer();
  }

  void _toggleSmartFullscreen() {
    Haptic.light();
    setState(() => _isFullscreen = !_isFullscreen);
    
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      final isWide = _controller.value.aspectRatio >= 1.2;
      if (isWide) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours > 0 ? '${d.inHours}:' : '';
    return '$h$m:$s';
  }

  Future<void> _handleLike() async {
    Haptic.medium();
    final uid = MayaJaalAccount.cachedUid;
    if (uid == null) return;
    await FirebaseService.toggleLike(widget.videoId, uid, _ownerUid, widget.title);
  }

  Future<void> _handleDislike() async {
    Haptic.medium();
    final uid = MayaJaalAccount.cachedUid;
    if (uid == null) return;
    await FirebaseService.toggleDislike(widget.videoId, uid);
  }

  Future<void> _shareVideoLink() async {
    Haptic.light();
    await FirebaseService.recordShare(widget.videoId);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF021206),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: kGreen.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('SHARE VIDEO', style: TextStyle(color: kGreen, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 6),
            Text(widget.title, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _shareOption(Icons.link, 'Copy Link', kNeonCyan, () async {
                  Haptic.medium();
                  await Clipboard.setData(ClipboardData(text: widget.sourcePageUrl));
                  if (c.mounted) Navigator.pop(c);
                  _showFeedback('🔗 Link Copied!');
                }),
                _shareOption(Icons.share, 'Share Now', kGreen, () {
                  Haptic.medium();
                  Navigator.pop(c);
                  Share.share('🎬 Watch "${widget.title}" on MayaJaal:\n${widget.sourcePageUrl}');
                }),
                _shareOption(Icons.send_rounded, 'Telegram', const Color(0xFF229ED9), () {
                  Haptic.medium();
                  Navigator.pop(c);
                  Share.share('🎬 Watch "${widget.title}" on MayaJaal:\n${widget.sourcePageUrl}');
                }),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _shareOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle, border: Border.all(color: color, width: 1.5), boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 12)]),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _startInAppDownload() async {
    if (_isDownloading) return;
    Haptic.medium();

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(widget.videoUrl));
      request.headers.set('User-Agent', 'Mozilla/5.0');
      final response = await request.close();

      final totalBytes = response.contentLength;
      int receivedBytes = 0;

      Directory baseDir = Directory('/storage/emulated/0/Download');
      if (!baseDir.existsSync()) baseDir = Directory('/storage/emulated/0/Movies');
      if (!baseDir.existsSync()) baseDir = Directory.systemTemp;

      final safeName = widget.title.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final savePath = '${baseDir.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final file = File(savePath);
      final sink = file.openWrite();

      await response.listen((List<int> chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && mounted) {
          setState(() => _downloadProgress = receivedBytes / totalBytes);
        }
      }).asFuture();

      await sink.flush();
      await sink.close();

      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: kCardBg, content: Text('✅ Video saved to:\n$savePath', style: const TextStyle(color: kGreen, fontSize: 11))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download status: $e')));
      }
    }
  }

  Future<void> _toggleSave() async {
    Haptic.medium();
    final prefs = await SharedPreferences.getInstance();
    final savedStr = prefs.getString('saved_videos_v1');
    List<Map<String, dynamic>> savedList = [];
    if (savedStr != null) {
      try { savedList = (jsonDecode(savedStr) as List).cast<Map<String, dynamic>>(); } catch (_) {}
    }

    setState(() => _isSaved = !_isSaved);

    if (_isSaved) {
      savedList.add({
        'url': widget.sourcePageUrl,
        'title': widget.title,
        'uploader': widget.uploader,
        'id': widget.videoId,
      });
      await prefs.setString('saved_videos_v1', jsonEncode(savedList));
      prefs.setBool('saved_${widget.videoId}', true);
    } else {
      savedList.removeWhere((s) => s['url'] == widget.sourcePageUrl);
      await prefs.setString('saved_videos_v1', jsonEncode(savedList));
      prefs.setBool('saved_${widget.videoId}', false);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isSaved ? 'Video Saved to Favorites' : 'Removed from Favorites'), duration: const Duration(seconds: 1)),
    );
  }

  void _showQualityDialog() {
    Haptic.light();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF031408),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: kGreen, width: 1.5)),
        title: Row(
          children: const [Icon(Icons.hd, color: kGreen, size: 24), SizedBox(width: 8), Text('SELECT QUALITY', style: TextStyle(color: kGreen, fontSize: 15, fontWeight: FontWeight.bold))],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _qualities.map((q) {
            return RadioListTile<String>(
              value: q,
              groupValue: _selectedQuality,
              activeColor: kGreen,
              title: Text(q, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              onChanged: (val) {
                if (val != null) {
                  Haptic.selection();
                  setState(() => _selectedQuality = val);
                  Navigator.pop(c);
                  _showFeedback('Quality: $val');
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showSpeedDialog() {
    Haptic.light();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF031408),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: kGreen, width: 1.5)),
        title: const Text('PLAYBACK SPEED', style: TextStyle(color: kGreen, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _speeds.map((s) {
            return RadioListTile<double>(
              value: s,
              groupValue: _playbackSpeed,
              activeColor: kGreen,
              title: Text('${s}x', style: const TextStyle(color: Colors.white, fontSize: 13)),
              onChanged: (val) {
                if (val != null) {
                  Haptic.selection();
                  setState(() => _playbackSpeed = val);
                  _controller.setPlaybackSpeed(val);
                  Navigator.pop(c);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildScaledVideo() {
    if (_isFullscreen) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }

  void _onVerticalDragStart(DragStartDetails details, double width) {
    _dragStartY = details.localPosition.dy;
    final dx = details.localPosition.dx;
    if (dx > width / 2) {
      _isAdjustingVolume = true;
      _isAdjustingBrightness = false;
      _volumeStart = _volume;
    } else {
      _isAdjustingBrightness = true;
      _isAdjustingVolume = false;
      _brightnessStart = _brightness;
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, double height) {
    final delta = (_dragStartY - details.localPosition.dy) / height;

    if (_isAdjustingVolume) {
      final newVol = (_volumeStart + delta).clamp(0.0, 1.0);
      setState(() => _volume = newVol);
      _controller.setVolume(newVol);
      _showFeedback('🔊 ${(newVol * 100).toInt()}%');
    } else if (_isAdjustingBrightness) {
      final newBright = (_brightnessStart + delta).clamp(0.1, 1.0);
      setState(() => _brightness = newBright);
      _showFeedback('☀️ ${(newBright * 100).toInt()}%');
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _isAdjustingVolume = false;
    _isAdjustingBrightness = false;
    _resetControlTimer();
  }

  Widget _buildWaterFillDownloadButton() {
    return GestureDetector(
      onTap: _isDownloading ? null : _startInAppDownload,
      child: Container(
        width: 108,
        height: 42,
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: kGreen, width: 1.2)),
        child: Stack(
          children: [
            if (_isDownloading)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 42 * _downloadProgress,
                  decoration: BoxDecoration(color: kGreen.withOpacity(0.35), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9))),
                ),
              ),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isDownloading ? Icons.downloading : Icons.download_rounded, color: kGreen, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _isDownloading ? '${(_downloadProgress * 100).toInt()}%' : 'Download',
                    style: const TextStyle(color: kGreen, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return GestureDetector(
              onTap: _onScreenTapped,
              onDoubleTapDown: (d) => _onDoubleTap(d, w),
              onDoubleTap: () {},
              onLongPressStart: (_) => _onLongPressStart(),
              onLongPressEnd: (_) => _onLongPressEnd(),
              onVerticalDragStart: (d) => _onVerticalDragStart(d, w),
              onVerticalDragUpdate: (d) => _onVerticalDragUpdate(d, h),
              onVerticalDragEnd: _onVerticalDragEnd,
              behavior: HitTestBehavior.opaque,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildScaledVideo(),
                  if (_brightness < 1.0)
                    Positioned.fill(child: IgnorePointer(child: Container(color: Colors.black.withOpacity(1.0 - _brightness)))),
                  if (_showControls) ...[
                    Positioned(
                      top: 20,
                      left: 20,
                      child: GestureDetector(
                        onTap: _toggleSmartFullscreen,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                          child: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => _seekRelative(-10),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                            child: const Icon(Icons.replay_10, color: Colors.white, size: 30),
                          ),
                        ),
                        const SizedBox(width: 30),
                        GestureDetector(
                          onTap: () {
                            Haptic.light();
                            setState(() {
                              _controller.value.isPlaying ? _controller.pause() : _controller.play();
                            });
                            _resetControlTimer();
                          },
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                            child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 40),
                          ),
                        ),
                        const SizedBox(width: 30),
                        GestureDetector(
                          onTap: () => _seekRelative(10),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                            child: const Icon(Icons.forward_10, color: Colors.white, size: 30),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Row(
                        children: [
                          Text(_formatDuration(_controller.value.position), style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace')),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(trackHeight: 3, activeTrackColor: kGreen, inactiveTrackColor: Colors.white30, thumbColor: kGreen, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
                              child: Slider(
                                value: _controller.value.position.inSeconds.toDouble().clamp(0.0, _controller.value.duration.inSeconds.toDouble() <= 0 ? 1.0 : _controller.value.duration.inSeconds.toDouble()),
                                min: 0.0,
                                max: _controller.value.duration.inSeconds.toDouble() > 0 ? _controller.value.duration.inSeconds.toDouble() : 1.0,
                                onChanged: (val) => _controller.seekTo(Duration(seconds: val.toInt())),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(_formatDuration(_controller.value.duration), style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                  ],
                  if (_flashFeedback.isNotEmpty)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(10), border: Border.all(color: kGreen, width: 1)),
                        child: Text(_flashFeedback, style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: kGreen, size: 22),
                      onPressed: () {
                        Haptic.light();
                        Navigator.pop(context); // ✅ Goes back to preview (10s page)
                      },
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kGreen, width: 1.5)),
                                child: const Center(child: Icon(Icons.change_history, color: kGreen, size: 14)),
                              ),
                              const SizedBox(width: 8),
                              const Text('MayaJaal', style: TextStyle(color: kGreen, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 1, shadows: [Shadow(color: kGreen, blurRadius: 10)])),
                            ],
                          ),
                          Text('— STREAM BEYOND LIMITS —', style: TextStyle(color: kGreen.withOpacity(0.8), fontSize: 8.5, letterSpacing: 2, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.share, color: kGreen, size: 22), onPressed: _shareVideoLink),
                  ],
                ),
              ),
              Expanded(
                flex: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Container(
                    width: double.infinity,
                    height: 230,
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGreen.withOpacity(0.55), width: 1.5)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: _hasError
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 45),
                                  const SizedBox(height: 10),
                                  const Text('Stream Connection Error', style: TextStyle(color: Colors.redAccent)),
                                  TextButton(onPressed: _initVideo, child: const Text('RETRY', style: TextStyle(color: kGreen))),
                                ],
                              ),
                            )
                          : !_isInitialized
                              ? const ProfessionalLoader(message: 'LOADING PLAYER...')
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final w = constraints.maxWidth;
                                    final h = constraints.maxHeight;
                                    return GestureDetector(
                                      onTap: _onScreenTapped,
                                      onDoubleTapDown: (d) => _onDoubleTap(d, w),
                                      onDoubleTap: () {},
                                      onLongPressStart: (_) => _onLongPressStart(),
                                      onLongPressEnd: (_) => _onLongPressEnd(),
                                      onVerticalDragStart: (d) => _onVerticalDragStart(d, w),
                                      onVerticalDragUpdate: (d) => _onVerticalDragUpdate(d, h),
                                      onVerticalDragEnd: _onVerticalDragEnd,
                                      behavior: HitTestBehavior.opaque,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          _buildScaledVideo(),
                                          if (_brightness < 1.0)
                                            Positioned.fill(child: IgnorePointer(child: Container(color: Colors.black.withOpacity(1.0 - _brightness)))),
                                          Positioned(
                                            top: 10,
                                            left: 10,
                                            child: GestureDetector(
                                              onTap: _showQualityDialog,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(6), border: Border.all(color: kGreen, width: 1)),
                                                child: const Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text('HD', style: TextStyle(color: kGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                                                    Text('1080p', style: TextStyle(color: kGreen, fontSize: 7, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 10,
                                            right: 10,
                                            child: GestureDetector(
                                              onTap: _showSpeedDialog,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(6), border: Border.all(color: kNeonCyan, width: 1)),
                                                child: Text('${_playbackSpeed}x', style: const TextStyle(color: kNeonCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                          ),
                                          if (_showControls && !_isLongPressBoost)
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                GestureDetector(
                                                  onTap: () => _seekRelative(-10),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                                                    child: const Icon(Icons.replay_10, color: Colors.white, size: 26),
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                GestureDetector(
                                                  onTap: () {
                                                    Haptic.light();
                                                    setState(() {
                                                      _controller.value.isPlaying ? _controller.pause() : _controller.play();
                                                    });
                                                    _resetControlTimer();
                                                  },
                                                  child: Container(
                                                    width: 62,
                                                    height: 62,
                                                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                                    child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 36),
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                GestureDetector(
                                                  onTap: () => _seekRelative(10),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                                                    child: const Icon(Icons.forward_10, color: Colors.white, size: 26),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (_flashFeedback.isNotEmpty)
                                            Center(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(10), border: Border.all(color: kGreen, width: 1)),
                                                child: Text(_flashFeedback, style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 18)),
                                              ),
                                            ),
                                          if (_showControls)
                                            Positioned(
                                              bottom: 6,
                                              left: 10,
                                              right: 10,
                                              child: Row(
                                                children: [
                                                  Text(_formatDuration(_controller.value.position), style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace')),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: SliderTheme(
                                                      data: SliderTheme.of(context).copyWith(trackHeight: 2.5, activeTrackColor: kGreen, inactiveTrackColor: Colors.white30, thumbColor: kGreen, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4)),
                                                      child: Slider(
                                                        value: _controller.value.position.inSeconds.toDouble().clamp(0.0, _controller.value.duration.inSeconds.toDouble() <= 0 ? 1.0 : _controller.value.duration.inSeconds.toDouble()),
                                                        min: 0.0,
                                                        max: _controller.value.duration.inSeconds.toDouble() > 0 ? _controller.value.duration.inSeconds.toDouble() : 1.0,
                                                        onChanged: (val) => _controller.seekTo(Duration(seconds: val.toInt())),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(_formatDuration(_controller.value.duration), style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace')),
                                                  const SizedBox(width: 8),
                                                  GestureDetector(
                                                    onTap: _toggleSmartFullscreen,
                                                    child: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 20),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF031408), borderRadius: BorderRadius.circular(16), border: Border.all(color: kGreen.withOpacity(0.55))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.play_circle_fill, color: kGreen, size: 26),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: kGreen)),
                                  child: const Text('HD', style: TextStyle(color: kGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.account_circle, color: kGreen, size: 14),
                                const SizedBox(width: 4),
                                Text('Uploaded by: ${widget.uploader}', style: const TextStyle(color: kGreen, fontSize: 10)),
                                const SizedBox(width: 8),
                                Text('|   👁 ${_stats['views']} views', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: _handleLike,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: _isLiked ? kGreen : kGreen.withOpacity(0.4))),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(_isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined, color: kGreen, size: 14),
                                              const SizedBox(width: 4),
                                              Text('${_stats['likes']}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          const Text('Like', style: TextStyle(color: Colors.white54, fontSize: 9)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: InkWell(
                                    onTap: _handleDislike,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: _isUnliked ? Colors.redAccent : kGreen.withOpacity(0.4))),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(_isUnliked ? Icons.thumb_down : Icons.thumb_down_alt_outlined, color: Colors.redAccent, size: 14),
                                              const SizedBox(width: 4),
                                              Text('${_stats['unlikes']}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          const Text('Dislike', style: TextStyle(color: Colors.white54, fontSize: 9)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: InkWell(
                                    onTap: _toggleSave,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: _isSaved ? kGreen : kGreen.withOpacity(0.4))),
                                      child: Column(
                                        children: [
                                          Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, color: _isSaved ? kGreen : Colors.white, size: 14),
                                          const Text('Save', style: TextStyle(color: Colors.white54, fontSize: 9)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildWaterFillDownloadButton(),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AdBanner(slot: 'player-mid'),
                      const SizedBox(height: 12),
                      Row(
                        children: const [
                          Icon(Icons.play_circle_outline, color: kGreen, size: 18),
                          SizedBox(width: 6),
                          Text('Related Videos', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _relatedLoading
                          ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: kGreen, strokeWidth: 2)))
                          : _relatedVideos.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(color: const Color(0xFF031408), borderRadius: BorderRadius.circular(12), border: Border.all(color: kGreen.withOpacity(0.3))),
                                  child: const Center(child: Text('No related videos yet', style: TextStyle(color: Colors.white54, fontSize: 12))),
                                )
                              : SizedBox(
                                  height: 155,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _relatedVideos.length,
                                    itemBuilder: (context, i) {
                                      final v = _relatedVideos[i];
                                      return _buildRelatedCard(v);
                                    },
                                  ),
                                ),
                      const SizedBox(height: 12),
                      AdBanner(slot: 'player-bottom'),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRelatedCard(Map<String, dynamic> v) {
    final id = v['id']?.toString() ?? '';
    final title = (v['filename'] ?? v['originalUrl'] ?? 'Video').toString();
    final uploader = (v['uploader'] ?? '@mayajaal').toString();
    final views = (v['views'] ?? 0) as int;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: () {
          Haptic.medium();
          final url = '$kBackendBaseUrl/v/$id';
          // ✅ PushReplacement so the back button goes to the original preview screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => StreamPreviewScreen(targetUrl: url),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 175,
          decoration: BoxDecoration(color: const Color(0xFF031408), borderRadius: BorderRadius.circular(12), border: Border.all(color: kGreen.withOpacity(0.35))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  gradient: LinearGradient(
                    colors: [kGreen.withOpacity(0.15), kNeonCyan.withOpacity(0.1), Colors.black],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.6), border: Border.all(color: kGreen, width: 1.5)),
                    child: const Icon(Icons.play_arrow, color: kGreen, size: 22),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: Text(uploader, style: TextStyle(color: kGreen.withOpacity(0.8), fontSize: 9.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const Icon(Icons.visibility, color: Colors.white54, size: 10),
                        const SizedBox(width: 2),
                        Text('$views', style: const TextStyle(color: Colors.white54, fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// WITHDRAW SCREEN
// ═══════════════════════════════════════════════════════
class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});
  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  bool _loading = true;
  double _balance = 0;
  bool _enabled = false;

  final _upiCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _gmailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  @override
  void dispose() {
    _upiCtrl.dispose();
    _bankCtrl.dispose();
    _ifscCtrl.dispose();
    _gmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    try {
      final dash = await MayaJaalAccount.getDashboard();
      final views = (dash['totalViews'] ?? 0) as int;
      final balance = MayaJaalAccount.calcEarnings(views);
      final info = await MayaJaalAccount.getWithdrawalInfo();

      if (mounted) {
        setState(() {
          _balance = balance;
          _enabled = (info['enabled'] ?? false) == true;
          _upiCtrl.text = info['upi']?.toString() ?? '';
          _bankCtrl.text = info['bank_account']?.toString() ?? '';
          _ifscCtrl.text = info['ifsc']?.toString() ?? '';
          _gmailCtrl.text = info['gmail']?.toString() ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveInfo() async {
    Haptic.medium();
    await MayaJaalAccount.saveWithdrawalInfo({
      'upi': _upiCtrl.text.trim(),
      'bank_account': _bankCtrl.text.trim(),
      'ifsc': _ifscCtrl.text.trim().toUpperCase(),
      'gmail': _gmailCtrl.text.trim(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: kCardBg, content: Text('✅ Withdrawal details saved', style: TextStyle(color: kGreen))),
    );
  }

  Future<void> _requestWithdraw() async {
    if (_balance < 5) {
      Haptic.heavy();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: kCardBg, content: Text('❌ Minimum \$5 balance required', style: TextStyle(color: Colors.orangeAccent))),
      );
      return;
    }

    if (!_enabled) {
      Haptic.heavy();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: kCardBg, content: Text('⚠️ Withdrawals coming soon — save your details first', style: TextStyle(color: Colors.orangeAccent))),
      );
      return;
    }

    Haptic.medium();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: kCardBg, content: Text('✅ Withdrawal request submitted', style: TextStyle(color: kGreen))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('WITHDRAW EARNINGS')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(color: const Color(0xFF031408), borderRadius: BorderRadius.circular(16), border: Border.all(color: kGreen, width: 1.5), boxShadow: [BoxShadow(color: kGreen.withOpacity(0.15), blurRadius: 20)]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AVAILABLE BALANCE', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        Text('\$${_balance.toStringAsFixed(2)}', style: const TextStyle(color: kGreen, fontSize: 38, fontWeight: FontWeight.w900, shadows: [Shadow(color: kGreen, blurRadius: 20)])),
                        const SizedBox(height: 4),
                        Text('≈ ₹${(_balance * 80).toStringAsFixed(0)} INR', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: _balance >= 5 ? kGreen.withOpacity(0.15) : Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: _balance >= 5 ? kGreen : Colors.orange, width: 1)),
                          child: Text(
                            _balance >= 5 ? '✅ Minimum reached — Ready to withdraw' : '⚠️ Minimum \$5 to withdraw',
                            style: TextStyle(color: _balance >= 5 ? kGreen : Colors.orange, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('PAYMENT DETAILS', style: TextStyle(color: kGreen, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  const Text('Save your details for faster withdrawals', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 12),
                  _field('UPI ID', _upiCtrl, 'yourname@upi'),
                  const SizedBox(height: 10),
                  _field('Bank Account Number', _bankCtrl, '1234567890'),
                  const SizedBox(height: 10),
                  _field('IFSC Code', _ifscCtrl, 'HDFC0001234'),
                  const SizedBox(height: 10),
                  _field('Gmail', _gmailCtrl, 'yourname@gmail.com'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _saveInfo,
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: kGreen, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('💾 SAVE DETAILS', style: TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _requestWithdraw,
                      style: ElevatedButton.styleFrom(backgroundColor: _balance >= 5 ? kGreen : Colors.grey[850], foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: _balance >= 5 ? 10 : 0),
                      child: Text(
                        _balance >= 5 ? '💸 REQUEST WITHDRAWAL' : 'EARN \$5 TO WITHDRAW',
                        style: TextStyle(color: _balance >= 5 ? Colors.black : Colors.white54, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFF031408), borderRadius: BorderRadius.circular(12), border: Border.all(color: kGreen.withOpacity(0.3))),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [Icon(Icons.info_outline, color: kGreen, size: 16), SizedBox(width: 6), Text('INFO', style: TextStyle(color: kGreen, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2))]),
                        SizedBox(height: 8),
                        Text('• Minimum withdrawal: \$5 (≈₹400)', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                        Text('• Processing time: 24–48 hours', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                        Text('• Methods: UPI · Bank Transfer', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                        Text('• TDS @ 2% applies above ₹15,000/year', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFF031A0B), borderRadius: BorderRadius.circular(12), border: Border.all(color: kGreen.withOpacity(0.4))),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: kGreen.withOpacity(0.8), fontSize: 11, letterSpacing: 1),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// USER SEARCH DELEGATE
// ═══════════════════════════════════════════════════════
class UserSearchDelegate extends SearchDelegate {
  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      inputDecorationTheme: const InputDecorationTheme(hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none),
      textTheme: const TextTheme(titleLarge: TextStyle(color: Colors.white, fontSize: 16)),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear, color: kGreen), onPressed: () => query = ''),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back, color: kGreen),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildSearch();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearch();

  Widget _buildSearch() {
    if (query.trim().isEmpty) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, color: kGreen.withOpacity(0.4), size: 60),
              const SizedBox(height: 12),
              const Text('Search users by name or email', style: TextStyle(color: Colors.white54, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: FirebaseService.searchUsers(query),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kGreen));
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_outlined, color: kGreen.withOpacity(0.4), size: 60),
                  const SizedBox(height: 12),
                  Text('No user found for "$query"', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, i) {
              final u = users[i];
              final name = u['name'] ?? 'User';
              final email = u['email'] ?? '';
              final photo = u['photoURL']?.toString() ?? '';

              return ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kGreen, width: 1.5)),
                  child: photo.isNotEmpty
                      ? ClipOval(child: Image.network(photo, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person, color: kGreen)))
                      : const Icon(Icons.person, color: kGreen),
                ),
                title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: Text(email, style: TextStyle(color: kGreen.withOpacity(0.7), fontSize: 11.5)),
                trailing: const Icon(Icons.arrow_forward_ios, color: kGreen, size: 14),
                onTap: () {
                  Haptic.light();
                  close(context, null);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(channelProfile: u)));
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// USER PROFILE SCREEN
// ═══════════════════════════════════════════════════════
class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> channelProfile;
  const UserProfileScreen({super.key, required this.channelProfile});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isSubscribed = false;
  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;

  String get _channelUid => widget.channelProfile['uid']?.toString() ?? '';
  String get _channelName => widget.channelProfile['name']?.toString() ?? 'User';
  String get _channelEmail => widget.channelProfile['email']?.toString() ?? '';
  String get _channelPhoto => widget.channelProfile['photoURL']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final myUid = MayaJaalAccount.cachedUid;
      if (myUid != null && _channelUid.isNotEmpty) {
        _isSubscribed = await FirebaseService.isSubscribed(myUid, _channelUid);
      }
      _videos = await FirebaseService.getUserVideos(_channelUid, limit: 50);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('Profile load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSub() async {
    Haptic.medium();
    final myUid = MayaJaalAccount.cachedUid;
    if (myUid == null) return;
    final newState = await FirebaseService.toggleSubscription(myUid, _channelUid);
    if (mounted) {
      setState(() => _isSubscribed = newState);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: kCardBg, content: Text(newState ? '✅ Subscribed!' : 'Unsubscribed', style: const TextStyle(color: kGreen)), duration: const Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = MayaJaalAccount.cachedUid == _channelUid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text('@${_channelName.split(' ').first}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kGreen, width: 2), boxShadow: [BoxShadow(color: kGreen.withOpacity(0.4), blurRadius: 20)]),
                  child: _channelPhoto.isNotEmpty
                      ? ClipOval(child: Image.network(_channelPhoto, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person, size: 45, color: kGreen)))
                      : const Icon(Icons.person, size: 45, color: kGreen),
                ),
                const SizedBox(height: 12),
                Text(_channelName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(_channelEmail, style: TextStyle(color: kGreen.withOpacity(0.7), fontSize: 12)),
                const SizedBox(height: 6),
                StreamBuilder<int>(
                  stream: FirebaseService.getSubscriberCount(_channelUid),
                  builder: (c, s) {
                    final count = s.data ?? 0;
                    return Text('$count subscribers', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11));
                  },
                ),
                const SizedBox(height: 16),
                if (!isOwnProfile)
                  SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      onPressed: _toggleSub,
                      style: ElevatedButton.styleFrom(backgroundColor: _isSubscribed ? Colors.grey[850] : kGreen, foregroundColor: _isSubscribed ? Colors.white : Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: Text(_isSubscribed ? '✓ SUBSCRIBED' : '+ SUBSCRIBE', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                  ),
                const Divider(color: Colors.white24, height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.video_library, color: kGreen, size: 18),
                      const SizedBox(width: 6),
                      Text('VIDEOS (${_videos.length})', style: const TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _videos.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.video_library_outlined, color: kGreen.withOpacity(0.4), size: 60),
                              const SizedBox(height: 12),
                              const Text('No uploads yet', style: TextStyle(color: Colors.white54, fontSize: 14)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _videos.length,
                          itemBuilder: (context, i) {
                            final vid = _videos[i];
                            final id = vid['id']?.toString() ?? '';
                            final name = vid['filename'] ?? 'Video';
                            final views = vid['views'] ?? 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGreen.withOpacity(0.3))),
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: kGreen.withOpacity(0.5))),
                                  child: const Icon(Icons.play_circle_fill, color: kGreen, size: 22),
                                ),
                                title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Row(
                                  children: [
                                    const Icon(Icons.visibility, color: kGreen, size: 11),
                                    const SizedBox(width: 3),
                                    Text('$views views', style: TextStyle(color: kGreen.withOpacity(0.8), fontSize: 10.5)),
                                  ],
                                ),
                                onTap: () {
                                  Haptic.light();
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => StreamPreviewScreen(targetUrl: '$kBackendBaseUrl/v/$id')));
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// EARNINGS SCREEN
// ═══════════════════════════════════════════════════════
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  Map<String, dynamic> _dashboard = {};
  List<Map<String, dynamic>> _links = [];
  double _totalIncome = 0;
  int _currentTier = 1;
  double _currentRate = 1.0;
  int _nextBoost = 1000;
  int _rankIndex = 0;

  late AnimationController _rankAnimCtrl;
  late Animation<double> _rankScale;

  @override
  void initState() {
    super.initState();
    _rankAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _rankScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _rankAnimCtrl, curve: Curves.easeOut));
    _loadData();
  }

  @override
  void dispose() {
    _rankAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      if (!MayaJaalAccount.isLoggedIn) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final dash = await MayaJaalAccount.getDashboard();
      final links = await MayaJaalAccount.getUserLinks(limit: 50);

      final views = (dash['totalViews'] ?? 0) as int;
      final income = MayaJaalAccount.calcEarnings(views);
      final tierInfo = MayaJaalAccount.getTierInfo(views);
      final newRankIndex = CyberRank.getIndex(views);

      if (newRankIndex != _rankIndex && _rankIndex != 0) {
        _rankAnimCtrl.forward(from: 0);
      }

      if (mounted) {
        setState(() {
          _dashboard = dash;
          _links = links;
          _totalIncome = income;
          _currentTier = (tierInfo['tier'] ?? 1) as int;
          _currentRate = (tierInfo['rate'] ?? 1.0) as double;
          _nextBoost = (tierInfo['next'] ?? 0) as int;
          _rankIndex = newRankIndex;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Earnings load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('EARNINGS DASHBOARD', style: TextStyle(letterSpacing: 1.5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kGreen),
            onPressed: () {
              Haptic.light();
              setState(() => _loading = true);
              _loadData();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : !MayaJaalAccount.isLoggedIn
              ? _buildNotLoggedIn()
              : _buildDashboard(),
    );
  }

  Widget _buildNotLoggedIn() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_off, color: Colors.orangeAccent, size: 60),
            const SizedBox(height: 16),
            const Text('NOT LOGGED IN', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            const Text('Login karke earnings dekh sakte hain.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final totalViews = (_dashboard['totalViews'] ?? 0) as int;
    final todayViews = (_dashboard['todayViews'] ?? 0) as int;
    final totalLinks = (_dashboard['totalLinks'] ?? 0) as int;
    final rank = CyberRank.get(totalViews);
    final nextRank = CyberRank.next(totalViews);
    final rankColor = rank['color'] as Color;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: kGreen,
      backgroundColor: kCardBg,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGreen.withOpacity(0.5))),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: kGreen, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('LOGGED IN AS', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1.5)),
                        const SizedBox(height: 2),
                        Text(MayaJaalAccount.cachedEmail ?? 'N/A', style: const TextStyle(color: kGreen, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _rankScale,
              builder: (c, child) => Transform.scale(scale: _rankScale.value, child: child),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [rankColor.withOpacity(0.15), Colors.black], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: rankColor.withOpacity(0.5), width: 1.5),
                  boxShadow: [BoxShadow(color: rankColor.withOpacity(0.25), blurRadius: 18)],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: rankColor, width: 2), boxShadow: [BoxShadow(color: rankColor.withOpacity(0.5), blurRadius: 15)]),
                      child: Center(child: Text(rank['emoji'] as String, style: const TextStyle(fontSize: 26))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CYBER RANK', style: TextStyle(color: rankColor, fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 3),
                          Text(rank['name'] as String, style: TextStyle(color: rankColor, fontSize: 18, fontWeight: FontWeight.w900, shadows: [Shadow(color: rankColor.withOpacity(0.6), blurRadius: 12)])),
                          if (nextRank != null)
                            Text('${(nextRank['min'] as int) - totalViews} views to ${nextRank['name']}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: const Color(0xFF031408), borderRadius: BorderRadius.circular(16), border: Border.all(color: kGreen, width: 1.5), boxShadow: [BoxShadow(color: kGreen.withOpacity(0.15), blurRadius: 20)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL BALANCE', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Text('\$${_totalIncome.toStringAsFixed(2)}', style: const TextStyle(color: kGreen, fontSize: 40, fontWeight: FontWeight.w900, shadows: [Shadow(color: kGreen, blurRadius: 20)])),
                  const SizedBox(height: 4),
                  Text('≈ ₹${(_totalIncome * 80).toStringAsFixed(0)} INR', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  const Divider(color: Colors.white24, height: 28),
                  Row(
                    children: [
                      Expanded(child: _statChip('👁 Total Views', '$totalViews')),
                      const SizedBox(width: 8),
                      Expanded(child: _statChip('📅 Today', '$todayViews')),
                      const SizedBox(width: 8),
                      Expanded(child: _statChip('🔗 Links', '$totalLinks')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF031408), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.orangeAccent.withOpacity(0.5))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 20),
                      const SizedBox(width: 8),
                      Text('TIER $_currentTier', style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _tierStat('Current Rate', '\$${_currentRate.toStringAsFixed(2)}/1K')),
                      const SizedBox(width: 8),
                      Expanded(child: _tierStat('Next Boost', '$_nextBoost views')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Rates: 1K = \$1.50 · 2K = \$4.00 · 4K = \$8.00 · 6K = \$12.00 · 8K = \$16.00 · 10K = \$20.00\nAfter 10K: \$2.00 per 1K views', style: TextStyle(color: Colors.white54, fontSize: 10.5)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('YOUR LINKS', style: TextStyle(color: kGreen, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            _links.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGreen.withOpacity(0.3))),
                    child: const Center(child: Text('No links yet. Bot me video upload karke start karein.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12))),
                  )
                : Column(
                    children: _links.map((link) {
                      final views = (link['views'] ?? 0) as int;
                      final earnings = MayaJaalAccount.calcEarnings(views);
                      final name = (link['filename'] ?? link['originalUrl'] ?? 'link').toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGreen.withOpacity(0.3))),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: kGreen.withOpacity(0.5))),
                              child: const Icon(Icons.play_circle_outline, color: kGreen, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(Icons.visibility, color: kGreen, size: 11),
                                      const SizedBox(width: 3),
                                      Text('$views', style: TextStyle(color: kGreen.withOpacity(0.9), fontSize: 10.5, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.attach_money, color: Colors.amberAccent, size: 11),
                                      const SizedBox(width: 2),
                                      Text('\$${earnings.toStringAsFixed(2)}', style: const TextStyle(color: Colors.amberAccent, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF031408), borderRadius: BorderRadius.circular(12), border: Border.all(color: kGreen.withOpacity(0.3))),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(Icons.info_outline, color: kGreen, size: 16), SizedBox(width: 6), Text('WITHDRAWAL INFO', style: TextStyle(color: kGreen, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2))]),
                  SizedBox(height: 8),
                  Text('Minimum: \$5 (≈₹400)', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                  Text('Methods: Bank Transfer · UPI · Any Bank', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                  Text('Processing: 24–48 hours', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: kGreen.withOpacity(0.2))),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9.5), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _tierStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orangeAccent.withOpacity(0.3))),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9.5)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ============ END OF FILE ============
