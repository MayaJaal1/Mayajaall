import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:app_links/app_links.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:better_player/better_player.dart'; 
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
import 'package:crypto/crypto.dart' as crypto;

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIG & NETWORK BASE URLS
// ═══════════════════════════════════════════════════════════════════════════════
const String webClientId = '96139047750-5ooi0pbvch98qu447somuurh6k6fmhcj.apps.googleusercontent.com';
const String oneSignalAppId = '06b99c2b-b3b4-413b-b6cc-480a624f4e25';
const String kBackendBaseUrl = 'https://www.mayajaal.online';
const int kAppCurrentVersionCode = 5;

const List<String> kAllowedEmailDomains = [
  '@gmail.com',
  '@googlemail.com',
];

const int kMinAccountAgeSeconds = 60;
const int kMaxLoginAttempts = 5;
const int kLoginWindowMinutes = 10;
const String _kHmacSecret = 'MJ_HMAC_v1_a7f3b92e_d4c8_11ef_9b8a_00ff_secret_2026';

// ═══════════════════════════════════════════════════════════════════════════════
// PROFESSIONAL THEME PALETTES
// ═══════════════════════════════════════════════════════════════════════════════
class AppThemes {
  static const Color kGreen = Color(0xFF00E676);
  static const Color kNeonCyan = Color(0xFF00E5FF);
  static const Color kNeonPurple = Color(0xFFB388FF);
  static const Color kBg = Color(0xFF070A08);
  static const Color kCardBg = Color(0xFF0E1511);
  static const Color kBorder = Color(0xFF1B281F);
  static const Color kDimGreen = Color(0xFF69F0AE);
  static const Color kGold = Color(0xFFFFD54F);
  static const Color kSilver = Color(0xFFCFD8DC);
  static const Color kBronze = Color(0xFFFFAB91);
  static const Color kRed = Color(0xFFFF5252);
  static const Color kFireOrange = Color(0xFFFF6D00);
  static const Color kFireYellow = Color(0xFFFFD600);
}

final ValueNotifier<String> themeNotifier = ValueNotifier<String>('Cyber Emerald');
final ValueNotifier<String> languageNotifier = ValueNotifier<String>('English');
final ValueNotifier<bool> soundEnabledNotifier = ValueNotifier<bool>(true);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ═══════════════════════════════════════════════════════════════════════════════
// AUDIO FEEDBACK CONTROLLER
// ═══════════════════════════════════════════════════════════════════════════════
class SoundService {
  static void playClick() {
    if (soundEnabledNotifier.value) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  static void playAlert() {
    if (soundEnabledNotifier.value) {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.alert);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INSTANT AUTO-GENERATED THUMBNAIL
// ═══════════════════════════════════════════════════════════════════════════════
Widget buildAutoThumbnail(String title, {bool isSmall = false}) {
  return RepaintBoundary(
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black,
            AppThemes.kCardBg,
            AppThemes.kBorder.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppThemes.kBorder),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 4,
            left: 6,
            right: 6,
            child: Text(
              'MAYAJAAL',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: isSmall ? 6 : 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Container(
            width: isSmall ? 22 : 44,
            height: isSmall ? 22 : 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.7),
              border: Border.all(color: AppThemes.kGreen.withOpacity(0.8), width: 1.2),
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: AppThemes.kGreen,
              size: isSmall ? 15 : 26,
            ),
          ),
          Positioned(
            left: 6,
            bottom: 4,
            right: 6,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: isSmall ? 7.5 : 10.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// INSTANT LOOPING VIDEO THUMBNAIL
// ═══════════════════════════════════════════════════════════════════════════════
class VideoLoopThumbnail extends StatefulWidget {
  final String videoUrl;
  final String title;
  final bool isSmall;
  final String? fallbackThumb;
  final void Function(String base64Thumb)? onFrameCaptured;

  const VideoLoopThumbnail({
    super.key,
    required this.videoUrl,
    required this.title,
    this.isSmall = false,
    this.fallbackThumb,
    this.onFrameCaptured,
  });

  @override
  State<VideoLoopThumbnail> createState() => _VideoLoopThumbnailState();
}

class _VideoLoopThumbnailState extends State<VideoLoopThumbnail> {
  VideoPlayerController? _controller;
  bool _isInit = false;
  bool _firstFrameReady = false;
  bool _hasError = false;
  final GlobalKey _captureKey = GlobalKey();
  bool _captureAttempted = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant VideoLoopThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl && widget.videoUrl.isNotEmpty) {
      _controller?.dispose();
      _controller = null;
      _isInit = false;
      _firstFrameReady = false;
      _captureAttempted = false;
      _hasError = false;
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    if (widget.videoUrl.isEmpty || !widget.videoUrl.startsWith('http')) return;

    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
          'Accept': '*/*',
        },
      );

      await _controller!.initialize();
      if (!mounted) return;

      _controller!.setVolume(0);
      _controller!.play();
      _controller!.addListener(_onVideoUpdate);

      if (mounted) setState(() => _isInit = true);
      _attemptFrameCapture();
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onVideoUpdate() {
    if (!mounted || _controller == null) return;
    final val = _controller!.value;
    if (!val.isInitialized) return;

    if (!_firstFrameReady && val.position > Duration.zero) {
      setState(() => _firstFrameReady = true);
    }

    if (val.position.inMilliseconds >= 4000) {
      _controller!.seekTo(Duration.zero);
    }
  }

  Future<void> _attemptFrameCapture() async {
    if (_captureAttempted || widget.onFrameCaptured == null) return;
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted || _captureAttempted || !_firstFrameReady) return;
    _captureAttempted = true;

    try {
      final ctx = _captureKey.currentContext;
      if (ctx == null) return;
      final boundary = ctx.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return;
      final image = await boundary.toImage(pixelRatio: 0.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final b64 = base64Encode(byteData.buffer.asUint8List());
      if (mounted) widget.onFrameCaptured!(b64);
    } catch (_) {}
  }

  Widget _buildFallback() {
    if (widget.fallbackThumb != null && widget.fallbackThumb!.isNotEmpty) {
      if (widget.fallbackThumb!.startsWith('http')) {
        return Image.network(
          widget.fallbackThumb!,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => buildAutoThumbnail(widget.title, isSmall: widget.isSmall),
        );
      }
      try {
        return Image.memory(
          base64Decode(widget.fallbackThumb!),
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => buildAutoThumbnail(widget.title, isSmall: widget.isSmall),
        );
      } catch (_) {}
    }
    return buildAutoThumbnail(widget.title, isSmall: widget.isSmall);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || (!_isInit && _controller == null)) {
      return _buildFallback();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_isInit && _controller != null)
          RepaintBoundary(
            key: _captureKey,
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
          ),
        if (!_firstFrameReady) _buildFallback(),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GLOBAL MEDIA THUMBNAIL DISPATCHER
// ═══════════════════════════════════════════════════════════════════════════════
Widget buildMediaThumbnail(
  String? thumb,
  String title,
  String videoUrl, {
  bool isSmall = false,
  void Function(String base64Thumb)? onFrameCaptured,
}) {
  if (thumb != null && thumb.isNotEmpty) {
    if (thumb.startsWith('http')) {
      return Image.network(
        thumb,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => buildAutoThumbnail(title, isSmall: isSmall),
      );
    }
    try {
      return Image.memory(
        base64Decode(thumb),
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => buildAutoThumbnail(title, isSmall: isSmall),
      );
    } catch (_) {}
  }

  if (videoUrl.isNotEmpty && videoUrl.startsWith('http')) {
    return VideoLoopThumbnail(
      videoUrl: videoUrl,
      title: title,
      isSmall: isSmall,
      fallbackThumb: thumb,
      onFrameCaptured: onFrameCaptured,
    );
  }

  return buildAutoThumbnail(title, isSmall: isSmall);
}

// ═══════════════════════════════════════════════════════════════════════════════
// 🆕 TERABOX API RESOLVER (With Cookie Support)
// ═══════════════════════════════════════════════════════════════════════════════
class TeraBoxResolver {
  static const String kTeraBoxCookie = 'ndus=YT1H4hKteHuiuwBbODNsOHsnYlv2Wgkc7WzceDwG';

  static bool isTeraBoxLink(String url) {
    final lower = url.toLowerCase();
    return lower.contains('terabox.com') ||
        lower.contains('1024terabox.com') ||
        lower.contains('freeterabox.com') ||
        lower.contains('teraboxapp.com') ||
        lower.contains('terabox.club') ||
        lower.contains('terabox.link');
  }

  static Future<Map<String, String>> resolve(String teraboxUrl) async {
    try {
      final apiUrl = 'https://terabox-worker.robinkumarshakya103.workers.dev/api?url=${Uri.encodeComponent(teraboxUrl)}';
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
          'Cookie': kTeraBoxCookie, 
          'Referer': 'https://www.terabox.com/',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['files'] != null && data['files'].isNotEmpty) {
          final file = data['files'][0];
          
          // Video URL nikalne ka sahi tarika
          final videoUrl = file['streaming_url'] ?? file['download_url'] ?? file['url'] ?? '';
          
          // 🔥 FILE NAME NIKALNE KA SAHI TARIKA 🔥
          String fileName = '';
          if (file['file_name'] != null && file['file_name'].toString().trim().isNotEmpty) {
            fileName = file['file_name'].toString().trim();
          } else if (file['filename'] != null && file['filename'].toString().trim().isNotEmpty) {
            fileName = file['filename'].toString().trim();
          } else if (file['name'] != null && file['name'].toString().trim().isNotEmpty) {
            fileName = file['name'].toString().trim();
          } else {
            // Agar API se naam nahi mila, toh URL se nikalne ki koshish karein
            try {
              final uri = Uri.parse(videoUrl);
              final lastSegment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
              if (lastSegment.contains('.')) {
                fileName = Uri.decodeComponent(lastSegment);
              }
            } catch (_) {}
          }

          final thumbnail = file['thumbnail'] ?? file['thumb'] ?? '';

          if (videoUrl.isNotEmpty) {
            return {
              'success': 'true',
              'videoUrl': videoUrl,
              'fileName': fileName.isNotEmpty ? fileName : 'TeraBox Video', // Fallback
              'thumbnail': thumbnail,
            };
          }
        }
      }
    } catch (e) {
      debugPrint('TeraBox Resolver Error: $e');
    }
    return {'success': 'false', 'videoUrl': '', 'fileName': '', 'thumbnail': ''};
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REAL VIDEO NAME RESOLVER — FIREBASE RTDB BACKUP
// ═══════════════════════════════════════════════════════════════════════════════
class VideoNameResolver {
  static Future<String> resolve(String videoId) async {
    if (videoId.isEmpty) return '';
    try {
      final snap = await FirebaseDatabase.instance.ref('links/$videoId').once();
      final val = snap.snapshot.value;
      if (val == null || val is! Map) return '';
      final data = Map<String, dynamic>.from(val);

      final candidates = [
        (data['filename'] ?? '').toString().trim(),
        (data['title'] ?? '').toString().trim(),
        (data['file_name'] ?? '').toString().trim(),
      ];

      for (final c in candidates) {
        if (c.isNotEmpty && c.toLowerCase() != 'null' && c != videoId) {
          return c;
        }
      }

      final origUrl = (data['originalUrl'] ?? '').toString();
      if (origUrl.isNotEmpty) {
        try {
          final u = Uri.parse(origUrl);
          final last = u.pathSegments.isNotEmpty ? u.pathSegments.last : '';
          if (last.isNotEmpty) return Uri.decodeComponent(last);
        } catch (_) {}
      }
    } catch (_) {}
    return '';
  }

  static bool isBadTitle(String title, String videoId) {
    final t = title.trim();
    return t.isEmpty ||
        t.toLowerCase() == 'null' ||
        t == videoId ||
        t.toLowerCase() == 'mayajaal video';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REAL UPLOADER NAME RESOLVER
// ═══════════════════════════════════════════════════════════════════════════════
class VideoOwnerResolver {
  static Future<Map<String, String>> resolve(String videoId) async {
    if (videoId.isEmpty) return {};
    try {
      final snap = await FirebaseDatabase.instance.ref('links/$videoId').once();
      final val = snap.snapshot.value;
      if (val == null || val is! Map) return {};
      final data = Map<String, dynamic>.from(val);

      String uploader = (data['uploader'] ?? '').toString().trim();
      String ownerUid = (data['ownerUid'] ?? '').toString().trim();
      String ownerName = '';

      if (ownerUid.isNotEmpty) {
        try {
          final uSnap = await FirebaseDatabase.instance.ref('users/$ownerUid').once();
          if (uSnap.snapshot.value != null && uSnap.snapshot.value is Map) {
            final u = Map<String, dynamic>.from(uSnap.snapshot.value as Map);
            final n = (u['name'] ?? '').toString().trim();
            final e = (u['email'] ?? '').toString().trim();
            if (n.isNotEmpty && n.toLowerCase() != 'null' && n.toLowerCase() != 'user') {
              ownerName = n;
            } else if (e.isNotEmpty) {
              ownerName = e.split('@').first;
            }
          }
        } catch (_) {}
      }

      if (ownerName.isEmpty && uploader.isNotEmpty && uploader.toLowerCase() != 'mayajaal' && uploader.toLowerCase() != 'null') {
        ownerName = uploader.replaceAll('@', '').trim();
      }

      final display = ownerName.isNotEmpty
          ? (ownerName.startsWith('@') ? ownerName : '@$ownerName')
          : '@mayajaal';

      return {
        'display': display,
        'name': ownerName,
        'uid': ownerUid,
      };
    } catch (_) {}
    return {};
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEVICE ID HELPER
// ═══════════════════════════════════════════════════════════════════════════════
class DeviceIdHelper {
  static String? _cached;
  static String? _cachedHash;

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
      await prefs.setString('mj_device_id', stored);
      _cached = stored;
      return stored;
    } catch (_) {
      _cached = 'dev-${DateTime.now().millisecondsSinceEpoch}';
      return _cached!;
    }
  }

  static Future<String> getHash() async {
    if (_cachedHash != null) return _cachedHash!;
    try {
      final raw = await get();
      final digest = crypto.sha256.convert(utf8.encode('mj_salt_2026_$raw'));
      _cachedHash = digest.toString().substring(0, 24);
      return _cachedHash!;
    } catch (_) {
      return 'unknown';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// IN-APP LEGAL & POLICY DIALOG
// ═══════════════════════════════════════════════════════════════════════════════
class LegalPolicyDialog {
  static void showPolicy(BuildContext context, String type) {
    SoundService.playClick();
    String title = '';
    String subtitle = '';
    Color accentColor = AppThemes.kGreen;
    List<Widget> sections = [];

    switch (type) {
      case 'privacy':
        title = 'PRIVACY POLICY';
        subtitle = 'Effective Date: October 2026 | Cloud Edge & Streaming Network';
        accentColor = AppThemes.kGreen;
        sections = [
          _buildSection('Introduction',
            'Thank you for choosing MayaJaal ("Platform", "App", "we", "us"). This Privacy Policy is engineered to help you understand how we collect, process, utilize, disclose, and safeguard your personal data and technical telemetry when accessing our web dashboard, Android streaming application, Cloudflare R2 media caches, and official Telegram automation bots (@Mayajaalfilebot, @MayaJaalBulkConverterbot, @MayaJaalExpiryBot). By creating an account or using the platform, you agree to the terms outlined herein.'),
          // ... Baaki sections (No changes)
        ];
        break;

      case 'terms':
        title = 'TERMS & CONDITIONS';
        subtitle = 'Effective Date: October 2026 | Operating Governance & User Agreement';
        accentColor = AppThemes.kGreen;
        sections = [
          _buildSection('Introduction',
            'By creating an account, accessing the MayaJaal web dashboard, utilizing our Telegram automation suite (@Mayajaalfilebot, @MayaJaalBulkConverterbot, @MayaJaalExpiryBot), or downloading the official MayaJaal Android Streaming APK, you acknowledge that you have read, understood, and agreed to be legally bound by these Terms and Conditions.'),
          // ... Baaki sections (No changes)
        ];
        break;

      case 'dmca':
        title = 'DMCA & COPYRIGHT POLICY';
        subtitle = 'Online Service Provider Notification & Takedown Framework | Title II 17 U.S.C. § 512';
        accentColor = const Color(0xFFFB7185);
        sections = [
          _buildSection('Introduction',
            'MayaJaal ("Platform", "we", "us") functions as an intermediary and online content routing provider under Title II of the Digital Millennium Copyright Act, 17 U.S.C. Section 512 ("DMCA"). This document formalizes the statutory notice-and-takedown procedures established by MayaJaal to enforce the intellectual property rights of copyright holders, as well as counter-notification protocols for restoring mistakenly disabled streams.\n\nWe strictly comply with prevailing standards under international intellectual property frameworks. MayaJaal accommodates and does not interfere with standard technical protection measures deployed by rights holders, and maintains an active procedure for disabling access to or permanently removing media assets confirmed to infringe third-party copyrights.'),
          // ... Baaki sections (No changes)
        ];
        break;

      case 'partner':
        title = 'CREATOR PROGRAM TERMS';
        subtitle = 'Effective Date: October 2026 | Creator Engagement & Anti-Fraud Governance';
        accentColor = AppThemes.kNeonCyan;
        sections = [
          _buildSection('Introduction',
            'This Agreement governs creator platform engagement, traffic integrity, creator ranking systems, and content sharing practices across the MayaJaal network. Compliance with these security and anti-abuse protocols is strictly mandatory for all creators.'),
          // ... Baaki sections (No changes)
        ];
        break;

      case 'support':
        title = 'HELP & SUPPORT';
        subtitle = 'For platform troubleshooting, Telegram bot configurations, link renewal assistance, or account recovery, reach out through our official channels:';
        accentColor = AppThemes.kGold;
        sections = [
          _buildSection('Official Compliance Email',
            'mayajaalsupport@gmail.com\n\nDirect verified response desk.'),
          _buildSection('Telegram Official Helpdesk',
            '@MayaJaalSupport\n\nInstant support bot and agent channel.'),
          _buildSection('Official Instagram Desk',
            '@maya_jaal_official\n\nUpdates and creator announcements.'),
          _buildSection('Response Times',
            'Automated bots operate 24/7. Support inquiries are reviewed and resolved within 12–24 business hours.'),
        ];
        break;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppThemes.kBg,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: accentColor.withOpacity(0.4), width: 1.2),
      ),
      builder: (c) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.55,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: accentColor.withOpacity(0.5)),
                    ),
                    child: Icon(Icons.verified_user_rounded, color: accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: accentColor.withOpacity(0.2), height: 1),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    ...sections,
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Center(
                        child: Text(
                          '© 2026 MayaJaal Network. All Rights Reserved.',
                          style: TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    SoundService.playClick();
                    Navigator.pop(c);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'CLOSE',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildSection(String heading, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemes.kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemes.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 11.5,
              height: 1.5,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MULTI-LANGUAGE TRANSLATION MATRIX
// ═══════════════════════════════════════════════════════════════════════════════
final Map<String, Map<String, String>> localizedStrings = {
  'English': {
    'app_title': 'MAYA JAAL',
    'paste_hint': 'Paste Stream URL',
    'watch_history': '> WATCH HISTORY',
    'no_history': 'No history yet',
    'settings': 'SETTINGS',
    'dark_theme': 'Theme Style',
    'language': 'Language',
    'download_location': 'Download Location',
    'clear_history': 'Clear History',
    'logout': 'Logout',
    'uploader': 'UPLOADER',
    'filename': 'FILE NAME',
    'sound_effects': 'In-App Sound Effects',
    'save_changes': 'Save Settings',
  },
  'Hindi': {
    'app_title': 'माया जाल',
    'paste_hint': 'यहाँ लिंक पेस्ट करें...',
    'watch_history': '> देखने का इतिहास',
    'no_history': 'अभी कोई इतिहास नहीं है',
    'settings': 'सेटिंग्स',
    'dark_theme': 'थीम का प्रकार',
    'language': 'भाषा (Language)',
    'download_location': 'डाउनलोड स्थान',
    'clear_history': 'इतिहास साफ़ करें',
    'logout': 'लॉग आउट',
    'uploader': 'अपलोडर',
    'filename': 'फ़ाइल का नाम',
    'sound_effects': 'ऐप साउंड इफ़ेक्ट्स',
    'save_changes': 'सेटिंग्स सुरक्षित करें',
  },
  'Bengali': {
    'app_title': 'মায়াজাল',
    'paste_hint': 'স্ট্রিম লিংক পেস্ট করুন...',
    'watch_history': '> দেখার ইতিহাস',
    'no_history': 'এখনো কোনো ইতিহাস নেই',
    'settings': 'সেটিংস',
    'dark_theme': 'থিমের ধরন',
    'language': 'ভাষা (Language)',
    'download_location': 'ডাউনলোড লোকেশন',
    'clear_history': 'ইতিহাস মুছুন',
    'logout': 'লগআউট',
    'uploader': 'আপলোডার',
    'filename': 'ফাইলের নাম',
    'sound_effects': 'অ্যাপ সাউন্ড ইফেক্ট',
    'save_changes': 'সংরক্ষণ করুন',
  },
  'Tamil': {
    'app_title': 'மாயாஜால்',
    'paste_hint': 'ஸ்ட்ரீம் இணைப்பை ஒட்டவும்...',
    'watch_history': '> பார்வை வரலாறு',
    'no_history': 'வரலாறு இல்லை',
    'settings': 'அமைப்புகள்',
    'dark_theme': 'தீம் தேர்வு',
    'language': 'மொழி (Language)',
    'download_location': 'பதிவிறக்க இடம்',
    'clear_history': 'வரலாற்றை அழி',
    'logout': 'வெளியேறு',
    'uploader': 'பதிவேற்றியவர்',
    'filename': 'கோப்பு பெயர்',
    'sound_effects': 'ஒலி விளைவுகள்',
    'save_changes': 'சேமிக்க',
  },
  'Telugu': {
    'app_title': 'మాయాజాల్',
    'paste_hint': 'లింక్ ఇక్కడ పేస్ట్ చేయండి...',
    'watch_history': '> వీక్షణ చరిత్ర',
    'no_history': 'చరిత్ర లేదు',
    'settings': 'సెట్టింగులు',
    'dark_theme': 'థీమ్ మోడ్',
    'language': 'భాష (Language)',
    'download_location': 'డౌన్‌లోడ్ లొకేషన్',
    'clear_history': 'చరిత్ర క్లియర్ చేయండి',
    'logout': 'లాగౌట్',
    'uploader': 'అప్‌లోడర్',
    'filename': 'ఫైల్ పేరు',
    'sound_effects': 'సౌండ్ ఎఫెక్ట్స్',
    'save_changes': 'మార్పులను సేవ్ చేయండి',
  },
};

String tr(String key) {
  final lang = languageNotifier.value;
  return localizedStrings[lang]?[key] ?? localizedStrings['English']?[key] ?? key;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HAPTIC FEEDBACK CONTROLLER
// ═══════════════════════════════════════════════════════════════════════════════
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

// ═══════════════════════════════════════════════════════════════════════════════
// SECURITY GUARD & AUTHENTICATION PROTOCOLS
// ═══════════════════════════════════════════════════════════════════════════════
class SecurityGuard {
  static bool isGmailOnly(String? email) {
    if (email == null || email.isEmpty) return false;
    final lower = email.trim().toLowerCase();
    return kAllowedEmailDomains.any((d) => lower.endsWith(d));
  }

  static bool isGoogleProvider(User user) {
    return user.providerData.any((p) => p.providerId == 'google.com');
  }

  static bool isEmailVerified(User user) {
    return user.emailVerified == true;
  }

  static bool isAccountOldEnough(User user, {int seconds = kMinAccountAgeSeconds}) {
    final created = user.metadata.creationTime;
    if (created == null) return false;
    return DateTime.now().difference(created).inSeconds >= seconds;
  }

  static Future<String?> validateUser(User user) async {
    if (!isGoogleProvider(user)) {
      return 'Only Google sign-in is allowed.';
    }
    if (!isGmailOnly(user.email)) {
      return 'Only @gmail.com accounts are supported.';
    }
    if (!isEmailVerified(user)) {
      return 'Your Gmail is not verified by Google. Please verify and retry.';
    }
    if (!isAccountOldEnough(user)) {
      return 'This account is too new. Please wait a minute and try again.';
    }
    try {
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        return 'Session token invalid. Please re-login.';
      }
    } catch (_) {
      return 'Session validation failed. Please retry.';
    }
    return null;
  }

  static Future<Map<String, dynamic>> validateAndBindDevice(
    String uid,
    String email,
  ) async {
    try {
      final deviceId = await DeviceIdHelper.get();
      final ref = FirebaseDatabase.instance.ref('deviceBindings/$deviceId');
      final snap = await ref.once();
      final data = snap.snapshot.value as Map?;

      if (data == null) {
        await ref.set({
          'uid': uid,
          'email': email,
          'boundAt': DateTime.now().millisecondsSinceEpoch,
        });
        return {'ok': true, 'firstBind': true};
      }

      final existingUid = data['uid']?.toString() ?? '';
      if (existingUid == uid) {
        await ref.update({
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        });
        return {'ok': true, 'firstBind': false};
      }

      await ref.update({
        'uid': uid,
        'email': email,
        'reboundAt': DateTime.now().millisecondsSinceEpoch,
        'previousUid': existingUid,
      });
      debugPrint('ℹ️ Device rebound from $existingUid to $uid (allowed)');
      return {'ok': true, 'firstBind': false, 'rebound': true};
    } catch (e) {
      debugPrint('Device bind error: $e');
      return {'ok': true, 'warning': 'binding_skipped'};
    }
  }

  static Future<Map<String, dynamic>> detectRootOrEmulator() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        final isEmulator =
            a.model.toLowerCase().contains('sdk') ||
            a.model.toLowerCase().contains('emulator') ||
            a.model.toLowerCase().contains('android sdk built for') ||
            a.manufacturer.toLowerCase().contains('genymotion') ||
            a.manufacturer.toLowerCase().contains('unknown') ||
            a.product.toLowerCase().contains('sdk') ||
            a.hardware.toLowerCase().contains('goldfish') ||
            a.hardware.toLowerCase().contains('ranchu');

        bool rooted = false;
        try {
          final suPaths = [
            '/system/app/Superuser.apk',
            '/sbin/su',
            '/system/bin/su',
            '/system/xbin/su',
            '/data/local/xbin/su',
            '/data/local/bin/su',
            '/system/sd/xbin/su',
            '/system/bin/failsafe/su',
            '/data/local/su',
            '/su/bin/su',
          ];
          for (final p in suPaths) {
            if (File(p).existsSync()) { rooted = true; break; }
          }
        } catch (_) {}

        return {
          'emulator': isEmulator,
          'rooted': rooted,
          'isPhysical': a.isPhysicalDevice,
          'brand': a.brand,
          'model': a.model,
          'sdk': a.version.sdkInt,
        };
      }
      if (Platform.isIOS) {
        final i = await info.iosInfo;
        final isJailbroken = i.isPhysicalDevice == false;
        return {
          'emulator': isJailbroken,
          'rooted': isJailbroken,
          'isPhysical': i.isPhysicalDevice,
          'brand': 'Apple',
          'model': i.utsname.machine,
        };
      }
    } catch (e) {
      debugPrint('device detect err: $e');
    }
    return {'emulator': false, 'rooted': false, 'isPhysical': true};
  }

  static Future<bool> isPackageIntact() async {
    return true;
  }

  static Future<bool> checkLoginRateLimit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final windowMs = kLoginWindowMinutes * 60 * 1000;
      final raw = prefs.getString('mj_login_attempts');
      List<int> attempts = [];
      if (raw != null) {
        attempts = (jsonDecode(raw) as List).map((e) => (e as num).toInt()).toList();
      }
      attempts = attempts.where((t) => now - t < windowMs).toList();
      if (attempts.length >= kMaxLoginAttempts) return false;
      return true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> recordLoginAttempt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final raw = prefs.getString('mj_login_attempts');
      List<int> attempts = [];
      if (raw != null) {
        attempts = (jsonDecode(raw) as List).map((e) => (e as num).toInt()).toList();
      }
      attempts.add(now);
      final windowMs = kLoginWindowMinutes * 60 * 1000;
      attempts = attempts.where((t) => now - t < windowMs).toList();
      await prefs.setString('mj_login_attempts', jsonEncode(attempts));
    } catch (_) {}
  }

  static Future<void> clearLoginAttempts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('mj_login_attempts');
    } catch (_) {}
  }

  static String signRequest(String method, String path, String body) {
    final payload = '$method\n$path\n$body';
    final hmac = crypto.Hmac(crypto.sha256, utf8.encode(_kHmacSecret));
    final digest = hmac.convert(utf8.encode(payload));
    return digest.toString();
  }

  static Map<String, String> signedHeaders({
    required String method,
    required String path,
    required String body,
    required String deviceId,
    String? uid,
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final sig = signRequest(method, path, '$ts.$body');
    return {
      'Content-Type': 'application/json',
      'X-MJ-Timestamp': ts,
      'X-MJ-Device': deviceId,
      'X-MJ-Uid': uid ?? '',
      'X-MJ-Signature': sig,
    };
  }

  static Future<bool> validateSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    if (!isGmailOnly(user.email)) return false;
    if (!isEmailVerified(user)) return false;
    if (!isGoogleProvider(user)) return false;
    try {
      await user.reload();
      final fresh = FirebaseAuth.instance.currentUser;
      if (fresh == null) return false;
      final token = await fresh.getIdToken(false);
      if (token == null || token.isEmpty) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> fullGate(User user) async {
    final userErr = await validateUser(user);
    if (userErr != null) return userErr;

    final device = await detectRootOrEmulator();
    if (device['emulator'] == true) {
      debugPrint('⚠️ Emulator detected (logged, not blocked): ${device['model']}');
    }
    if (device['rooted'] == true) {
      debugPrint('⚠️ Rooted device detected (logged, not blocked)');
    }

    await validateAndBindDevice(user.uid, user.email ?? '');

    final sessOk = await validateSession();
    if (!sessOk) return 'Session invalid. Please login again.';

    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CYBER RANK TIERS
// ═══════════════════════════════════════════════════════════════════════════════
class CyberRank {
  static const List<Map<String, dynamic>> ranks = [
    {'name': 'Neon Rookie', 'emoji': '🥉', 'color': AppThemes.kSilver, 'min': 0},
    {'name': 'Cyber Trader', 'emoji': '🥈', 'color': AppThemes.kNeonCyan, 'min': 1000},
    {'name': 'Matrix Master', 'emoji': '🥇', 'color': AppThemes.kGreen, 'min': 10000},
    {'name': 'Quantum Elite', 'emoji': '💎', 'color': AppThemes.kNeonPurple, 'min': 100000},
    {'name': 'MayaJaal Legend', 'emoji': '👑', 'color': AppThemes.kGold, 'min': 1000000},
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

// ═══════════════════════════════════════════════════════════════════════════════
// MAYAJAAL ACCOUNT SERVICE (NO WITHDRAWAL · PLAY STORE SAFE · ACCOUNT DELETION)
// ═══════════════════════════════════════════════════════════════════════════════
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
      final err = await SecurityGuard.validateUser(user);
      if (err != null) {
        debugPrint('🚫 init rejected: $err');
        await signOut();
        return;
      }
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
      if (!SecurityGuard.isGmailOnly(user.email)) return;
      final ref = _rtdb.child('users/${user.uid}');
      final snap = await ref.once();
      final data = snap.snapshot.value as Map?;

      final updates = <String, dynamic>{
        'email': (user.email ?? '').toLowerCase(),
        'name': user.displayName ?? 'User',
        'photoURL': user.photoURL ?? '',
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
        'emailVerified': user.emailVerified,
        'provider': 'google.com',
        'deviceHash': await DeviceIdHelper.getHash(),
      };

      if (data == null) {
        updates['createdAt'] = DateTime.now().millisecondsSinceEpoch;
        updates['subscribersCount'] = 0;
        updates['dashboard'] = {
          'totalLinks': 0,
          'totalViews': 0,
          'todayViews': 0,
          'viewsByDay': {},
          'linksByDay': {},
        };
      }

      await ref.update(updates);
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

      if (key == null || key.length < 20) {
        key = _generateKey();
        await ref.set(key);
      }
      cachedApiKey = key;
      return key;
    } catch (e) {
      debugPrint('API key load error: $e');
      return '';
    }
  }

  static String _generateKey() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = math.Random.secure();
    return List.generate(24, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static Future<UserCredential?> signInWithGoogle() async {
    final allowed = await SecurityGuard.checkLoginRateLimit();
    if (!allowed) {
      throw FirebaseAuthException(
        code: 'too-many-requests',
        message: 'Too many login attempts. Try again in 10 minutes.',
      );
    }
    await SecurityGuard.recordLoginAttempt();

    final googleSignIn = GoogleSignIn(serverClientId: webClientId);
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null;

    if (!SecurityGuard.isGmailOnly(googleUser.email)) {
      await googleSignIn.signOut();
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Only @gmail.com accounts are allowed.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );
    final result = await FirebaseAuth.instance.signInWithCredential(credential);

    final user = result.user;
    if (user == null) throw FirebaseAuthException(code: 'unknown', message: 'No user returned.');

    final err = await SecurityGuard.validateUser(user);
    if (err != null) {
      await FirebaseAuth.instance.signOut();
      await googleSignIn.signOut();
      throw FirebaseAuthException(code: 'invalid-credential', message: err);
    }

    await SecurityGuard.validateAndBindDevice(user.uid, user.email ?? '');
    await SecurityGuard.clearLoginAttempts();
    return result;
  }

  static Future<void> signOut() async {
    try {
      final googleSignIn = GoogleSignIn(serverClientId: webClientId);
      try { await googleSignIn.signOut(); } catch (_) {}
      try { await googleSignIn.disconnect(); } catch (_) {}
    } catch (_) {}

    try { await FirebaseAuth.instance.signOut(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 100));

    cachedUid = null;
    cachedEmail = null;
    cachedName = null;
    cachedPhoto = null;
    cachedApiKey = null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DEEP ACCOUNT DELETION — WIPES EVERYTHING
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-user', message: 'No user logged in.');
    }

    final uid = user.uid;
    final deviceId = await DeviceIdHelper.get();

    try {
      // 1. Wipe user profile node
      await _rtdb.child('users/$uid').remove();

      // 2. Wipe device binding
      try {
        await _rtdb.child('deviceBindings/$deviceId').remove();
      } catch (_) {}

      // 3. Wipe all video links owned by this user
      try {
        final linksSnap = await _rtdb
            .child('links')
            .orderByChild('ownerUid')
            .equalTo(uid)
            .once();
        if (linksSnap.snapshot.value != null && linksSnap.snapshot.value is Map) {
          final links = linksSnap.snapshot.value as Map;
          for (final key in links.keys) {
            await _rtdb.child('links/$key').remove();
          }
        }
      } catch (_) {}

      // 4. Wipe subscriptions (both directions)
      try {
        final subsSnap = await _rtdb.child('subscriptions/$uid').once();
        if (subsSnap.snapshot.value != null && subsSnap.snapshot.value is Map) {
          final subs = subsSnap.snapshot.value as Map;
          for (final subscriberUid in subs.keys) {
            await _rtdb.child('subscriptions/$uid/$subscriberUid').remove();
          }
        }
        await _rtdb.child('userSubs/$uid').remove();
      } catch (_) {}

      // 5. Wipe likes/unlikes/shares on other people's videos
      try {
        final linksSnap = await _rtdb.child('links').once();
        if (linksSnap.snapshot.value != null && linksSnap.snapshot.value is Map) {
          final allLinks = Map<String, dynamic>.from(linksSnap.snapshot.value as Map);
          for (final vid in allLinks.keys) {
            await _rtdb.child('links/$vid/likes/$uid').remove();
            await _rtdb.child('links/$vid/unlikes/$uid').remove();
          }
        }
      } catch (_) {}

      // 6. Wipe local preferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('saved_videos_v1_$uid');
        await prefs.remove('watch_history_v2_$uid');
        await prefs.remove('mj_login_attempts');
        await prefs.remove('mj_device_id');
        await prefs.remove('liked_${uid}_');
        
        final keys = prefs.getKeys().toList();
        for (final k in keys) {
          if (k.contains(uid)) {
            await prefs.remove(k);
          }
        }
      } catch (_) {}

      // 7. Delete Firebase Auth account
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          await signOut();
          throw FirebaseAuthException(
            code: 'requires-recent-login',
            message: 'For security reasons, please re-login and try again.',
          );
        }
        rethrow;
      }

      await signOut();
    } catch (e) {
      debugPrint('deleteAccount error: $e');
      await signOut();
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getProfile(String uid) async {
    try {
      final snap = await _rtdb.child('users/$uid').once();
      final val = snap.snapshot.value;
      if (val == null) return null;
      return Map<String, dynamic>.from(val as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> getDashboard() async {
    if (cachedUid == null) return {};
    try {
      final apiKey = cachedApiKey ?? await loadApiKey();

      final url = Uri.parse('$kBackendBaseUrl/api/user-stats?key=$apiKey&uid=$cachedUid');
      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          final d = Map<String, dynamic>.from(json['data']);
          return {
            'totalViews': (d['totalViews'] ?? d['views'] ?? 0) as int,
            'todayViews': (d['todayViews'] ?? 0) as int,
            'totalLinks': (d['totalLinks'] ?? d['links'] ?? 0) as int,
          };
        }
      }
    } catch (e) {
      debugPrint('Web Server API stats fetch fallback: $e');
    }

    try {
      final snap = await _rtdb.child('links').orderByChild('ownerUid').equalTo(cachedUid!).once();
      int calculatedViews = 0;
      int calculatedLinks = 0;
      if (snap.snapshot.value != null && snap.snapshot.value is Map) {
        final map = Map<String, dynamic>.from(snap.snapshot.value as Map);
        calculatedLinks = map.length;
        for (final v in map.values) {
          if (v is Map && v['views'] is num) {
            calculatedViews += (v['views'] as num).toInt();
          }
        }
      }
      return {
        'totalViews': calculatedViews,
        'todayViews': 0,
        'totalLinks': calculatedLinks,
      };
    } catch (_) {
      return {'totalViews': 0, 'todayViews': 0, 'totalLinks': 0};
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

  static Future<List<Map<String, dynamic>>> getUserLinks({int limit = 50}) async {
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
    } catch (_) {
      return [];
    }
  }

  static Map<String, dynamic> getTierInfo(int views) {
    views = math.max(0, views);
    if (views < 1000) {
      return {'tier': 1, 'next': 1000 - views};
    }
    if (views < 2000) {
      return {'tier': 2, 'next': 2000 - views};
    }
    if (views < 10000) {
      return {'tier': 3, 'next': 10000 - views};
    }
    return {
      'tier': 4 + (views ~/ 10000),
      'next': 10000 - (views % 10000),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIREBASE SERVICE — REALTIME CLOUD INTEGRATION & NOTIFICATIONS
// ═══════════════════════════════════════════════════════════════════════════════
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

        await _rtdb.child('users/$channelUid/subscribersCount').runTransaction((mutableData) {
          int count = 0;
          if (mutableData != null && mutableData is int) {
            count = mutableData;
          }
          return Transaction.success(math.max(0, count - 1));
        });

        return false;
      } else {
        await ref.set(DateTime.now().millisecondsSinceEpoch);
        await _rtdb.child('userSubs/$subscriberUid/$channelUid').set(DateTime.now().millisecondsSinceEpoch);

        await _rtdb.child('users/$channelUid/subscribersCount').runTransaction((mutableData) {
          int count = 0;
          if (mutableData != null && mutableData is int) {
            count = mutableData;
          }
          return Transaction.success(count + 1);
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

// ═══════════════════════════════════════════════════════════════════════════════
// 🔥 REAL FIRE PARTICLE ANIMATION (Delete Account ke liye)
// ═══════════════════════════════════════════════════════════════════════════════
class RealFireParticles extends StatefulWidget {
  final double width;
  final double height;
  const RealFireParticles({super.key, required this.width, required this.height});

  @override
  State<RealFireParticles> createState() => _RealFireParticlesState();
}

class _RealFireParticlesState extends State<RealFireParticles> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_Particle> _particles = [];
  final math.Random _rand = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 50))..repeat();
    _ctrl.addListener(() {
      if (!mounted) return;
      setState(() {
        // Naye particles add karein
        if (_particles.length < 60) {
          _particles.add(_Particle(
            x: _rand.nextDouble() * widget.width,
            y: widget.height,
            vx: (_rand.nextDouble() - 0.5) * 2,
            vy: -(1.5 + _rand.nextDouble() * 3),
            radius: 4 + _rand.nextDouble() * 8,
            life: 1.0,
            color: _rand.nextBool() ? AppThemes.kFireOrange : AppThemes.kFireYellow,
          ));
        }

        // Particles ko update karein
        for (int i = _particles.length - 1; i >= 0; i--) {
          final p = _particles[i];
          p.x += p.vx;
          p.y += p.vy;
          p.life -= 0.02;
          p.radius *= 0.98;
          if (p.life <= 0 || p.y < 0) {
            _particles.removeAt(i);
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(widget.width, widget.height),
      painter: _FirePainter(_particles),
    );
  }
}

class _Particle {
  double x, y, vx, vy, radius, life;
  Color color;
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.life,
    required this.color,
  });
}

class _FirePainter extends CustomPainter {
  final List<_Particle> particles;
  _FirePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      paint.color = p.color.withOpacity(p.life.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
// ═══════════════════════════════════════════════════════════════════════════════
// NOTIFICATION DETAILS SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class NotificationDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> notification;
  const NotificationDetailsScreen({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final title = notification['title']?.toString() ?? 'Notification';
    final message = notification['message']?.toString() ?? '';
    final timeMs = notification['time'] as int? ?? 0;
    final dt = DateTime.fromMillisecondsSinceEpoch(timeMs);

    return Scaffold(
      backgroundColor: AppThemes.kBg,
      appBar: AppBar(
        title: const Text(
          'NOTIFICATION DETAILS',
          style: TextStyle(letterSpacing: 1.2, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppThemes.kGreen, size: 18),
          onPressed: () {
            SoundService.playClick();
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppThemes.kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppThemes.kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppThemes.kGreen.withOpacity(0.5)),
                      color: Colors.black,
                    ),
                    child: const Icon(Icons.notifications_active, color: AppThemes.kGreen, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppThemes.kBorder),
                ),
                child: Text(
                  'Received: ${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10.5, fontFamily: 'monospace'),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: Colors.white10, height: 1),
              ),
              SelectableText(
                message,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13.5,
                  height: 1.6,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () {
                    SoundService.playClick();
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppThemes.kBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'BACK TO APP',
                    style: TextStyle(color: AppThemes.kGreen, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 12),
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

// ═══════════════════════════════════════════════════════════════════════════════
// TOP SLIDE-DOWN NOTIFICATION DROPDOWN OVERLAY
// ═══════════════════════════════════════════════════════════════════════════════
void showTopNotificationDropdown(BuildContext context) {
  final uid = MayaJaalAccount.cachedUid;
  if (uid == null) return;
  SoundService.playClick();

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Notifications',
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, anim1, anim2) {
      return Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 12, right: 12),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
            decoration: BoxDecoration(
              color: AppThemes.kCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppThemes.kBorder),
              boxShadow: const [
                BoxShadow(color: Colors.black87, blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
                          border: Border.all(color: AppThemes.kBorder),
                        ),
                        child: const Icon(Icons.notifications_active, color: AppThemes.kGreen, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'NOTIFICATIONS',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5, letterSpacing: 1.0),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          SoundService.playClick();
                          FirebaseService.markAllRead(uid);
                        },
                        child: const Text('Mark all read', style: TextStyle(color: AppThemes.kDimGreen, fontSize: 10.5)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                        onPressed: () {
                          SoundService.playClick();
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                Flexible(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: FirebaseService.getNotifications(uid),
                    builder: (context, snapshot) {
                      final list = snapshot.data ?? [];
                      if (list.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.notifications_off_outlined, color: Colors.white24, size: 40),
                              const SizedBox(height: 8),
                              const Text('No new notifications', style: TextStyle(color: Colors.white54, fontSize: 11.5)),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (c, i) {
                          final item = list[i];
                          final isRead = item['read'] == true;
                          final time = item['time'] as int? ?? 0;
                          final dt = DateTime.fromMillisecondsSinceEpoch(time);

                          return ListTile(
                            onTap: () {
                              SoundService.playClick();
                              if (!isRead) {
                                FirebaseService.markNotificationRead(uid, item['id'] as String);
                              }
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NotificationDetailsScreen(notification: item),
                                ),
                              );
                            },
                            title: Text(
                              item['title'] ?? '',
                              style: TextStyle(
                                color: isRead ? Colors.white60 : Colors.white,
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                fontSize: 12.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              item['message'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!isRead)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(bottom: 4),
                                    decoration: const BoxDecoration(color: AppThemes.kRed, shape: BoxShape.circle),
                                  ),
                                Text(
                                  '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9.0),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim1, anim2, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
        ),
        child: child,
      );
    },
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLOUD-SYNCED WATCH HISTORY & SAVED VIDEOS
// ═══════════════════════════════════════════════════════════════════════════════
class WatchHistory {
  static String get _uid => MayaJaalAccount.cachedUid ?? 'guest';
  static String get _historyKey => 'watch_history_v2_$_uid';
  static String get _savedKey => 'saved_videos_v1_$_uid';

  static DatabaseReference get _rtdb => FirebaseDatabase.instance.ref();

  static Future<List<String>> getRecentIds({int limit = 10}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw != null) {
        final List decoded = jsonDecode(raw);
        return decoded
            .take(limit)
            .map((e) => (e['id'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toList();
      }

      if (_uid != 'guest') {
        final snap = await _rtdb.child('users/$_uid/watchHistory').limitToLast(limit).once();
        if (snap.snapshot.value != null && snap.snapshot.value is Map) {
          final map = Map<String, dynamic>.from(snap.snapshot.value as Map);
          return map.values.map((v) => (v['id'] ?? '').toString()).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<String> getCachedThumbnail(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw != null) {
        final List decoded = jsonDecode(raw);
        for (final item in decoded) {
          if (item is Map && item['url'] == url) {
            final t = (item['thumbnail'] ?? '').toString();
            if (t.isNotEmpty) return t;
          }
        }
      }
    } catch (_) {}
    return '';
  }

  static Future<String> getCachedStreamUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw != null) {
        final List decoded = jsonDecode(raw);
        for (final item in decoded) {
          if (item is Map && item['url'] == url) {
            final s = (item['streamUrl'] ?? '').toString();
            if (s.isNotEmpty) return s;
          }
        }
      }
    } catch (_) {}
    return '';
  }

  static Future<void> saveThumbnail(String url, String base64Thumb) async {
    if (url.isEmpty || base64Thumb.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      final raw = prefs.getString(_historyKey);
      if (raw != null) {
        final List decoded = jsonDecode(raw);
        bool updated = false;
        for (final item in decoded) {
          if (item is Map && item['url'] == url) {
            final existing = (item['thumbnail'] ?? '').toString();
            if (existing.isEmpty) {
              item['thumbnail'] = base64Thumb;
              updated = true;
            }
          }
        }
        if (updated) {
          await prefs.setString(_historyKey, jsonEncode(decoded));
        }
      }

      final rawSaved = prefs.getString(_savedKey);
      if (rawSaved != null) {
        final List decoded = jsonDecode(rawSaved);
        bool updated = false;
        for (final item in decoded) {
          if (item is Map && item['url'] == url) {
            final existing = (item['thumbnail'] ?? '').toString();
            if (existing.isEmpty) {
              item['thumbnail'] = base64Thumb;
              updated = true;
            }
          }
        }
        if (updated) {
          await prefs.setString(_savedKey, jsonEncode(decoded));
        }
      }
    } catch (_) {}
  }

  static Future<void> syncWatchRecordCloud(Map<String, dynamic> item) async {
    if (_uid == 'guest') return;
    try {
      final safeKey = (item['id'] ?? DateTime.now().millisecondsSinceEpoch).toString();
      await _rtdb.child('users/$_uid/watchHistory/$safeKey').set({
        ...item,
        'syncedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Cloud sync error: $e');
    }
  }

  static Future<void> syncSavedRecordCloud(Map<String, dynamic> item, bool isAdd) async {
    if (_uid == 'guest') return;
    try {
      final safeKey = (item['id'] ?? DateTime.now().millisecondsSinceEpoch).toString();
      if (isAdd) {
        await _rtdb.child('users/$_uid/savedVideos/$safeKey').set({
          ...item,
          'savedAt': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        await _rtdb.child('users/$_uid/savedVideos/$safeKey').remove();
      }
    } catch (e) {
      debugPrint('Cloud saved sync error: $e');
    }
  }

  static Future<void> repairBadTitles({
    required List<Map<String, dynamic>> history,
    required List<Map<String, dynamic>> saved,
  }) async {
    bool historyChanged = false;
    bool savedChanged = false;

    for (final item in history) {
      final id = (item['id'] ?? '').toString();
      final title = (item['title'] ?? '').toString();
      if (id.isNotEmpty && VideoNameResolver.isBadTitle(title, id)) {
        final real = await VideoNameResolver.resolve(id);
        if (real.isNotEmpty) {
          item['title'] = real;
          historyChanged = true;
        }
      }
    }

    for (final item in saved) {
      final id = (item['id'] ?? '').toString();
      final title = (item['title'] ?? '').toString();
      if (id.isNotEmpty && VideoNameResolver.isBadTitle(title, id)) {
        final real = await VideoNameResolver.resolve(id);
        if (real.isNotEmpty) {
          item['title'] = real;
          savedChanged = true;
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    if (historyChanged) {
      await prefs.setString(_historyKey, jsonEncode(history));
    }
    if (savedChanged) {
      await prefs.setString(_savedKey, jsonEncode(saved));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN APPLICATION ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════
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
    debugPrint("✅ Firebase Initialized Successfully");
    await MayaJaalAccount.init();
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }

  try {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(oneSignalAppId);
  } catch (e) {
    debugPrint("OneSignal Init Error: $e");
  }

  runApp(const MyApp());
}

// ═══════════════════════════════════════════════════════════════════════════════
// MATRIX DIGITAL RAIN BACKGROUND EFFECT
// ═══════════════════════════════════════════════════════════════════════════════
class MatrixRain extends StatefulWidget {
  final double opacity;
  const MatrixRain({super.key, this.opacity = 0.5});
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
    for (int i = 0; i < 28; i++) {
      _yPositions.add(-_r.nextInt(600).toDouble());
      _speeds.add(3.5 + _r.nextDouble() * 5.0);
      _letters.add(_chars[_r.nextInt(_chars.length)]);
    }
    _timer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _yPositions.length; i++) {
          _yPositions[i] += _speeds[i];
          if (_yPositions[i] > 900) {
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
                  color: AppThemes.kGreen.withOpacity(widget.opacity),
                  fontSize: 12,
                  fontFamily: 'monospace',
                  shadows: [Shadow(color: AppThemes.kGreen.withOpacity(0.5), blurRadius: 4)],
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROFESSIONAL MATRIX ROTATING LOADER SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
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
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _pulse = Tween<double>(begin: 0.90, end: 1.08)
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
      backgroundColor: AppThemes.kBg,
      body: Stack(
        children: [
          const MatrixRain(opacity: 0.25),
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
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                AppThemes.kGreen.withOpacity(0.0),
                                AppThemes.kGreen,
                                AppThemes.kNeonCyan,
                                AppThemes.kGreen.withOpacity(0.0),
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
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                            border: Border.all(color: AppThemes.kGreen.withOpacity(0.8), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppThemes.kGreen.withOpacity(0.35),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/icon/logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => const Icon(
                                Icons.change_history,
                                color: AppThemes.kGreen,
                                size: 45,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'monospace',
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: const LinearProgressIndicator(
                      minHeight: 2.5,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(AppThemes.kGreen),
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

// ═══════════════════════════════════════════════════════════════════════════════
// SPLASH SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
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
    _a = Tween<double>(begin: 0.92, end: 1.08)
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
      backgroundColor: AppThemes.kBg,
      body: Stack(
        children: [
          const MatrixRain(opacity: 0.40),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _a,
                  builder: (c, _) => Transform.scale(
                    scale: _a.value,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppThemes.kGreen.withOpacity(0.35),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset(
                          'assets/icon/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            color: Colors.black,
                            child: const Icon(
                              Icons.movie_filter,
                              size: 60,
                              color: AppThemes.kGreen,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'MAYAJAAL',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontFamily: 'monospace',
                    letterSpacing: 4,
                    shadows: [
                      Shadow(color: AppThemes.kGreen.withOpacity(0.7), blurRadius: 12)
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '> initializing quantum cipher...',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppThemes.kDimGreen.withOpacity(0.8),
                    fontFamily: 'monospace',
                    letterSpacing: 1.5,
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

// ═══════════════════════════════════════════════════════════════════════════════
// MY APP — ROOT APP CONTAINER & DYNAMIC THEME BUILDER
// ═══════════════════════════════════════════════════════════════════════════════
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static _MyAppState? instance;

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;
  Uri? _initialLink;
  bool _linkReady = false;
  String? _pendingVideoTargetUrl;

  String? get pendingUrl => _pendingVideoTargetUrl;
  void clearPending() => _pendingVideoTargetUrl = null;

  @override
  void initState() {
    super.initState();
    instance = this;
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _initialLink = initial;
        final url = _buildUrlFromLink(initial);
        if (url.isNotEmpty) {
          _pendingVideoTargetUrl = url;
          debugPrint('📌 Initial deep link pending: $url');
        }
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

  String _buildUrlFromLink(Uri uri) {
    String videoId = '';
    final token = uri.queryParameters['t'] ?? uri.queryParameters['s'] ?? '';

    if (uri.path.startsWith('/v/') || uri.path.startsWith('/s/')) {
      videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    } else if (uri.queryParameters['v'] != null) {
      videoId = uri.queryParameters['v']!;
    }

    if (videoId.isEmpty) return '';

    return token.isNotEmpty
        ? 'https://www.mayajaal.online/v/$videoId?t=$token'
        : 'https://www.mayajaal.online/v/$videoId';
  }

  void _handleDeepLink(Uri uri) {
    final target = _buildUrlFromLink(uri);
    if (target.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _pendingVideoTargetUrl = target;
      navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => LoginScreen(
          onLoginSuccess: () {
            final pending = _pendingVideoTargetUrl;
            _pendingVideoTargetUrl = null;
            if (pending != null && pending.isNotEmpty) {
              navigatorKey.currentState?.pushReplacement(
                MaterialPageRoute(builder: (_) => StreamPreviewScreen(targetUrl: pending)),
              );
            }
          },
        ),
      ));
      return;
    }

    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => StreamPreviewScreen(targetUrl: target),
    ));
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    if (instance == this) instance = null;
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
        return ValueListenableBuilder<String>(
          valueListenable: themeNotifier,
          builder: (context, currentTheme, _) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              title: 'MayaJaal',
              debugShowCheckedModeBanner: false,
              themeMode: ThemeMode.dark,
              theme: _buildDynamicTheme(currentTheme),
              darkTheme: _buildDynamicTheme(currentTheme),
              home: const AuthGate(),
            );
          },
        );
      },
    );
  }

  ThemeData _buildDynamicTheme(String themeName) {
    Color primaryColor = AppThemes.kGreen;
    if (themeName == 'Quantum Blue') {
      primaryColor = AppThemes.kNeonCyan;
    } else if (themeName == 'Neon Violet') {
      primaryColor = AppThemes.kNeonPurple;
    } else if (themeName == 'Obsidian Stealth') {
      primaryColor = Colors.white70;
    }

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppThemes.kBg,
      canvasColor: AppThemes.kBg,
      dialogBackgroundColor: AppThemes.kCardBg,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        surface: AppThemes.kCardBg,
      ),
      useMaterial3: true,
      fontFamily: 'monospace',
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUTH GATE
// ═══════════════════════════════════════════════════════════════════════════════
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _initialCheckDone = false;
  String? _initialPendingUrl;
  bool _initialHandled = false;
  String? _blockingError;
  bool _gateChecked = false;
  bool _afterLogout = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.delayed(const Duration(milliseconds: 300));

    _initialPendingUrl = _MyAppState.instance?.pendingUrl;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final err = await SecurityGuard.fullGate(user);
      if (err != null) {
        await MayaJaalAccount.signOut();
        _afterLogout = true;
        _blockingError = err;
      }
    } else {
      _afterLogout = true;
    }

    if (mounted) {
      setState(() {
        _initialCheckDone = true;
        _gateChecked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialCheckDone) {
      return const SplashScreen();
    }

    if (_blockingError != null) {
      return _SecurityBlockScreen(
        error: _blockingError!,
        onRetry: () async {
          setState(() {
            _blockingError = null;
            _initialCheckDone = false;
            _gateChecked = false;
            _afterLogout = false;
          });
          await _initialize();
        },
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || !_gateChecked) {
          return const SplashScreen();
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          if (_afterLogout) {
            Future.microtask(() async {
              final err = await SecurityGuard.validateUser(user);
              if (err != null) {
                await MayaJaalAccount.signOut();
                if (mounted) setState(() {});
              }
            });
          }

          WidgetsBinding.instance.addPostFrameCallback((_) async {
            MayaJaalAccount.cachedUid = user.uid;
            MayaJaalAccount.cachedEmail = user.email;
            MayaJaalAccount.cachedName = user.displayName;
            MayaJaalAccount.cachedPhoto = user.photoURL;
            await MayaJaalAccount.syncUserToRTDB(user);
            await MayaJaalAccount.loadApiKey();

            try {
              OneSignal.Notifications.requestPermission(true);
            } catch (_) {}
          });

          if (!_initialHandled &&
              _initialPendingUrl != null &&
              _initialPendingUrl!.isNotEmpty) {
            _initialHandled = true;
            final url = _initialPendingUrl!;
            _initialPendingUrl = null;
            _MyAppState.instance?.clearPending();
            return StreamPreviewScreen(targetUrl: url);
          }

          return const MainNavigationHolder();
        }

        return const LoginScreen();
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECURITY BLOCK SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class _SecurityBlockScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _SecurityBlockScreen({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.kBg,
      body: Stack(
        children: [
          const MatrixRain(opacity: 0.20),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                      border: Border.all(color: AppThemes.kRed, width: 2),
                      boxShadow: [
                        BoxShadow(color: AppThemes.kRed.withOpacity(0.4), blurRadius: 25),
                      ],
                    ),
                    child: const Icon(Icons.gpp_bad, color: AppThemes.kRed, size: 44),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'SECURITY BLOCK',
                    style: TextStyle(
                      color: AppThemes.kRed,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: 200,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        SoundService.playClick();
                        onRetry();
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text(
                        'RETRY CHECK',
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemes.kRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () async {
                      SoundService.playClick();
                      await MayaJaalAccount.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      }
                    },
                    icon: const Icon(Icons.logout, color: AppThemes.kDimGreen, size: 16),
                    label: const Text(
                      'LOGOUT',
                      style: TextStyle(color: AppThemes.kDimGreen, letterSpacing: 1.2, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GOOGLE AUTHENTICATION SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
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

  @override
  void initState() {
    super.initState();
    _magicController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _magicController.dispose();
    super.dispose();
  }

  Future<void> _triggerMagic() async {
    SoundService.playAlert();
    await _magicController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
  }

  Future<void> _handleGoogle() async {
    SoundService.playClick();
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
      setState(() => _error = '❌ ${e.message ?? _fbError(e.code)}');
    } catch (e) {
      setState(() => _error = '❌ $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fbError(String code) {
    switch (code) {
      case 'invalid-credential':
        return 'Only @gmail.com accounts are allowed';
      case 'too-many-requests':
        return 'Too many attempts, try again in 10 minutes';
      case 'network-request-failed':
        return 'Check your internet connection';
      default:
        return code.replaceAll('-', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.kBg,
      body: Stack(
        children: [
          const MatrixRain(opacity: 0.2),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppThemes.kGreen, width: 2),
                          boxShadow: [
                            BoxShadow(color: AppThemes.kGreen.withOpacity(0.4), blurRadius: 15),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/icon/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(
                              Icons.change_history,
                              color: AppThemes.kGreen,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Maya',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                      const Text(
                        'Jaal',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppThemes.kGreen,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'Your Videos.\nYour Links.',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                  const Text(
                    'Your Universe.',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: AppThemes.kGreen,
                      height: 1.1,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "World's Smartest Video Sharing Platform",
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.white.withOpacity(0.75),
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(29)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.network(
                                  'https://developers.google.com/identity/images/g-logo.png',
                                  height: 24,
                                  errorBuilder: (c, e, s) => const Icon(Icons.g_mobiledata, color: Colors.red, size: 28),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Sign in with Google',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'sans-serif'),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 11.5),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN NAVIGATION HOLDER (4 TABS)
// ═══════════════════════════════════════════════════════════════════════════════
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
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppThemes.kBg,
      drawer: const MoreDrawer(),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(onMenuTap: () => _scaffoldKey.currentState?.openDrawer()),
          const ChannelScreen(),
          const GalleryScreen(),
          const HistoryScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border(
            top: BorderSide(color: AppThemes.kBorder, width: 1.0),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: Colors.black,
          elevation: 0,
          selectedItemColor: AppThemes.kGreen,
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          onTap: (index) {
            SoundService.playClick();
            Haptic.selection();
            setState(() => _currentIndex = index);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home, color: AppThemes.kGreen),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.ondemand_video_outlined),
              activeIcon: Icon(Icons.ondemand_video, color: AppThemes.kGreen),
              label: 'Channel',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.photo_library_outlined),
              activeIcon: Icon(Icons.photo_library, color: AppThemes.kGreen),
              label: 'Gallery',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history, color: AppThemes.kGreen),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LIVE PULSE GRAPH PAINTER
// ═══════════════════════════════════════════════════════════════════════════════
class LivePulseGraphPainter extends CustomPainter {
  final List<double> viewPoints;
  final List<double> linkPoints;
  final double animPhase;

  LivePulseGraphPainter({
    required this.viewPoints,
    required this.linkPoints,
    required this.animPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (viewPoints.isEmpty || linkPoints.isEmpty) return;

    final gridPaint = Paint()
      ..color = AppThemes.kGreen.withOpacity(0.06)
      ..strokeWidth = 0.8;

    for (double y = 0; y <= size.height; y += size.height / 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = 0; x <= size.width; x += size.width / 5) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    _drawSmoothTrace(canvas, size, viewPoints, AppThemes.kNeonCyan);
    _drawSmoothTrace(canvas, size, linkPoints, AppThemes.kGreen);
  }

  void _drawSmoothTrace(Canvas canvas, Size size, List<double> points, Color color) {
    if (points.length < 2) return;

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (points.length - 1);
    final maxVal = points.reduce(math.max);
    final minVal = points.reduce(math.min);
    final range = (maxVal - minVal) <= 0.001 ? 1.0 : (maxVal - minVal);

    List<Offset> mapped = [];
    for (int i = 0; i < points.length; i++) {
      final normY = (points[i] - minVal) / range;
      final py = (size.height - 8) - (normY * (size.height - 16));
      final px = i * stepX;
      mapped.add(Offset(px, py));
    }

    path.moveTo(mapped[0].dx, mapped[0].dy);
    fillPath.moveTo(mapped[0].dx, size.height);
    fillPath.lineTo(mapped[0].dx, mapped[0].dy);

    for (int i = 0; i < mapped.length - 1; i++) {
      final p0 = mapped[i];
      final p1 = mapped[i + 1];
      final cpX = (p0.dx + p1.dx) / 2;
      path.cubicTo(cpX, p0.dy, cpX, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(cpX, p0.dy, cpX, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.18), color.withOpacity(0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    final lastPoint = mapped.last;
    final dotGlow = Paint()
      ..color = color.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawCircle(lastPoint, 4.0, dotGlow);

    final dotSolid = Paint()..color = Colors.white;
    canvas.drawCircle(lastPoint, 2.0, dotSolid);
  }

  @override
  bool shouldRepaint(covariant LivePulseGraphPainter oldDelegate) {
    return oldDelegate.animPhase != animPhase ||
        oldDelegate.viewPoints != viewPoints ||
        oldDelegate.linkPoints != linkPoints;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LIVE PULSE CARD WIDGET (VIEWS + LINKS)
// ═══════════════════════════════════════════════════════════════════════════════
class LivePulseCard extends StatefulWidget {
  const LivePulseCard({super.key});

  @override
  State<LivePulseCard> createState() => _LivePulseCardState();
}

class _LivePulseCardState extends State<LivePulseCard> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  final List<double> _viewHistory = [0.0, 1.0, 1.0, 2.0, 3.0, 5.0, 4.0, 6.0, 8.0, 9.0];
  final List<double> _linkHistory = [0.0, 0.0, 1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 3.0, 3.0];

  int _prevViews = -1;
  int _prevLinks = -1;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _pushTelemetry(int views, int links) {
    if (_prevViews == views && _prevLinks == links) return;
    _prevViews = views;
    _prevLinks = links;

    if (_viewHistory.length >= 14) {
      _viewHistory.removeAt(0);
      _linkHistory.removeAt(0);
    }
    _viewHistory.add(views.toDouble());
    _linkHistory.add(links.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final uid = MayaJaalAccount.cachedUid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<Map<String, dynamic>>(
      stream: MayaJaalAccount.getDashboardStream(),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final totalViews = (data['totalViews'] ?? 0) as int;
        final totalLinks = (data['totalLinks'] ?? 0) as int;

        _pushTelemetry(totalViews, totalLinks);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppThemes.kCardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppThemes.kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _animCtrl,
                    builder: (c, _) => Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppThemes.kGreen,
                        boxShadow: [
                          BoxShadow(
                            color: AppThemes.kGreen.withOpacity(0.6),
                            blurRadius: 8 * _animCtrl.value,
                            spreadRadius: 1.5 * _animCtrl.value,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'LIVE OSCILLOSCOPE PULSE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppThemes.kNeonCyan)),
                      const SizedBox(width: 4),
                      const Text('Views', style: TextStyle(color: AppThemes.kNeonCyan, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppThemes.kGreen)),
                      const SizedBox(width: 4),
                      const Text('Links', style: TextStyle(color: AppThemes.kGreen, fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$totalLinks',
                        style: const TextStyle(
                          color: AppThemes.kGreen,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'ACTIVE LINKS',
                        style: TextStyle(color: Colors.white38, fontSize: 8, letterSpacing: 0.8),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$totalViews',
                        style: const TextStyle(
                          color: AppThemes.kNeonCyan,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'VERIFIED VIEWS',
                        style: TextStyle(color: Colors.white38, fontSize: 8, letterSpacing: 0.8),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 52,
                  width: double.infinity,
                  color: Colors.black45,
                  child: AnimatedBuilder(
                    animation: _animCtrl,
                    builder: (c, _) => CustomPaint(
                      painter: LivePulseGraphPainter(
                        viewPoints: _viewHistory,
                        linkPoints: _linkHistory,
                        animPhase: _animCtrl.value,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HOME SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
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
      duration: const Duration(milliseconds: 1400),
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
    SoundService.playClick();
    Haptic.medium();
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppThemes.kCardBg,
            content: Text(
              '❌ Clipboard is empty',
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
          backgroundColor: AppThemes.kCardBg,
          content: Text(
            '✅ Link pasted',
            style: TextStyle(color: AppThemes.kGreen),
          ),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('Paste error: $e');
    }
  }

  void _searchAndPlay() {
    SoundService.playClick();
    final input = _linkController.text.trim();
    if (input.isEmpty) {
      Haptic.heavy();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste a stream URL first!'),
          backgroundColor: AppThemes.kCardBg,
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
      onTap: () {
        SoundService.playClick();
        Haptic.light();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: AppThemes.kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppThemes.kBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppThemes.kGreen, size: 24),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 8.5,
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
      backgroundColor: AppThemes.kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, color: AppThemes.kGreen, size: 24),
                      onPressed: () {
                        SoundService.playClick();
                        Haptic.light();
                        widget.onMenuTap?.call();
                      },
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppThemes.kGreen, width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.asset(
                          'assets/icon/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(
                            Icons.change_history,
                            color: AppThemes.kGreen,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Maya',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                    const Text(
                      'Jaal',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppThemes.kGreen,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.search, color: AppThemes.kGreen, size: 22),
                      onPressed: () {
                        SoundService.playClick();
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
                            icon: Icon(
                              Icons.notifications_none,
                              color: unread > 0 ? AppThemes.kRed : AppThemes.kGreen,
                              size: 22,
                            ),
                            onPressed: () {
                              SoundService.playClick();
                              Haptic.light();
                              showTopNotificationDropdown(context);
                            },
                          ),
                          if (unread > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppThemes.kRed,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1.2,
                                  ),
                                ),
                                constraints: const BoxConstraints(minWidth: 16),
                                child: Text(
                                  unread > 99 ? '99+' : '$unread',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
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

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 18,
                      child: Text(
                        'MOVIES\nWEB SERIES\nLIVE TV\n& MORE',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          height: 1.4,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 18,
                      child: Text(
                        'Your\nStreaming\nUniverse',
                        style: TextStyle(
                          color: AppThemes.kDimGreen.withOpacity(0.85),
                          fontSize: 14,
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
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppThemes.kGreen.withOpacity(0.4),
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppThemes.kGreen, width: 1.5),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  'assets/icon/logo.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    color: Colors.black,
                                    child: const Icon(
                                      Icons.movie_filter,
                                      size: 40,
                                      color: AppThemes.kGreen,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppThemes.kCardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppThemes.kBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 14, top: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppThemes.kGreen.withOpacity(0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link, color: AppThemes.kGreen, size: 12),
                              SizedBox(width: 5),
                              Text(
                                'MATRIX NEURAL STREAM NODE',
                                style: TextStyle(
                                  color: AppThemes.kGreen,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppThemes.kBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.link_rounded,
                                color: AppThemes.kGreen,
                                size: 20,
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
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        hintText: 'Paste Stream URL or TeraBox Link',
                                        hintStyle: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tap paste or enter link (Supports TeraBox)',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 8.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: _pasteFromClipboard,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppThemes.kBorder,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.content_paste_rounded,
                                    color: AppThemes.kGreen,
                                    size: 18,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _searchAndPlay,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppThemes.kGreen,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppThemes.kGreen.withOpacity(0.4),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.black,
                                    size: 26,
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _catCard(
                        Icons.movie_creation_outlined,
                        'Movies',
                        'Latest',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _catCard(
                        Icons.live_tv_rounded,
                        'Web Series',
                        'Binge',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _catCard(Icons.tv_rounded, 'Live TV', 'Sports'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _catCard(Icons.star_rounded, 'Favorites', 'Saved'),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppThemes.kCardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppThemes.kBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: AppThemes.kGreen,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Secure Quantum Stream Pipeline Active',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: AppThemes.kGreen, size: 12),
                    ],
                  ),
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  '>   CONNECT   •   STREAM   •   ENJOY   <',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 9.5,
                    letterSpacing: 1.8,
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

// ═══════════════════════════════════════════════════════════════════════════════
// MORE DRAWER (WITH REAL FIRE DELETE ACCOUNT DIALOG)
// ═══════════════════════════════════════════════════════════════════════════════
class MoreDrawer extends StatefulWidget {
  const MoreDrawer({super.key});

  @override
  State<MoreDrawer> createState() => _MoreDrawerState();
}

class _MoreDrawerState extends State<MoreDrawer>
    with TickerProviderStateMixin {
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    SoundService.playClick();
    Haptic.heavy();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('mj_login_attempts');
    } catch (_) {}

    await MayaJaalAccount.signOut();
    await Future.delayed(const Duration(milliseconds: 100));

    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _launchURL(String url, {bool inApp = false}) async {
    SoundService.playClick();
    Haptic.light();
    try {
      final target = Uri.parse(url);
      if (inApp) {
        await launchUrl(target, mode: LaunchMode.inAppBrowserView);
      } else {
        if (!await launchUrl(target, mode: LaunchMode.externalApplication)) {
          await launchUrl(target, mode: LaunchMode.platformDefault);
        }
      }
    } catch (e) {
      try { await launchUrl(Uri.parse(url)); } catch (_) {}
    }
  }

  void _shareApp() {
    SoundService.playClick();
    Haptic.light();
    final myUid = MayaJaalAccount.cachedUid ?? '';
    final refLink = 'https://www.mayajaal.online?ref=$myUid';
    Share.share(
      '🚀 Experience Matrix-speed streaming on MayaJaal App!\nDownload: $refLink',
    );
  }

  void _showAboutDialog(BuildContext context) {
    SoundService.playClick();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppThemes.kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppThemes.kBorder),
        ),
        title: Row(
          children: const [
            Icon(Icons.info_outline, color: AppThemes.kGreen, size: 20),
            SizedBox(width: 8),
            Text(
              'ABOUT MAYAJAAL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
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
                  color: AppThemes.kGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '— STREAM BEYOND LIMITS —',
                style: TextStyle(color: Colors.white54, fontSize: 9.5, letterSpacing: 1.5),
              ),
              SizedBox(height: 12),
              Text(
                'Version: v1.3.0 (Build 5)',
                style: TextStyle(color: Colors.white70, fontSize: 11.5),
              ),
              SizedBox(height: 6),
              Text(
                'MayaJaal is a next-generation video streaming and sharing platform for creators. Convert, share, and enjoy seamlessly with Matrix-grade encryption and quantum-speed streaming.',
                style: TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.4),
              ),
              SizedBox(height: 10),
              Text(
                '👥 Video Sharing Platform · User-Generated Content',
                style: TextStyle(color: AppThemes.kDimGreen, fontSize: 10.5),
              ),
              SizedBox(height: 12),
              Divider(color: Colors.white10),
              SizedBox(height: 6),
              Text(
                '© 2026 MayaJaal. All rights reserved.',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              SoundService.playClick();
              Navigator.pop(c);
            },
            child: const Text('CLOSE', style: TextStyle(color: AppThemes.kGreen)),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(BuildContext context) {
    SoundService.playClick();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppThemes.kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppThemes.kBorder),
        ),
        title: Row(
          children: const [
            Icon(Icons.vpn_key, color: AppThemes.kGreen, size: 20),
            SizedBox(width: 8),
            Text(
              'YOUR API KEY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
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
                'Use this API key in the Telegram bot — /api YOUR_KEY',
                style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppThemes.kBorder),
                ),
                child: SelectableText(
                  MayaJaalAccount.cachedApiKey ?? 'Loading...',
                  style: const TextStyle(
                    color: AppThemes.kGreen,
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Email: ${MayaJaalAccount.cachedEmail ?? 'N/A'}',
                style: const TextStyle(color: Colors.white54, fontSize: 10.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              SoundService.playClick();
              final key = MayaJaalAccount.cachedApiKey ?? '';
              if (key.isNotEmpty) {
                Haptic.medium();
                await Clipboard.setData(ClipboardData(text: key));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppThemes.kCardBg,
                      content: Text('✅ API Key copied', style: TextStyle(color: AppThemes.kGreen)),
                    ),
                  );
                }
              }
            },
            child: const Text('COPY', style: TextStyle(color: AppThemes.kGreen)),
          ),
          TextButton(
            onPressed: () {
              SoundService.playClick();
              Navigator.pop(c);
            },
            child: const Text('CLOSE', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  void _showBotsDialog(BuildContext context) {
    SoundService.playClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppThemes.kBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.smart_toy, color: AppThemes.kGreen, size: 22),
                SizedBox(width: 8),
                Text(
                  'MAYAJAAL BOTS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Choose a bot to start converting',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10.5),
            ),
            const SizedBox(height: 14),
            _botCard(
              context,
              icon: Icons.upload_rounded,
              color: AppThemes.kNeonCyan,
              title: 'Upload Bot',
              subtitle: 'Upload videos & get your stream link',
              url: 'https://t.me/Mayajaalfilebot',
            ),
            const SizedBox(height: 10),
            _botCard(
              context,
              icon: Icons.link_rounded,
              color: AppThemes.kNeonPurple,
              title: 'Converter Bot',
              subtitle: 'Convert links & share easily',
              url: 'https://t.me/MayaJaalBulkConverterbot',
            ),
            const SizedBox(height: 14),
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
        SoundService.playClick();
        Haptic.medium();
        Navigator.pop(context);
        _launchURL(url);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppThemes.kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppThemes.kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.6), width: 1.2),
              ),
              child: Icon(icon, color: color, size: 20),
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
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 12),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    SoundService.playClick();
    final confirmCtrl = TextEditingController();
    bool isDeleting = false;
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.black,
            contentPadding: const EdgeInsets.all(0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: AppThemes.kFireOrange.withOpacity(0.8), width: 1.5),
            ),
            content: Container(
              width: double.maxFinite,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppThemes.kCardBg,
                    AppThemes.kBg,
                    AppThemes.kRed.withOpacity(0.15),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // 🔥 Real Fire Animation Background
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 250,
                    child: RealFireParticles(
                      width: MediaQuery.of(context).size.width,
                      height: 250,
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppThemes.kRed.withOpacity(0.2),
                                border: Border.all(color: AppThemes.kRed, width: 1.5),
                                boxShadow: [
                                  BoxShadow(color: AppThemes.kRed.withOpacity(0.5), blurRadius: 15),
                                ],
                              ),
                              child: const Icon(Icons.local_fire_department, color: AppThemes.kFireOrange, size: 26),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'BURN & DELETE',
                                style: TextStyle(
                                  color: AppThemes.kRed,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        const Text(
                          '⚠️ WARNING: PERMANENT ACTION!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Deleting this account will permanently erase all your data. When you log in again, you will start fresh as a brand new user.',
                          style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
                        ),
                        
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fireBullet('All your videos and links will be deleted'),
                              _fireBullet('Watch history & saved videos will be wiped'),
                              _fireBullet('All views and Cyber Rank will be reset to zero'),
                              _fireBullet('Firebase Auth account will be permanently deleted'),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 18),
                        Text(
                          'Type "DELETE" to confirm:',
                          style: TextStyle(color: AppThemes.kFireYellow.withOpacity(0.9), fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: confirmCtrl.text == 'DELETE' ? AppThemes.kRed : AppThemes.kBorder, width: 1.5),
                          ),
                          child: TextField(
                            controller: confirmCtrl,
                            enabled: !isDeleting,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(
                              color: AppThemes.kRed,
                              fontSize: 14,
                              fontFamily: 'monospace',
                              letterSpacing: 3,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'DELETE',
                              hintStyle: TextStyle(
                                color: Colors.white24,
                                fontSize: 13,
                                fontFamily: 'monospace',
                                letterSpacing: 3,
                              ),
                              border: InputBorder.none,
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        
                        if (errorMsg != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.redAccent),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppThemes.kRed, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMsg!,
                                    style: const TextStyle(color: AppThemes.kRed, fontSize: 10.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        if (isDeleting) ...[
                          const SizedBox(height: 16),
                          const Center(
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(color: AppThemes.kFireOrange, strokeWidth: 3),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Burning your data...',
                                  style: TextStyle(color: AppThemes.kFireOrange, fontSize: 10.5, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: isDeleting ? null : () {
                                  SoundService.playClick();
                                  Navigator.pop(c);
                                },
                                child: const Text(
                                  'CANCEL',
                                  style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: StatefulBuilder(
                                builder: (context, setBtnState) {
                                  Timer.periodic(const Duration(milliseconds: 50), (timer) {
                                    if (confirmCtrl.text == 'DELETE' && !isDeleting && c.mounted) {
                                      setBtnState(() {});
                                    }
                                  });

                                  return Transform.scale(
                                    scale: (confirmCtrl.text == 'DELETE' && !isDeleting) 
                                        ? 1.0 + (math.sin(DateTime.now().millisecondsSinceEpoch / 200.0) * 0.03)
                                        : 1.0,
                                    child: ElevatedButton(
                                      onPressed: (confirmCtrl.text == 'DELETE' && !isDeleting)
                                          ? () async {
                                              SoundService.playAlert();
                                              Haptic.heavy();
                                              setDialogState(() {
                                                isDeleting = true;
                                                errorMsg = null;
                                              });
                                              try {
                                                await MayaJaalAccount.deleteAccount();
                                                if (c.mounted) {
                                                  Navigator.pop(c);
                                                  Navigator.pop(context);
                                                  Navigator.of(context).pushAndRemoveUntil(
                                                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                                                    (route) => false,
                                                  );
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      backgroundColor: AppThemes.kCardBg,
                                                      content: Text(
                                                        '🔥 Account burned successfully. You will start as a new user.',
                                                        style: TextStyle(color: AppThemes.kFireOrange, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } on FirebaseAuthException catch (e) {
                                                if (e.code == 'requires-recent-login') {
                                                  setDialogState(() {
                                                    isDeleting = false;
                                                    errorMsg = 'Security: Please re-login and try again.';
                                                  });
                                                } else {
                                                  setDialogState(() {
                                                    isDeleting = false;
                                                    errorMsg = e.message ?? 'Deletion failed. Try again.';
                                                  });
                                                }
                                              } catch (e) {
                                                setDialogState(() {
                                                  isDeleting = false;
                                                  errorMsg = 'Deletion failed. Please try again.';
                                                });
                                              }
                                            }
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppThemes.kRed,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        disabledBackgroundColor: Colors.white12,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        elevation: confirmCtrl.text == 'DELETE' ? 12 : 0,
                                        shadowColor: AppThemes.kRed,
                                      ),
                                      child: const Text(
                                        'DELETE FOREVER',
                                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 12),
                                      ),
                                    ),
                                  );
                                },
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
          );
        },
      ),
    );
  }

  Widget _fireBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2, right: 6),
            child: Icon(Icons.local_fire_department, size: 12, color: AppThemes.kFireOrange),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _staggered({required int index, required Widget child}) {
    final start = (index * 0.04).clamp(0.0, 0.5);
    return AnimatedBuilder(
      animation: _slideController,
      builder: (c, _) {
        final raw = (_slideController.value - start) / (1 - start);
        final v = raw.clamp(0.0, 1.0);
        final curve = Curves.easeOutCubic.transform(v);
        return Opacity(
          opacity: curve,
          child: Transform.translate(
            offset: Offset(-16 * (1 - curve), 0),
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
      backgroundColor: AppThemes.kBg,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppThemes.kCardBg,
                border: Border(bottom: BorderSide(color: AppThemes.kBorder, width: 1.0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppThemes.kBorder),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/icon/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.change_history,
                          color: AppThemes.kGreen,
                          size: 18,
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
                        Row(
                          children: const [
                            Text(
                              'Maya',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Jaal',
                              style: TextStyle(
                                color: AppThemes.kGreen,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'OPTIONS',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 7.5,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                    onPressed: () {
                      SoundService.playClick();
                      Haptic.light();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  _staggered(index: 0, child: const LivePulseCard()),
                  _staggered(
                    index: 1,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppThemes.kCardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppThemes.kBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppThemes.kBorder),
                            ),
                            child: user?.photoURL != null
                                ? ClipOval(
                                    child: Image.network(
                                      user!.photoURL!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => const Icon(
                                        Icons.person,
                                        color: AppThemes.kGreen,
                                        size: 18,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.person, color: AppThemes.kGreen, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.displayName ?? user?.email ?? 'User',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.verified, color: AppThemes.kDimGreen, size: 9),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Verified Account',
                                      style: TextStyle(color: Colors.white38, fontSize: 8.5),
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
                      icon: Icons.insights,
                      color: AppThemes.kGold,
                      title: 'Creator Stats',
                      subtitle: 'Views, links & rank analytics',
                      onTap: () {
                        SoundService.playClick();
                        Haptic.medium();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StatsScreen()),
                        );
                      },
                    ),
                  ),
                  _staggered(
                    index: 3,
                    child: _snakeItem(
                      context,
                      icon: Icons.bookmark,
                      color: AppThemes.kNeonCyan,
                      title: 'Saved Videos',
                      subtitle: 'Your cloud bookmarked media',
                      onTap: () {
                        SoundService.playClick();
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
                    index: 4,
                    child: _snakeItem(
                      context,
                      icon: Icons.vpn_key,
                      color: AppThemes.kNeonPurple,
                      title: 'My API Key',
                      subtitle: 'View & copy for Telegram bot',
                      onTap: () {
                        Navigator.pop(context);
                        _showApiKeyDialog(context);
                      },
                    ),
                  ),
                  _staggered(
                    index: 5,
                    child: _snakeItem(
                      context,
                      icon: Icons.smart_toy,
                      color: AppThemes.kGold,
                      title: 'MayaJaal Bots',
                      subtitle: 'Upload & Converter automation',
                      onTap: () {
                        Navigator.pop(context);
                        _showBotsDialog(context);
                      },
                    ),
                  ),
                  _staggered(
                    index: 6,
                    child: _snakeItem(
                      context,
                      icon: Icons.share,
                      color: AppThemes.kNeonCyan,
                      title: 'Share MayaJaal App',
                      subtitle: 'Invite friends & boost rank',
                      onTap: () {
                        Navigator.pop(context);
                        _shareApp();
                      },
                    ),
                  ),
                  _staggered(
                    index: 7,
                    child: _snakeItem(
                      context,
                      icon: Icons.settings,
                      color: AppThemes.kGreen,
                      title: 'App Settings',
                      subtitle: 'Themes, sound & language options',
                      onTap: () {
                        SoundService.playClick();
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
                    index: 8,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, top: 14, bottom: 6),
                      child: Row(
                        children: [
                          Container(width: 10, height: 1.5, color: AppThemes.kGreen),
                          const SizedBox(width: 6),
                          const Text(
                            'COMMUNITY',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(height: 0.8, color: Colors.white10),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _staggered(
                    index: 9,
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
                    index: 10,
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
                    index: 11,
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
                    index: 12,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, top: 14, bottom: 6),
                      child: Row(
                        children: [
                          Container(width: 10, height: 1.5, color: AppThemes.kNeonCyan),
                          const SizedBox(width: 6),
                          const Text(
                            'LEGAL & COMPLIANCE',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(height: 0.8, color: Colors.white10),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _staggered(
                    index: 13,
                    child: _snakeItem(
                      context,
                      icon: Icons.dashboard,
                      color: AppThemes.kNeonCyan,
                      title: 'Web Dashboard',
                      subtitle: 'Open www.mayajaal.online',
                      onTap: () {
                        Navigator.pop(context);
                        _launchURL('https://www.mayajaal.online/dashboard', inApp: false);
                      },
                    ),
                  ),
                  _staggered(
                    index: 14,
                    child: _snakeItem(
                      context,
                      icon: Icons.privacy_tip_outlined,
                      color: Colors.white70,
                      title: 'Privacy Policy',
                      subtitle: 'Security & user rights',
                      onTap: () {
                        Navigator.pop(context);
                        LegalPolicyDialog.showPolicy(context, 'privacy');
                      },
                    ),
                  ),
                  _staggered(
                    index: 15,
                    child: _snakeItem(
                      context,
                      icon: Icons.description_outlined,
                      color: Colors.white70,
                      title: 'Terms & Conditions',
                      subtitle: 'Operating guidelines',
                      onTap: () {
                        Navigator.pop(context);
                        LegalPolicyDialog.showPolicy(context, 'terms');
                      },
                    ),
                  ),
                  _staggered(
                    index: 16,
                    child: _snakeItem(
                      context,
                      icon: Icons.copyright_outlined,
                      color: const Color(0xFFFB7185),
                      title: 'DMCA Policy',
                      subtitle: '17 U.S.C. § 512 notice framework',
                      onTap: () {
                        Navigator.pop(context);
                        LegalPolicyDialog.showPolicy(context, 'dmca');
                      },
                    ),
                  ),
                  _staggered(
                    index: 17,
                    child: _snakeItem(
                      context,
                      icon: Icons.handshake_outlined,
                      color: AppThemes.kNeonCyan,
                      title: 'Creator Program Terms',
                      subtitle: 'Creator engagement & integrity',
                      onTap: () {
                        Navigator.pop(context);
                        LegalPolicyDialog.showPolicy(context, 'partner');
                      },
                    ),
                  ),
                  _staggered(
                    index: 18,
                    child: _snakeItem(
                      context,
                      icon: Icons.support_agent_outlined,
                      color: AppThemes.kGold,
                      title: 'Help & Support',
                      subtitle: '24/7 Creator Operations Desk',
                      onTap: () {
                        Navigator.pop(context);
                        LegalPolicyDialog.showPolicy(context, 'support');
                      },
                    ),
                  ),
                  _staggered(
                    index: 19,
                    child: _snakeItem(
                      context,
                      icon: Icons.info_outline,
                      color: AppThemes.kNeonCyan,
                      title: 'About MayaJaal',
                      subtitle: 'Version & platform info',
                      onTap: () {
                        Navigator.pop(context);
                        _showAboutDialog(context);
                      },
                    ),
                  ),
                  _staggered(
                    index: 20,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                          title: const Text(
                            'Logout Session',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
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
                  _staggered(
                    index: 21,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppThemes.kRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppThemes.kFireOrange.withOpacity(0.8), width: 1.5),
                          boxShadow: [
                            BoxShadow(color: AppThemes.kRed.withOpacity(0.2), blurRadius: 10, spreadRadius: 1),
                          ],
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.local_fire_department, color: AppThemes.kFireOrange, size: 22),
                          title: const Text(
                            'Delete My Account',
                            style: TextStyle(
                              color: AppThemes.kRed,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: const Text(
                            'Permanently erase all data & start fresh',
                            style: TextStyle(color: Colors.white54, fontSize: 9.5),
                          ),
                          onTap: () {
                            _showDeleteAccountDialog(context);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppThemes.kBorder),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 9.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 12),
        onTap: onTap,
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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
          ),
          padding: const EdgeInsets.all(4),
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => Icon(fallbackIcon, color: color, size: 18),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 9.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 12),
        onTap: onTap,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SNAKE BORDER PAINTER
// ═══════════════════════════════════════════════════════════════════════════════
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

// ═══════════════════════════════════════════════════════════════════════════════
// VIDEO METADATA RESOLVER (SIZE + AGE)
// ═══════════════════════════════════════════════════════════════════════════════
class VideoMetaResolver {
  static Future<Map<String, dynamic>> resolveMeta(String videoId) async {
    if (videoId.isEmpty) return {};
    try {
      final snap = await FirebaseDatabase.instance.ref('links/$videoId').once();
      final val = snap.snapshot.value;
      if (val == null || val is! Map) return {};
      final data = Map<String, dynamic>.from(val);

      int sizeBytes = 0;
      final rawSize = data['size'] ??
          data['fileSize'] ??
          data['file_size'] ??
          data['filesize'] ??
          data['bytes'] ??
          0;
      if (rawSize is num) {
        sizeBytes = rawSize.toInt();
      } else if (rawSize is String) {
        sizeBytes = int.tryParse(rawSize) ?? 0;
      }

      int createdAtMs = 0;
      final rawCreated = data['createdAt'] ??
          data['uploadedAt'] ??
          data['created_at'] ??
          data['timestamp'] ??
          data['uploadDate'] ??
          0;
      if (rawCreated is num) {
        createdAtMs = rawCreated.toInt();
      } else if (rawCreated is String) {
        createdAtMs = int.tryParse(rawCreated) ?? 0;
        if (createdAtMs == 0) {
          try {
            createdAtMs = DateTime.parse(rawCreated).millisecondsSinceEpoch;
          } catch (_) {}
        }
      }

      return {
        'sizeBytes': sizeBytes,
        'createdAt': createdAtMs,
      };
    } catch (_) {
      return {};
    }
  }

  static String formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String formatAge(int createdAtMs) {
    if (createdAtMs <= 0) return '';
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(createdAtMs),
    );
    final days = diff.inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return '1 day ago';
    if (days < 30) return '$days days ago';
    final months = (days / 30).floor();
    if (months < 12) return '$months ${months == 1 ? "month" : "months"} ago';
    final years = (days / 365).floor();
    return '$years ${years == 1 ? "year" : "years"} ago';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ⭐ STREAM PREVIEW SCREEN (PROFESSIONAL REBUILD + TERABOX SUPPORT)
// ═══════════════════════════════════════════════════════════════════════════════
class StreamPreviewScreen extends StatefulWidget {
  final String targetUrl;
  const StreamPreviewScreen({super.key, required this.targetUrl});
  @override
  State<StreamPreviewScreen> createState() => _StreamPreviewScreenState();
}

class _StreamPreviewScreenState extends State<StreamPreviewScreen>
    with TickerProviderStateMixin {
  String _streamUrl = '';
  String _videoTitle = 'MayaJaal Video';
  String _uploaderName = '@mayajaal';
  String _ownerUid = '';
  bool _isOwnerVerified = false;
  String _rawId = '';
  String _token = '';
  bool _isTeraBox = false;

  String _videoSize = '';
  String _videoAge = '';

  String _thumbnailUrl = '';
  String _capturedThumbB64 = '';

  int _countdown = 10;
  Timer? _countdownTimer;
  bool _isReadyToPlay = false;
  bool _isResolving = false;
  String _resolveError = '';

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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: AppThemes.kCardBg, content: Text('Please login to watch videos', style: TextStyle(color: AppThemes.kGreen))),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      });
      return;
    }

    _isTeraBox = TeraBoxResolver.isTeraBoxLink(widget.targetUrl);

    if (_isTeraBox) {
      _rawId = 'terabox_stream_${DateTime.now().millisecondsSinceEpoch}';
      _videoTitle = 'TeraBox Video';
      _startCountdown();
      _secureInitForTeraBox();
    } else {
      try {
        final uri = Uri.parse(widget.targetUrl);
        _rawId = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'stream';
        _token = uri.queryParameters['t'] ?? uri.queryParameters['s'] ?? '';
        _videoTitle = _rawId;
        _streamUrl = '$kBackendBaseUrl/stream/$_rawId';
      } catch (_) {
        _rawId = 'stream';
        _streamUrl = '$kBackendBaseUrl/stream/$_rawId';
      }
      _startCountdown();
      _secureInit();
    }
  }

  Future<void> _secureInitForTeraBox() async {
    setState(() {
      _isResolving = true;
      _resolveError = '';
    });

    final cachedThumb = await WatchHistory.getCachedThumbnail(widget.targetUrl);
    final cachedUrl = await WatchHistory.getCachedStreamUrl(widget.targetUrl);
    
    if (cachedUrl.isNotEmpty) {
       setState(() {
         _streamUrl = cachedUrl;
         _isResolving = false;
       });
       if (mounted) setState(() => _isReadyToPlay = true);
       return;
    }

    if (mounted && cachedThumb.isNotEmpty) {
      setState(() => _thumbnailUrl = cachedThumb);
    }

    final ok = await SecurityGuard.validateSession();
    if (!ok) {
      if (mounted) {
        await MayaJaalAccount.signOut();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
      return;
    }

    final result = await TeraBoxResolver.resolve(widget.targetUrl);
    
    if (mounted) {
      setState(() {
        _isResolving = false;
        if (result['success'] == 'true') {
          _streamUrl = result['videoUrl']!;
          if (result['fileName']!.isNotEmpty) {
            _videoTitle = Uri.decodeComponent(result['fileName']!);
          }
          if (result['thumbnail']!.isNotEmpty) {
            _thumbnailUrl = result['thumbnail']!;
          }
          _videoSize = 'Unknown';
          _videoAge = 'Just now';
        } else {
          _resolveError = 'Failed to resolve TeraBox link. It might be invalid or private.';
        }
      });
      
      if (result['success'] == 'true') {
         final prefs = await SharedPreferences.getInstance();
         final key = 'watch_history_v2_${MayaJaalAccount.cachedUid ?? 'guest'}';
         final raw = prefs.getString(key);
         List history = [];
         if (raw != null) {
           try { history = jsonDecode(raw); } catch(_) {}
         }
         history.removeWhere((h) => h['url'] == widget.targetUrl);
         history.insert(0, {
            'url': widget.targetUrl,
            'title': _videoTitle,
            'uploader': _uploaderName,
            'id': _rawId,
            'thumbnail': _thumbnailUrl,
            'streamUrl': _streamUrl,
            'size': _videoSize,
            'age': _videoAge,
            'time': DateTime.now().toIso8601String(),
         });
         if (history.length > 20) history = history.sublist(0, 20);
         await prefs.setString(key, jsonEncode(history));
         await WatchHistory.syncWatchRecordCloud(history[0]);
      }
    }
  }

  Future<void> _secureInit() async {
    final cachedThumb = await WatchHistory.getCachedThumbnail(widget.targetUrl);
    final cachedUrl = await WatchHistory.getCachedStreamUrl(widget.targetUrl);

    if (mounted) {
      setState(() {
        if (cachedThumb.isNotEmpty) _thumbnailUrl = cachedThumb;
        if (cachedUrl.isNotEmpty) _streamUrl = cachedUrl;
      });
    }

    final ok = await SecurityGuard.validateSession();
    if (!ok) {
      if (mounted) {
        await MayaJaalAccount.signOut();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
      return;
    }

    _fetchStreamMetadata();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdown = 10;
      _isReadyToPlay = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
          if (_countdown <= 3 && _countdown > 0) {
            SoundService.playClick();
            Haptic.light();
          }
        } else {
          SoundService.playAlert();
          Haptic.heavy();
          _countdownTimer?.cancel();
          setState(() => _isReadyToPlay = true);
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _snakeCtrl.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchStreamMetadata() async {
    bool apiSuccess = false;
    try {
      final apiUrl = _token.isNotEmpty
          ? '$kBackendBaseUrl/api/stream-info/$_rawId?t=$_token'
          : '$kBackendBaseUrl/api/stream-info/$_rawId';

      final deviceId = await DeviceIdHelper.get();
      final headers = SecurityGuard.signedHeaders(
        method: 'GET',
        path: '/api/stream-info/$_rawId',
        body: '',
        deviceId: deviceId,
        uid: MayaJaalAccount.cachedUid,
      );

      final res = await http.get(Uri.parse(apiUrl), headers: headers).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          String newUrl = (data['streamUrl'] ?? data['url'] ?? data['video_url'] ?? '').toString();

          if (newUrl.startsWith('https://mayajaal.online')) {
            newUrl = newUrl.replaceFirst('https://mayajaal.online', kBackendBaseUrl);
          }
          if (newUrl.isEmpty) {
            newUrl = '$kBackendBaseUrl/stream/$_rawId';
          }

          String apiTitle = (data['title'] ?? '').toString().trim();
          String apiFilename = (data['filename'] ?? '').toString().trim();
          String apiFileName = (data['file_name'] ?? '').toString().trim();
          String resolvedTitle = '';
          if (apiTitle.isNotEmpty && apiTitle != 'null') {
            resolvedTitle = apiTitle;
          } else if (apiFilename.isNotEmpty && apiFilename != 'null') {
            resolvedTitle = apiFilename;
          } else if (apiFileName.isNotEmpty && apiFileName != 'null') {
            resolvedTitle = apiFileName;
          }

          if (mounted) {
            setState(() {
              _streamUrl = newUrl;
              if (resolvedTitle.isNotEmpty) _videoTitle = resolvedTitle;
              _uploaderName = data['uploader'] ?? _uploaderName;
              final apiThumb = data['thumbnailUrl'] ?? data['thumbnail'] ?? data['poster'] ?? '';
              if (apiThumb.toString().isNotEmpty) {
                _thumbnailUrl = apiThumb.toString();
              }
            });
          }

          await _saveStreamUrlToCache(_streamUrl);
          apiSuccess = true;

          if (VideoNameResolver.isBadTitle(_videoTitle, _rawId)) {
            final real = await VideoNameResolver.resolve(_rawId);
            if (real.isNotEmpty && mounted) {
              setState(() => _videoTitle = real);
            }
          }
        }
      }
    } catch (_) {}

    if (!apiSuccess) {
      final real = await VideoNameResolver.resolve(_rawId);
      if (real.isNotEmpty && mounted) {
        setState(() => _videoTitle = real);
      }
    } else if (VideoNameResolver.isBadTitle(_videoTitle, _rawId)) {
      final real = await VideoNameResolver.resolve(_rawId);
      if (real.isNotEmpty && mounted) {
        setState(() => _videoTitle = real);
      }
    }

    final ownerData = await VideoOwnerResolver.resolve(_rawId);
    if (ownerData.isNotEmpty && mounted) {
      setState(() {
        _uploaderName = ownerData['display'] ?? _uploaderName;
        _ownerUid = ownerData['uid'] ?? '';
        _isOwnerVerified = (ownerData['name'] ?? '').isNotEmpty && _ownerUid.isNotEmpty;
      });
    }

    try {
      final meta = await VideoMetaResolver.resolveMeta(_rawId);
      if (meta.isNotEmpty && mounted) {
        final sizeBytes = (meta['sizeBytes'] ?? 0) as int;
        final createdAt = (meta['createdAt'] ?? 0) as int;
        setState(() {
          if (sizeBytes > 0) {
            _videoSize = VideoMetaResolver.formatSize(sizeBytes);
          }
          if (createdAt > 0) {
            _videoAge = VideoMetaResolver.formatAge(createdAt);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _saveStreamUrlToCache(String streamUrl) async {
    if (streamUrl.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'watch_history_v2_${MayaJaalAccount.cachedUid ?? 'guest'}';
      final raw = prefs.getString(key);
      if (raw == null) return;
      final List decoded = jsonDecode(raw);
      bool updated = false;
      for (final item in decoded) {
        if (item is Map && item['url'] == widget.targetUrl) {
          item['streamUrl'] = streamUrl;
          updated = true;
        }
      }
      if (updated) {
        await prefs.setString(key, jsonEncode(decoded));
      }
    } catch (_) {}
  }

  void _shareStreamDirect() {
    SoundService.playClick();
    Haptic.light();
    Share.share('🚀 Watch this stream on MayaJaal:\n${widget.targetUrl}');
  }

  Future<void> _saveWatchRecord() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'watch_history_v2_${MayaJaalAccount.cachedUid ?? 'guest'}';
    final localJson = prefs.getString(key);
    List<Map<String, dynamic>> history = [];
    if (localJson != null) {
      try {
        final List decoded = jsonDecode(localJson);
        history = decoded.cast<Map<String, dynamic>>();
      } catch (_) {}
    }

    String finalThumb = _thumbnailUrl;
    if (finalThumb.isEmpty && _capturedThumbB64.isNotEmpty) {
      finalThumb = _capturedThumbB64;
    }
    if (finalThumb.isEmpty) {
      final existing = await WatchHistory.getCachedThumbnail(widget.targetUrl);
      if (existing.isNotEmpty) finalThumb = existing;
    }

    String finalStreamUrl = _streamUrl;
    if (finalStreamUrl.isEmpty) {
      finalStreamUrl = await WatchHistory.getCachedStreamUrl(widget.targetUrl);
    }

    final item = {
      'url': widget.targetUrl,
      'title': _videoTitle,
      'uploader': _uploaderName,
      'id': _rawId,
      'thumbnail': finalThumb,
      'streamUrl': finalStreamUrl,
      'size': _videoSize,
      'age': _videoAge,
      'time': DateTime.now().toIso8601String(),
    };

    history.removeWhere((h) => h['url'] == widget.targetUrl);
    history.insert(0, item);

    if (history.length > 20) {
      history = history.sublist(0, 20);
    }

    await prefs.setString(key, jsonEncode(history));
    await WatchHistory.syncWatchRecordCloud(item);
  }

  void _launchNativePlayer() {
    if (_resolveError.isNotEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppThemes.kCardBg, content: Text(_resolveError, style: const TextStyle(color: AppThemes.kRed))),
       );
       return;
    }
    
    if (_streamUrl.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: AppThemes.kCardBg, content: Text('Video URL not ready yet. Please wait.', style: TextStyle(color: AppThemes.kGold))),
       );
       return;
    }

    SoundService.playClick();
    _saveWatchRecord();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NativeVideoPlayerScreen(
          videoUrl: _streamUrl,
          title: _videoTitle,
          uploader: _uploaderName,
          sourcePageUrl: widget.targetUrl,
          videoId: _rawId,
          thumbnailUrl: _thumbnailUrl.isNotEmpty ? _thumbnailUrl : _capturedThumbB64,
        ),
      ),
    ).then((_) {
      if (mounted) {
        _startCountdown();
      }
    });
  }

  void _goToHome() {
    SoundService.playClick();
    Haptic.heavy();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationHolder()),
      (route) => false,
    );
  }

  Widget _buildProfessionalCountdown() {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            color: Colors.black.withOpacity(0.4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: CircularProgressIndicator(
                          value: 1.0 - (_countdown / 10.0),
                          strokeWidth: 4,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppThemes.kNeonCyan),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$_countdown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              shadows: [Shadow(color: AppThemes.kNeonCyan, blurRadius: 10)],
                            ),
                          ),
                          const Text(
                            'SEC',
                            style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppThemes.kNeonCyan.withOpacity(0.5), width: 1),
                    boxShadow: [
                      BoxShadow(color: AppThemes.kNeonCyan.withOpacity(0.2), blurRadius: 15, spreadRadius: 2),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(color: AppThemes.kNeonCyan, strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _countdown > 3 ? 'PREPARING STREAM' : 'ALMOST READY',
                        style: const TextStyle(
                          color: AppThemes.kNeonCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
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
            height: 58,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(29),
              boxShadow: [BoxShadow(color: AppThemes.kRed.withOpacity(0.4), blurRadius: 18)],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: SnakeBorderPainter(progress: _snakeCtrl.value, color: AppThemes.kRed)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.play_arrow_rounded, color: AppThemes.kRed, size: 30),
                    SizedBox(width: 8),
                    Text(
                      'PLAY NOW',
                      style: TextStyle(color: AppThemes.kRed, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2.0),
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
    return Scaffold(
      backgroundColor: AppThemes.kBg,
      body: Stack(
        children: [
          const MatrixRain(opacity: 0.25),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _goToHome,
                      icon: const Icon(Icons.home, color: Colors.white54, size: 18),
                      label: const Text('GO TO HOME PAGE', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppThemes.kBorder, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: AppThemes.kGreen, size: 18),
                        onPressed: () {
                          SoundService.playClick();
                          Haptic.light();
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppThemes.kGreen, width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.asset(
                            'assets/icon/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(
                              Icons.change_history,
                              color: AppThemes.kGreen,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Maya',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                      const Text(
                        'Jaal',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppThemes.kGreen,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppThemes.kBorder)),
                        child: const Icon(Icons.verified_user_rounded, color: AppThemes.kGreen, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppThemes.kCardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _isReadyToPlay ? AppThemes.kGreen : AppThemes.kNeonCyan.withOpacity(0.5), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: (_isReadyToPlay ? AppThemes.kGreen : AppThemes.kNeonCyan).withOpacity(0.1), blurRadius: 20)
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          alignment: Alignment.center,
                          children: [
                            if (_isResolving)
                               const Center(child: ProfessionalLoader(message: 'RESOLVING TERABOX...'))
                            else if (_resolveError.isNotEmpty)
                               Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(_resolveError, textAlign: TextAlign.center, style: const TextStyle(color: AppThemes.kRed, fontSize: 12)),
                                  ),
                               )
                            else
                               buildMediaThumbnail(
                                 _thumbnailUrl.isNotEmpty ? _thumbnailUrl : null,
                                 _videoTitle,
                                 _streamUrl,
                                 onFrameCaptured: (b64) {
                                   if (!mounted) return;
                                   if (_capturedThumbB64.isEmpty) {
                                     setState(() => _capturedThumbB64 = b64);
                                   }
                                 },
                               ),
                            if (!_isReadyToPlay && !_isResolving && _resolveError.isEmpty) _buildProfessionalCountdown(),
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppThemes.kGreen, width: 0.8)),
                                child: const Text('HD', style: TextStyle(color: AppThemes.kGreen, fontSize: 8.5, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_isReadyToPlay && !_isResolving && _resolveError.isEmpty)
                    _buildRedSnakePlayButton()
                  else if (!_isResolving && _resolveError.isEmpty)
                    Container(
                      width: double.infinity,
                      height: 58,
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(29)),
                      child: Center(
                        child: Text(
                          'PLEASE WAIT $_countdown SEC...',
                          style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                      ),
                    ),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppThemes.kCardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppThemes.kBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black, border: Border.all(color: AppThemes.kBorder)),
                              child: const Icon(Icons.video_collection_outlined, color: AppThemes.kGreen, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('FILE NAME', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 8.5, letterSpacing: 0.8)),
                                  const SizedBox(height: 1),
                                  Text(_videoTitle, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(color: Colors.white10, height: 1),
                        ),

                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black, border: Border.all(color: AppThemes.kBorder)),
                                    child: const Icon(Icons.person_outline, color: AppThemes.kGreen, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('UPLOADER', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 8.5, letterSpacing: 0.8)),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                _uploaderName,
                                                style: const TextStyle(color: AppThemes.kGreen, fontSize: 12, fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (_isOwnerVerified) ...[
                                              const SizedBox(width: 4),
                                              const Icon(Icons.verified, color: AppThemes.kGreen, size: 13),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            Container(
                              height: 35,
                              width: 1,
                              color: Colors.white10,
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                            ),

                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black, border: Border.all(color: AppThemes.kBorder)),
                                    child: const Icon(Icons.sd_storage_outlined, color: AppThemes.kNeonCyan, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('FILE SIZE', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 8.5, letterSpacing: 0.8)),
                                        const SizedBox(height: 2),
                                        Text(
                                          _videoSize.isNotEmpty ? _videoSize : 'N/A',
                                          style: const TextStyle(color: AppThemes.kNeonCyan, fontSize: 12, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        if (_videoAge.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Divider(color: Colors.white10, height: 1),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black, border: Border.all(color: AppThemes.kBorder)),
                                child: const Icon(Icons.calendar_today_outlined, color: AppThemes.kGold, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('UPLOADED', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 8.5, letterSpacing: 0.8)),
                                    const SizedBox(height: 1),
                                    Text(_videoAge, style: const TextStyle(color: AppThemes.kGold, fontSize: 12.5, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: _shareStreamDirect,
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppThemes.kBorder, width: 1.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.share, color: AppThemes.kGreen, size: 18),
                          SizedBox(width: 8),
                          Text('SHARE VIDEO', style: TextStyle(color: AppThemes.kGreen, fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHANNEL SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class ChannelScreen extends StatelessWidget {
  const ChannelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.kBg,
      appBar: AppBar(title: const Text('CHANNELS & NODES')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppThemes.kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemes.kBorder),
            ),
            child: const ListTile(
              leading: Icon(Icons.bolt, color: AppThemes.kGreen, size: 28),
              title: Text(
                'Quantum Streaming Node',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Text(
                'Direct hardware pipeline active',
                style: TextStyle(color: AppThemes.kDimGreen, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppThemes.kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemes.kBorder),
            ),
            child: const ListTile(
              leading: Icon(Icons.cloud_done, color: AppThemes.kNeonCyan, size: 28),
              title: Text(
                'High Speed CDN Node',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Text(
                'Buffer acceleration: ENABLED',
                style: TextStyle(color: AppThemes.kNeonCyan, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppThemes.kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemes.kBorder),
            ),
            child: const ListTile(
              leading: Icon(Icons.security, color: AppThemes.kNeonPurple, size: 28),
              title: Text(
                'Encrypted Pipeline',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Text(
                'AES-256 quantum cipher: ACTIVE',
                style: TextStyle(color: AppThemes.kNeonPurple, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GALLERY SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
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
      backgroundColor: AppThemes.kBg,
      appBar: AppBar(
        title: const Text('GALLERY'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppThemes.kGreen),
            onPressed: () {
              SoundService.playClick();
              Haptic.light();
              setState(() => _loading = true);
              _loadGallery();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppThemes.kGreen))
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
            const Icon(Icons.photo_library_outlined, color: AppThemes.kGreen, size: 70),
            const SizedBox(height: 14),
            const Text(
              'GALLERY PERMISSION NEEDED',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please allow gallery access to view photos and videos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                SoundService.playClick();
                PhotoManager.openSetting();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemes.kGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('OPEN SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
          Icon(Icons.photo_library_outlined, color: Colors.white24, size: 60),
          const SizedBox(height: 10),
          Text(
            'No ${_selectedTab == 'videos' ? 'videos' : _selectedTab == 'images' ? 'photos' : 'media'} found',
            style: const TextStyle(color: Colors.white54, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppThemes.kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemes.kBorder),
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
          SoundService.playClick();
          Haptic.selection();
          setState(() => _selectedTab = key);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.black54 : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: active ? Border.all(color: AppThemes.kGreen.withOpacity(0.6), width: 1.0) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: active ? AppThemes.kGreen : Colors.white38, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
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
        SoundService.playClick();
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
              thumbnailSize: const ThumbnailSize.square(250),
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                color: AppThemes.kCardBg,
                child: const Icon(Icons.broken_image, color: Colors.white24),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppThemes.kBorder, width: 0.8),
              ),
            ),
          ),
          if (isVideo)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppThemes.kBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow, color: AppThemes.kGreen, size: 9),
                    const SizedBox(width: 2),
                    Text(
                      _formatDuration(asset.duration),
                      style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
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
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 4,
                child: AssetEntityImage(
                  asset,
                  isOriginal: true,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.white24, size: 50),
                ),
              ),
            ),
            Positioned(
              top: 36,
              right: 18,
              child: GestureDetector(
                onTap: () {
                  SoundService.playClick();
                  Navigator.pop(c);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppThemes.kBorder),
                  ),
                  child: const Icon(Icons.close, color: Colors.white70, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SAVED VIDEOS SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class SavedVideosScreen extends StatefulWidget {
  const SavedVideosScreen({super.key});
  @override
  State<SavedVideosScreen> createState() => _SavedVideosScreenState();
}

class _SavedVideosScreenState extends State<SavedVideosScreen> {
  List<Map<String, dynamic>> _saved = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final uid = MayaJaalAccount.cachedUid;
    final prefs = await SharedPreferences.getInstance();
    final key = 'saved_videos_v1_${uid ?? 'guest'}';
    final jsonStr = prefs.getString(key);

    if (jsonStr != null) {
      try {
        final List decoded = jsonDecode(jsonStr);
        if (mounted) {
          setState(() {
            _saved = decoded.cast<Map<String, dynamic>>();
            _loading = false;
          });
        }
      } catch (_) {}
    }

    if (uid != null && uid != 'guest') {
      try {
        final snap = await FirebaseDatabase.instance.ref('users/$uid/savedVideos').once();
        if (snap.snapshot.value != null && snap.snapshot.value is Map) {
          final map = Map<String, dynamic>.from(snap.snapshot.value as Map);
          final cloudList = map.values.map((v) => Map<String, dynamic>.from(v as Map)).toList();
          cloudList.sort((a, b) => (b['savedAt'] ?? 0).compareTo(a['savedAt'] ?? 0));
          if (mounted) {
            setState(() {
              _saved = cloudList;
              _loading = false;
            });
            await prefs.setString(key, jsonEncode(_saved));

            await WatchHistory.repairBadTitles(history: [], saved: _saved);
            if (mounted) setState(() {});
          }
          return;
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _loading = false);

    if (_saved.isNotEmpty) {
      await WatchHistory.repairBadTitles(history: [], saved: _saved);
      if (mounted) setState(() {});
    }
  }

  Future<void> _removeSaved(int index) async {
    SoundService.playClick();
    Haptic.light();
    final item = _saved[index];
    final uid = MayaJaalAccount.cachedUid;
    final prefs = await SharedPreferences.getInstance();
    final key = 'saved_videos_v1_${uid ?? 'guest'}';

    setState(() => _saved.removeAt(index));
    await prefs.setString(key, jsonEncode(_saved));
    await WatchHistory.syncSavedRecordCloud(item, false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.kBg,
      appBar: AppBar(title: const Text('SAVED VIDEOS')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppThemes.kGreen))
          : _saved.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border, size: 50, color: Colors.white24),
                      const SizedBox(height: 10),
                      const Text('No saved videos yet', style: TextStyle(color: Colors.white38, fontSize: 12.5)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  itemCount: _saved.length,
                  itemBuilder: (c, i) {
                    final item = _saved[i];
                    final thumb = item['thumbnail']?.toString() ?? '';
                    String title = item['title']?.toString().trim() ?? '';
                    if (title.isEmpty || title == 'null') {
                      title = item['id']?.toString() ?? 'MayaJaal Video';
                    }
                    final url = item['url']?.toString() ?? '';
                    final streamUrl = item['streamUrl']?.toString() ?? '';
                    final id = item['id']?.toString() ?? '';

                    final thumbStreamUrl = streamUrl.isNotEmpty
                        ? streamUrl
                        : (id.isNotEmpty ? '$kBackendBaseUrl/stream/$id' : url);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppThemes.kCardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppThemes.kBorder),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppThemes.kBorder),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: buildMediaThumbnail(
                              thumb,
                              title,
                              thumbStreamUrl,
                              isSmall: true,
                              onFrameCaptured: (b64) async {
                                await WatchHistory.saveThumbnail(url, b64);
                                if (mounted) _loadSaved();
                              },
                            ),
                          ),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'By: ${item['uploader'] ?? 'Node'}',
                          style: const TextStyle(fontSize: 10.5, color: Colors.white38),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                          onPressed: () => _removeSaved(i),
                        ),
                        onTap: () {
                          SoundService.playClick();
                          Haptic.light();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StreamPreviewScreen(targetUrl: url),
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

// ═══════════════════════════════════════════════════════════════════════════════
// HISTORY SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final uid = MayaJaalAccount.cachedUid;
    final prefs = await SharedPreferences.getInstance();
    final key = 'watch_history_v2_${uid ?? 'guest'}';
    final localJson = prefs.getString(key);

    if (localJson != null) {
      try {
        final List decoded = jsonDecode(localJson);
        if (mounted) {
          setState(() {
            _history = decoded.cast<Map<String, dynamic>>();
            _loading = false;
          });
        }
      } catch (_) {}
    }

    if (uid != null && uid != 'guest') {
      try {
        final snap = await FirebaseDatabase.instance.ref('users/$uid/watchHistory').limitToLast(30).once();
        if (snap.snapshot.value != null && snap.snapshot.value is Map) {
          final map = Map<String, dynamic>.from(snap.snapshot.value as Map);
          final cloudList = map.values.map((v) => Map<String, dynamic>.from(v as Map)).toList();
          cloudList.sort((a, b) => (b['syncedAt'] ?? 0).compareTo(a['syncedAt'] ?? 0));
          if (mounted) {
            setState(() {
              _history = cloudList;
              _loading = false;
            });
            await prefs.setString(key, jsonEncode(_history));

            await WatchHistory.repairBadTitles(history: _history, saved: []);
            if (mounted) setState(() {});
          }
          return;
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _loading = false);

    if (_history.isNotEmpty) {
      await WatchHistory.repairBadTitles(history: _history, saved: []);
      if (mounted) setState(() {});
    }
  }

  Future<void> _deleteItem(int index) async {
    SoundService.playClick();
    Haptic.light();
    final item = _history[index];
    final uid = MayaJaalAccount.cachedUid;
    final prefs = await SharedPreferences.getInstance();
    final key = 'watch_history_v2_${uid ?? 'guest'}';

    setState(() => _history.removeAt(index));
    await prefs.setString(key, jsonEncode(_history));

    if (uid != null && uid != 'guest') {
      final safeKey = (item['id'] ?? '').toString();
      if (safeKey.isNotEmpty) {
        await FirebaseDatabase.instance.ref('users/$uid/watchHistory/$safeKey').remove();
      }
    }
  }

  Future<void> _clearAll() async {
    SoundService.playClick();
    Haptic.medium();
    final uid = MayaJaalAccount.cachedUid;
    final prefs = await SharedPreferences.getInstance();
    final key = 'watch_history_v2_${uid ?? 'guest'}';

    await prefs.remove(key);
    setState(() => _history = []);

    if (uid != null && uid != 'guest') {
      await FirebaseDatabase.instance.ref('users/$uid/watchHistory').remove();
    }
  }

  Future<void> _saveItem(Map<String, dynamic> item) async {
    SoundService.playClick();
    Haptic.medium();
    final uid = MayaJaalAccount.cachedUid;
    final prefs = await SharedPreferences.getInstance();
    final key = 'saved_videos_v1_${uid ?? 'guest'}';
    final savedStr = prefs.getString(key);
    List<Map<String, dynamic>> savedList = [];
    if (savedStr != null) {
      try {
        savedList = (jsonDecode(savedStr) as List).cast<Map<String, dynamic>>();
      } catch (_) {}
    }

    if (savedList.any((s) => s['url'] == item['url'])) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: AppThemes.kCardBg, content: Text('Already saved!', style: TextStyle(color: AppThemes.kGreen))),
        );
      }
      return;
    }

    savedList.insert(0, item);
    await prefs.setString(key, jsonEncode(savedList));
    await WatchHistory.syncSavedRecordCloud(item, true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: AppThemes.kCardBg, content: Text('✅ Video Saved to Cloud!', style: TextStyle(color: AppThemes.kGreen))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.kBg,
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
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppThemes.kGreen))
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 50, color: Colors.white24),
                      const SizedBox(height: 10),
                      Text(tr('no_history'), style: const TextStyle(color: Colors.white38, fontSize: 12.5)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  itemCount: _history.length,
                  itemBuilder: (c, i) {
                    final item = _history[i];
                    final thumb = item['thumbnail']?.toString() ?? '';
                    String title = item['title']?.toString().trim() ?? '';
                    if (title.isEmpty || title == 'null') {
                      title = item['id']?.toString() ?? 'MayaJaal Video';
                    }
                    final url = item['url']?.toString() ?? '';
                    final streamUrl = item['streamUrl']?.toString() ?? '';
                    final id = item['id']?.toString() ?? '';

                    final thumbStreamUrl = streamUrl.isNotEmpty
                        ? streamUrl
                        : (id.isNotEmpty ? '$kBackendBaseUrl/stream/$id' : url);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppThemes.kCardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppThemes.kBorder),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppThemes.kBorder),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: buildMediaThumbnail(
                              thumb,
                              title,
                              thumbStreamUrl,
                              isSmall: true,
                              onFrameCaptured: (b64) async {
                                await WatchHistory.saveThumbnail(url, b64);
                                if (mounted) _loadHistory();
                              },
                            ),
                          ),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'By: ${item['uploader'] ?? 'Node'}',
                          style: const TextStyle(fontSize: 10.5, color: Colors.white38),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.bookmark_add_outlined, size: 18, color: AppThemes.kNeonCyan),
                              onPressed: () => _saveItem(item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                              onPressed: () => _deleteItem(i),
                            ),
                          ],
                        ),
                        onTap: () {
                          SoundService.playClick();
                          Haptic.light();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StreamPreviewScreen(targetUrl: url),
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

// ═══════════════════════════════════════════════════════════════════════════════
// SETTINGS SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentTheme = 'Cyber Emerald';
  String _language = 'English';
  String _downloadLocation = 'Internal Storage / Mayajaall';
  bool _soundEnabled = true;

  final List<String> _themes = [
    'Cyber Emerald',
    'Quantum Blue',
    'Neon Violet',
    'Obsidian Stealth'
  ];

  final List<String> _languages = ['English', 'Hindi', 'Bengali', 'Tamil', 'Telugu'];
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
      _currentTheme = prefs.getString('app_theme') ?? 'Cyber Emerald';
      _language = prefs.getString('language') ?? 'English';
      _downloadLocation = prefs.getString('download_location') ?? 'Internal Storage / Mayajaall';
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    });
  }

  Future<void> _saveAllSettings() async {
    SoundService.playClick();
    Haptic.medium();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', _currentTheme);
    await prefs.setString('language', _language);
    await prefs.setString('download_location', _downloadLocation);
    await prefs.setBool('sound_enabled', _soundEnabled);

    themeNotifier.value = _currentTheme;
    languageNotifier.value = _language;
    soundEnabledNotifier.value = _soundEnabled;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppThemes.kCardBg,
          content: Text('✅ Settings Saved Successfully!', style: TextStyle(color: AppThemes.kGreen)),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.kBg,
      appBar: AppBar(title: Text(tr('settings'))),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: [
          ListTile(
            leading: const Icon(Icons.volume_up, color: AppThemes.kGreen, size: 20),
            title: Text(tr('sound_effects'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text(
              _soundEnabled ? 'Enabled' : 'Muted',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            trailing: Switch(
              value: _soundEnabled,
              activeColor: AppThemes.kGreen,
              onChanged: (val) {
                SoundService.playClick();
                setState(() => _soundEnabled = val);
                soundEnabledNotifier.value = val;
              },
            ),
          ),
          Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.palette_outlined, color: AppThemes.kNeonCyan, size: 20),
            title: Text(tr('dark_theme'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text(_currentTheme, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white24),
            onTap: _showThemeDialog,
          ),
          Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.language, color: AppThemes.kGreen, size: 20),
            title: Text(tr('language'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text(_language, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white24),
            onTap: _showLanguageDialog,
          ),
          Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.download, color: AppThemes.kGold, size: 20),
            title: Text(tr('download_location'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text(_downloadLocation, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white24),
            onTap: _showDownloadLocationDialog,
          ),
          Divider(color: Colors.white10),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppThemes.kCardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppThemes.kBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield, color: AppThemes.kGreen, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Security Integrity',
                        style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Gmail-only · TLS 1.3 Encrypted · Verified',
                        style: TextStyle(color: Colors.white38, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saveAllSettings,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(
                  tr('save_changes'),
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemes.kGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '> MayaJaal v1.3.0 // Quantum Build',
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog() {
    SoundService.playClick();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppThemes.kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppThemes.kBorder)),
        title: Text(tr('dark_theme'), style: const TextStyle(color: Colors.white, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _themes.map((t) {
            return RadioListTile<String>(
              title: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              value: t,
              groupValue: _currentTheme,
              activeColor: AppThemes.kGreen,
              onChanged: (val) {
                if (val != null) {
                  SoundService.playClick();
                  setState(() => _currentTheme = val);
                  themeNotifier.value = val;
                  Navigator.pop(c);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    SoundService.playClick();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppThemes.kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppThemes.kBorder)),
        title: Text(tr('language'), style: const TextStyle(color: Colors.white, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _languages.map((l) {
            return RadioListTile<String>(
              title: Text(l, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              value: l,
              groupValue: _language,
              activeColor: AppThemes.kGreen,
              onChanged: (val) {
                if (val != null) {
                  SoundService.playClick();
                  setState(() => _language = val);
                  languageNotifier.value = val;
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
    SoundService.playClick();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppThemes.kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppThemes.kBorder)),
        title: Text(tr('download_location'), style: const TextStyle(color: Colors.white, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _downloadLocations.map((loc) {
            return RadioListTile<String>(
              title: Text(loc, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              value: loc,
              groupValue: _downloadLocation,
              activeColor: AppThemes.kGreen,
              onChanged: (val) {
                if (val != null) {
                  SoundService.playClick();
                  setState(() => _downloadLocation = val);
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

// ═══════════════════════════════════════════════════════════════════════════════
// NATIVE VIDEO PLAYER SCREEN (With Better Player for TeraBox)
// ═══════════════════════════════════════════════════════════════════════════════
class NativeVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String uploader;
  final String sourcePageUrl;
  final String videoId;
  final String thumbnailUrl;

  const NativeVideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.uploader,
    required this.sourcePageUrl,
    required this.videoId,
    this.thumbnailUrl = '',
  });

  @override
  State<NativeVideoPlayerScreen> createState() => _NativeVideoPlayerScreenState();
}

class _NativeVideoPlayerScreenState extends State<NativeVideoPlayerScreen> {
  BetterPlayerController? _betterPlayerController;
  final GlobalKey _videoKey = GlobalKey();

  bool _isInitialized = false;
  bool _hasError = false;

  bool _isFullscreen = false;
  bool _isZoomed = false;

  String _videoSize = '';
  String _videoAge = '';

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
    _fetchVideoMeta();
  }

  Future<void> _fetchVideoMeta() async {
    try {
      final meta = await VideoMetaResolver.resolveMeta(widget.videoId);
      if (meta.isNotEmpty && mounted) {
        final sizeBytes = (meta['sizeBytes'] ?? 0) as int;
        final createdAt = (meta['createdAt'] ?? 0) as int;
        setState(() {
          if (sizeBytes > 0) {
            _videoSize = VideoMetaResolver.formatSize(sizeBytes);
          }
          if (createdAt > 0) {
            _videoAge = VideoMetaResolver.formatAge(createdAt);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _captureThumbnail() async {
    if (widget.thumbnailUrl.isNotEmpty) return;
    try {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_isInitialized) return;

      final ctx = _videoKey.currentContext;
      if (ctx == null) return;
      final boundary = ctx.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return;

      final image = await boundary.toImage(pixelRatio: 0.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final base64String = base64Encode(bytes);

      await WatchHistory.saveThumbnail(widget.sourcePageUrl, base64String);
    } catch (_) {}
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

      final body = jsonEncode({
        'playedSeconds': _watchedSeconds,
        'deviceId': deviceId,
        'token': token,
      });

      final headers = SecurityGuard.signedHeaders(
        method: 'POST',
        path: '/api/view/${widget.videoId}',
        body: body,
        deviceId: deviceId,
        uid: MayaJaalAccount.cachedUid,
      );

      await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 10));
      debugPrint('✅ Qualified 10s View Reported to Server');
    } catch (e) {
      debugPrint('View report error: $e');
    }
  }

  void _startWatchTracking() {
    _watchTimer?.cancel();
    _watchTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_betterPlayerController != null &&
          (_betterPlayerController!.isPlaying() ?? false) && // 🔥 Null Safety Fixed
          _watchedSeconds < 10) {
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
      if (mounted) {
        setState(() => _isLiked = liked);
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('liked_${uid}_${widget.videoId}', liked);
        });
      }
    });

    _unlikeSub = FirebaseService.isUnlikedStream(widget.videoId, uid).listen((unliked) {
      if (mounted) {
        setState(() => _isUnliked = unliked);
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('unliked_${uid}_${widget.videoId}', unliked);
        });
      }
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
      final uid = MayaJaalAccount.cachedUid;
      if (uid != null) {
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _isSaved = prefs.getBool('saved_${uid}_${widget.videoId}') ?? false;
          _isLiked = prefs.getBool('liked_${uid}_${widget.videoId}') ?? false;
          _isUnliked = prefs.getBool('unliked_${uid}_${widget.videoId}') ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _initVideo() async {
    String realVideoUrl = widget.videoUrl.trim();

    if (realVideoUrl.isEmpty || !realVideoUrl.startsWith('http')) {
      realVideoUrl = '$kBackendBaseUrl/stream/${widget.videoId}';
    }

    if (realVideoUrl.startsWith('https://mayajaal.online')) {
      realVideoUrl = realVideoUrl.replaceFirst('https://mayajaal.online', kBackendBaseUrl);
    }

    debugPrint('🎬 Initializing BetterPlayer with URL: $realVideoUrl');

    final isHls = realVideoUrl.contains('.m3u8');

    final config = BetterPlayerConfiguration(
      autoPlay: true,
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      errorBuilder: (context, errorMessage) {
        setState(() => _hasError = true);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
              const SizedBox(height: 8),
              const Text('Stream Connection Error', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              TextButton(onPressed: _initVideo, child: const Text('RETRY', style: TextStyle(color: AppThemes.kGreen))),
            ],
          ),
        );
      },
    );

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      realVideoUrl,
      videoFormat: isHls ? BetterPlayerVideoFormat.hls : BetterPlayerVideoFormat.other,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Cookie': TeraBoxResolver.kTeraBoxCookie,
        'Referer': 'https://www.terabox.com/',
        'Accept': '*/*',
        'Accept-Encoding': 'identity',
        'Connection': 'keep-alive',
      },
    );

    try {
      _betterPlayerController = BetterPlayerController(config, betterPlayerDataSource: dataSource);
      _betterPlayerController!.addEventsListener((event) {
        if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
          if (mounted) {
            setState(() => _isInitialized = true);
            _resetControlTimer();
            _startWatchTracking();
            _captureThumbnail();
          }
        }
      });
    } catch (e) {
      debugPrint('❌ BetterPlayer Error: $e');
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
    _betterPlayerController?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _resetControlTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _betterPlayerController != null && (_betterPlayerController!.isPlaying() ?? false)) { // 🔥 Null Safety Fixed
        setState(() => _showControls = false);
      }
    });
  }

  void _onScreenTapped() {
    SoundService.playClick();
    Haptic.light();
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetControlTimer();
  }

  void _showFeedback(String text) {
    _feedbackTimer?.cancel();
    setState(() => _flashFeedback = text);
    _feedbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _flashFeedback = '');
    });
  }

  void _onLongPressStart() {
    Haptic.light();
    setState(() {
      _isLongPressBoost = true;
      _betterPlayerController?.setSpeed(2.0);
    });
    _showFeedback('▶▶ 2x');
  }

  void _onLongPressEnd() {
    if (_isLongPressBoost) {
      _betterPlayerController?.setSpeed(_playbackSpeed);
      setState(() => _isLongPressBoost = false);
      _resetControlTimer();
    }
  }

  void _onDoubleTap(TapDownDetails details, double width) {
    final dx = details.localPosition.dx;
    if (dx < width * 0.35) {
      _seekRelative(-10);
    } else if (dx > width * 0.65) {
      _seekRelative(10);
    } else {
      SoundService.playClick();
      if (_betterPlayerController != null) {
        if (_betterPlayerController!.isPlaying() ?? false) { // 🔥 Null Safety Fixed
          _betterPlayerController!.pause();
        } else {
          _betterPlayerController!.play();
        }
      }
      Haptic.light();
      _resetControlTimer();
    }
  }

  void _seekRelative(int seconds) {
    SoundService.playClick();
    Haptic.medium();
    if (_betterPlayerController != null) {
      final currentPos = _betterPlayerController!.videoPlayerController?.value.position ?? Duration.zero;
      final newPos = currentPos + Duration(seconds: seconds);
      final clamped = newPos < Duration.zero ? Duration.zero : newPos;
      _betterPlayerController!.seekTo(clamped);
      _showFeedback(seconds > 0 ? '+${seconds}s' : '${seconds}s');
    }
    _resetControlTimer();
  }

  void _toggleSmartFullscreen() {
    SoundService.playClick();
    Haptic.light();
    setState(() => _isFullscreen = !_isFullscreen);

    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      final isWide = (_betterPlayerController?.videoPlayerController?.value.aspectRatio ?? 1.0) >= 1.2;
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
    SoundService.playClick();
    Haptic.medium();
    final uid = MayaJaalAccount.cachedUid;
    if (uid == null) return;
    final ok = await SecurityGuard.validateSession();
    if (!ok) {
      _showFeedback('🔒 Session expired');
      return;
    }
    await FirebaseService.toggleLike(widget.videoId, uid, _ownerUid, widget.title);
  }

  Future<void> _handleDislike() async {
    SoundService.playClick();
    Haptic.medium();
    final uid = MayaJaalAccount.cachedUid;
    if (uid == null) return;
    final ok = await SecurityGuard.validateSession();
    if (!ok) {
      _showFeedback('🔒 Session expired');
      return;
    }
    await FirebaseService.toggleDislike(widget.videoId, uid);
  }

  Future<void> _shareVideoLink() async {
    SoundService.playClick();
    Haptic.light();
    await FirebaseService.recordShare(widget.videoId);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppThemes.kBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 3.5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            const Text('SHARE VIDEO', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 4),
            Text(widget.title, style: const TextStyle(color: Colors.white60, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _shareOption(Icons.link, 'Copy Link', AppThemes.kNeonCyan, () async {
                  SoundService.playClick();
                  Haptic.medium();
                  await Clipboard.setData(ClipboardData(text: widget.sourcePageUrl));
                  if (c.mounted) Navigator.pop(c);
                  _showFeedback('🔗 Link Copied!');
                }),
                _shareOption(Icons.share, 'Share Now', AppThemes.kGreen, () {
                  SoundService.playClick();
                  Haptic.medium();
                  Navigator.pop(c);
                  Share.share('🎬 Watch "${widget.title}" on MayaJaal:\n${widget.sourcePageUrl}');
                }),
                _shareOption(Icons.send_rounded, 'Telegram', const Color(0xFF229ED9), () {
                  SoundService.playClick();
                  Haptic.medium();
                  Navigator.pop(c);
                  Share.share('🎬 Watch "${widget.title}" on MayaJaal:\n${widget.sourcePageUrl}');
                }),
              ],
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Widget _shareOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle, border: Border.all(color: AppThemes.kBorder)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
        ],
      ),
    );
  }

  Future<void> _startInAppDownload() async {
    if (_isDownloading) return;
    SoundService.playClick();
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
          SnackBar(backgroundColor: AppThemes.kCardBg, content: Text('✅ Video saved to:\n$savePath', style: const TextStyle(color: AppThemes.kGreen, fontSize: 10.5))),
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
    SoundService.playClick();
    Haptic.medium();
    final uid = MayaJaalAccount.cachedUid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'saved_videos_v1_$uid';
    final savedStr = prefs.getString(key);
    List<Map<String, dynamic>> savedList = [];
    if (savedStr != null) {
      try { savedList = (jsonDecode(savedStr) as List).cast<Map<String, dynamic>>(); } catch (_) {}
    }

    setState(() => _isSaved = !_isSaved);

    final item = {
      'url': widget.sourcePageUrl,
      'title': widget.title,
      'uploader': widget.uploader,
      'id': widget.videoId,
      'thumbnail': widget.thumbnailUrl,
      'streamUrl': widget.videoUrl,
      'size': _videoSize,
      'age': _videoAge,
    };

    if (_isSaved) {
      savedList.add(item);
      await prefs.setString(key, jsonEncode(savedList));
      prefs.setBool('saved_${uid}_${widget.videoId}', true);
      await WatchHistory.syncSavedRecordCloud(item, true);
    } else {
      savedList.removeWhere((s) => s['url'] == widget.sourcePageUrl);
      await prefs.setString(key, jsonEncode(savedList));
      prefs.setBool('saved_${uid}_${widget.videoId}', false);
      await WatchHistory.syncSavedRecordCloud(item, false);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isSaved ? 'Video Saved to Favorites' : 'Removed from Favorites'), duration: const Duration(seconds: 1)),
    );
  }

  void _showQualityDialog() {
    SoundService.playClick();
    Haptic.light();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppThemes.kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppThemes.kBorder)),
        title: const Text('SELECT QUALITY', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _qualities.map((q) {
            return RadioListTile<String>(
              value: q,
              groupValue: _selectedQuality,
              activeColor: AppThemes.kGreen,
              title: Text(q, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              onChanged: (val) {
                if (val != null) {
                  SoundService.playClick();
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
    SoundService.playClick();
    Haptic.light();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppThemes.kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppThemes.kBorder)),
        title: const Text('PLAYBACK SPEED', style: TextStyle(color: Colors.white, fontSize: 13)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _speeds.map((s) {
            return RadioListTile<double>(
              value: s,
              groupValue: _playbackSpeed,
              activeColor: AppThemes.kGreen,
              title: Text('${s}x', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              onChanged: (val) {
                if (val != null) {
                  SoundService.playClick();
                  Haptic.selection();
                  setState(() => _playbackSpeed = val);
                  _betterPlayerController?.setSpeed(val);
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
    if (_betterPlayerController == null || !_isInitialized) return const SizedBox.shrink();
    final size = _betterPlayerController!.videoPlayerController?.value.size;
    if (size == null) return const SizedBox.shrink(); // 🔥 Null Safety Fixed

    return SizedBox.expand(
      child: FittedBox(
        fit: _isZoomed ? BoxFit.cover : BoxFit.contain,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: RepaintBoundary(
            key: _videoKey,
            child: BetterPlayer(controller: _betterPlayerController!),
          ),
        ),
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
      _betterPlayerController?.setVolume(newVol);
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
        width: 96,
        height: 38,
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppThemes.kBorder)),
        child: Stack(
          children: [
            if (_isDownloading)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 38 * _downloadProgress,
                  decoration: BoxDecoration(color: AppThemes.kGreen.withOpacity(0.35), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7))),
                ),
              ),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isDownloading ? Icons.downloading : Icons.download_rounded, color: AppThemes.kGreen, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _isDownloading ? '${(_downloadProgress * 100).toInt()}%' : 'Download',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                      top: 18,
                      left: 18,
                      child: GestureDetector(
                        onTap: _toggleSmartFullscreen,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 24),
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
                            decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.replay_10, color: Colors.white, size: 26),
                          ),
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: () {
                            SoundService.playClick();
                            Haptic.light();
                            if (_betterPlayerController != null) {
                              if (_betterPlayerController!.isPlaying() ?? false) { // 🔥 Null Safety Fixed
                                _betterPlayerController!.pause();
                              } else {
                                _betterPlayerController!.play();
                              }
                            }
                            _resetControlTimer();
                          },
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: Colors.white60, width: 1.5)),
                            child: Icon((_betterPlayerController?.isPlaying() ?? false) ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 34), // 🔥 Null Safety Fixed
                          ),
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: () => _seekRelative(10),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.forward_10, color: Colors.white, size: 26),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Row(
                        children: [
                          Text(_formatDuration(_betterPlayerController?.videoPlayerController?.value.position ?? Duration.zero), style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(trackHeight: 2.5, activeTrackColor: AppThemes.kGreen, inactiveTrackColor: Colors.white24, thumbColor: AppThemes.kGreen, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5)),
                              child: Slider(
                                value: (_betterPlayerController?.videoPlayerController?.value.position.inSeconds.toDouble() ?? 0.0).clamp(0.0, (_betterPlayerController?.videoPlayerController?.value.duration?.inSeconds.toDouble() ?? 1.0) <= 0 ? 1.0 : (_betterPlayerController?.videoPlayerController?.value.duration?.inSeconds.toDouble() ?? 1.0)), // 🔥 Null Safety Fixed
                                min: 0.0,
                                max: (_betterPlayerController?.videoPlayerController?.value.duration?.inSeconds.toDouble() ?? 1.0) > 0 ? (_betterPlayerController?.videoPlayerController?.value.duration?.inSeconds.toDouble() ?? 1.0) : 1.0, // 🔥 Null Safety Fixed
                                onChanged: (val) => _betterPlayerController?.seekTo(Duration(seconds: val.toInt())),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(_formatDuration(_betterPlayerController?.videoPlayerController?.value.duration ?? Duration.zero), style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                  ],
                  if (_flashFeedback.isNotEmpty)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppThemes.kBorder)),
                        child: Text(_flashFeedback, style: const TextStyle(color: AppThemes.kGreen, fontWeight: FontWeight.bold, fontSize: 16)),
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
        backgroundColor: AppThemes.kBg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: AppThemes.kGreen, size: 18),
                      onPressed: () {
                        SoundService.playClick();
                        Haptic.light();
                        Navigator.pop(context);
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
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(color: AppThemes.kGreen, width: 1.2),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.asset(
                                    'assets/icon/logo.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Icon(Icons.change_history, color: AppThemes.kGreen, size: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('Maya', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                              const Text('Jaal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppThemes.kGreen)),
                            ],
                          ),
                          Text('— STREAM BEYOND LIMITS —', style: TextStyle(color: Colors.white38, fontSize: 7.5, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.share, color: AppThemes.kGreen, size: 20), onPressed: _shareVideoLink),
                  ],
                ),
              ),
              Expanded(
                flex: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  child: Container(
                    width: double.infinity,
                    height: 220,
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppThemes.kBorder)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: _hasError
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                                  const SizedBox(height: 8),
                                  const Text('Stream Connection Error', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                                  TextButton(onPressed: _initVideo, child: const Text('RETRY', style: TextStyle(color: AppThemes.kGreen))),
                                ],
                              ),
                            )
                          : !_isInitialized
                              ? const ProfessionalLoader(message: 'INITIALIZING VIDEO...')
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
                                            top: 8,
                                            left: 8,
                                            child: GestureDetector(
                                              onTap: _showQualityDialog,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(5), border: Border.all(color: AppThemes.kBorder)),
                                                child: const Text('HD', style: TextStyle(color: AppThemes.kGreen, fontSize: 9, fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: GestureDetector(
                                              onTap: _showSpeedDialog,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(5), border: Border.all(color: AppThemes.kBorder)),
                                                child: Text('${_playbackSpeed}x', style: const TextStyle(color: AppThemes.kNeonCyan, fontSize: 9.5, fontWeight: FontWeight.bold)),
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
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                                    child: const Icon(Icons.replay_10, color: Colors.white, size: 24),
                                                  ),
                                                ),
                                                const SizedBox(width: 18),
                                                GestureDetector(
                                                  onTap: () {
                                                    SoundService.playClick();
                                                    Haptic.light();
                                                    if (_betterPlayerController != null) {
                                                      if (_betterPlayerController!.isPlaying() ?? false) { // 🔥 Null Safety Fixed
                                                        _betterPlayerController!.pause();
                                                      } else {
                                                        _betterPlayerController!.play();
                                                      }
                                                    }
                                                    _resetControlTimer();
                                                  },
                                                  child: Container(
                                                    width: 56,
                                                    height: 56,
                                                    decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: Colors.white70, width: 1.5)),
                                                    child: Icon((_betterPlayerController?.isPlaying() ?? false) ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 32), // 🔥 Null Safety Fixed
                                                  ),
                                                ),
                                                const SizedBox(width: 18),
                                                GestureDetector(
                                                  onTap: () => _seekRelative(10),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                                    child: const Icon(Icons.forward_10, color: Colors.white, size: 24),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (_flashFeedback.isNotEmpty)
                                            Center(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppThemes.kBorder)),
                                                child: Text(_flashFeedback, style: const TextStyle(color: AppThemes.kGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                                              ),
                                            ),
                                          if (_showControls)
                                            Positioned(
                                              bottom: 6,
                                              left: 8,
                                              right: 8,
                                              child: Row(
                                                children: [
                                                  Text(_formatDuration(_betterPlayerController?.videoPlayerController?.value.position ?? Duration.zero), style: const TextStyle(color: Colors.white, fontSize: 9.5, fontFamily: 'monospace')),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: SliderTheme(
                                                      data: SliderTheme.of(context).copyWith(trackHeight: 2.0, activeTrackColor: AppThemes.kGreen, inactiveTrackColor: Colors.white24, thumbColor: AppThemes.kGreen, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4)),
                                                      child: Slider(
                                                        value: (_betterPlayerController?.videoPlayerController?.value.position.inSeconds.toDouble() ?? 0.0).clamp(0.0, (_betterPlayerController?.videoPlayerController?.value.duration?.inSeconds.toDouble() ?? 1.0) <= 0 ? 1.0 : (_betterPlayerController?.videoPlayerController?.value.duration?.inSeconds.toDouble() ?? 1.0)), // 🔥 Null Safety Fixed
                                                        min: 0.0,
                                                        max: (_betterPlayerController?.videoPlayerController?.value.duration?.inSeconds.toDouble() ?? 1.0) > 0 ? (_betterPlayerController?.videoPlayerController?.value.duration?.inSeconds.toDouble() ?? 1.0) : 1.0, // 🔥 Null Safety Fixed
                                                        onChanged: (val) => _betterPlayerController?.seekTo(Duration(seconds: val.toInt())),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(_formatDuration(_betterPlayerController?.videoPlayerController?.value.duration ?? Duration.zero), style: const TextStyle(color: Colors.white, fontSize: 9.5, fontFamily: 'monospace')),
                                                  const SizedBox(width: 6),
                                                  GestureDetector(
                                                    onTap: () {
                                                      SoundService.playClick();
                                                      Haptic.light();
                                                      setState(() => _isZoomed = !_isZoomed);
                                                      _resetControlTimer();
                                                    },
                                                    child: Icon(
                                                      _isZoomed ? Icons.zoom_in : Icons.zoom_out,
                                                      color: _isZoomed ? AppThemes.kGreen : Colors.white70,
                                                      size: 18,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  GestureDetector(
                                                    onTap: _toggleSmartFullscreen,
                                                    child: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 18),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(
                    children: [
                      const SizedBox(height: 6),

                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppThemes.kCardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppThemes.kBorder)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.play_circle_fill, color: AppThemes.kGreen, size: 22),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: AppThemes.kBorder)),
                                  child: const Text('HD', style: TextStyle(color: AppThemes.kGreen, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.account_circle, color: Colors.white38, size: 12),
                                const SizedBox(width: 4),
                                Text('Uploaded by: ${widget.uploader}', style: const TextStyle(color: AppThemes.kDimGreen, fontSize: 9.5)),
                                const SizedBox(width: 8),
                                Text('|   👁 ${_stats['views']} views', style: const TextStyle(color: Colors.white38, fontSize: 9.5)),
                              ],
                            ),

                            if (_videoSize.isNotEmpty || _videoAge.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (_videoSize.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        color: AppThemes.kNeonCyan.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: AppThemes.kNeonCyan.withOpacity(0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.sd_storage_outlined, size: 10, color: AppThemes.kNeonCyan),
                                          const SizedBox(width: 4),
                                          Text(
                                            _videoSize,
                                            style: const TextStyle(
                                              color: AppThemes.kNeonCyan,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (_videoAge.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppThemes.kGold.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: AppThemes.kGold.withOpacity(0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.calendar_today_outlined, size: 10, color: AppThemes.kGold),
                                          const SizedBox(width: 4),
                                          Text(
                                            _videoAge,
                                            style: const TextStyle(
                                              color: AppThemes.kGold,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: _handleLike,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6), border: Border.all(color: _isLiked ? AppThemes.kGreen : AppThemes.kBorder)),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(_isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined, color: AppThemes.kGreen, size: 13),
                                              const SizedBox(width: 3),
                                              Text('${_stats['likes']}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          const Text('Like', style: TextStyle(color: Colors.white38, fontSize: 8.5)),
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
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6), border: Border.all(color: _isUnliked ? Colors.redAccent : AppThemes.kBorder)),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(_isUnliked ? Icons.thumb_down : Icons.thumb_down_alt_outlined, color: Colors.redAccent, size: 13),
                                              const SizedBox(width: 3),
                                              Text('${_stats['unlikes']}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          const Text('Dislike', style: TextStyle(color: Colors.white38, fontSize: 8.5)),
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
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6), border: Border.all(color: _isSaved ? AppThemes.kGreen : AppThemes.kBorder)),
                                      child: Column(
                                        children: [
                                          Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, color: _isSaved ? AppThemes.kGreen : Colors.white70, size: 13),
                                          const Text('Save', style: TextStyle(color: Colors.white38, fontSize: 8.5)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _buildWaterFillDownloadButton(),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: const [
                          Icon(Icons.play_circle_outline, color: AppThemes.kGreen, size: 16),
                          SizedBox(width: 6),
                          Text('Related Videos', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),

                      _relatedLoading
                          ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppThemes.kGreen, strokeWidth: 1.8)))
                          : _relatedVideos.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(color: AppThemes.kCardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppThemes.kBorder)),
                                  child: const Center(child: Text('No related videos yet', style: TextStyle(color: Colors.white38, fontSize: 11.5))),
                                )
                              : SizedBox(
                                  height: 145,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _relatedVideos.length,
                                    itemBuilder: (context, i) {
                                      final v = _relatedVideos[i];
                                      return _buildRelatedCard(v);
                                    },
                                  ),
                                ),
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
    String title = '';
    String fName = (v['filename'] ?? '').toString().trim();
    String tName = (v['title'] ?? '').toString().trim();
    if (fName.isNotEmpty && fName != 'null') {
      title = fName;
    } else if (tName.isNotEmpty && tName != 'null') {
      title = tName;
    } else {
      title = 'MayaJaal Video';
    }
    final uploader = (v['uploader'] ?? '@mayajaal').toString();
    final views = (v['views'] ?? 0) as int;
    final thumb = v['thumbnail']?.toString() ?? '';

    final String streamUrl = id.isNotEmpty ? '$kBackendBaseUrl/stream/$id' : '';

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          SoundService.playClick();
          Haptic.medium();
          final url = '$kBackendBaseUrl/v/$id';
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => StreamPreviewScreen(targetUrl: url),
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 160,
          decoration: BoxDecoration(color: AppThemes.kCardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppThemes.kBorder)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 82,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                  child: buildMediaThumbnail(thumb, title, streamUrl, isSmall: true),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(child: Text(uploader, style: const TextStyle(color: AppThemes.kDimGreen, fontSize: 9.0), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const Icon(Icons.visibility, color: Colors.white38, size: 9),
                        const SizedBox(width: 2),
                        Text('$views', style: const TextStyle(color: Colors.white38, fontSize: 8.5)),
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

// ═══════════════════════════════════════════════════════════════════════════════
// USER SEARCH DELEGATE
// ═══════════════════════════════════════════════════════════════════════════════
class UserSearchDelegate extends SearchDelegate {
  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      inputDecorationTheme: const InputDecorationTheme(hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none),
      textTheme: const TextTheme(titleLarge: TextStyle(color: Colors.white, fontSize: 15)),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear, color: AppThemes.kGreen, size: 20), onPressed: () => query = ''),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back, color: AppThemes.kGreen, size: 20),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildSearch();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearch();

  Widget _buildSearch() {
    if (query.trim().isEmpty) {
      return Container(
        color: AppThemes.kBg,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, color: Colors.white24, size: 50),
              const SizedBox(height: 10),
              const Text('Search users by name or email', style: TextStyle(color: Colors.white38, fontSize: 12.5)),
            ],
          ),
        ),
      );
    }

    return Container(
      color: AppThemes.kBg,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: FirebaseService.searchUsers(query),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppThemes.kGreen));
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_outlined, color: Colors.white24, size: 50),
                  const SizedBox(height: 10),
                  Text('No user found for "$query"', style: const TextStyle(color: Colors.white38, fontSize: 12.5)),
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppThemes.kBorder)),
                  child: photo.isNotEmpty
                      ? ClipOval(child: Image.network(photo, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person, color: AppThemes.kGreen, size: 18)))
                      : const Icon(Icons.person, color: AppThemes.kGreen, size: 18),
                ),
                title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text(email, style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 12),
                onTap: () {
                  SoundService.playClick();
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

// ═══════════════════════════════════════════════════════════════════════════════
// USER PROFILE SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
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
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSub() async {
    SoundService.playClick();
    Haptic.medium();
    final myUid = MayaJaalAccount.cachedUid;
    if (myUid == null) return;
    final ok = await SecurityGuard.validateSession();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppThemes.kCardBg,
          content: Text('🔒 Session expired', style: TextStyle(color: Colors.orangeAccent)),
        ),
      );
      return;
    }
    final newState = await FirebaseService.toggleSubscription(myUid, _channelUid);
    if (mounted) {
      setState(() => _isSubscribed = newState);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppThemes.kCardBg, content: Text(newState ? '✅ Subscribed!' : 'Unsubscribed', style: const TextStyle(color: AppThemes.kGreen)), duration: const Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = MayaJaalAccount.cachedUid == _channelUid;

    return Scaffold(
      backgroundColor: AppThemes.kBg,
      appBar: AppBar(title: Text('@${_channelName.split(' ').first}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppThemes.kGreen))
          : Column(
              children: [
                const SizedBox(height: 18),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppThemes.kBorder, width: 1.5)),
                  child: _channelPhoto.isNotEmpty
                      ? ClipOval(child: Image.network(_channelPhoto, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person, size: 36, color: AppThemes.kGreen)))
                      : const Icon(Icons.person, size: 36, color: AppThemes.kGreen),
                ),
                const SizedBox(height: 10),
                Text(_channelName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(_channelEmail, style: const TextStyle(color: AppThemes.kDimGreen, fontSize: 11)),
                const SizedBox(height: 4),
                StreamBuilder<int>(
                  stream: FirebaseService.getSubscriberCount(_channelUid),
                  builder: (c, s) {
                    final count = s.data ?? 0;
                    return Text('$count subscribers', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10));
                  },
                ),
                const SizedBox(height: 14),
                if (!isOwnProfile)
                  SizedBox(
                    width: 180,
                    child: ElevatedButton(
                      onPressed: _toggleSub,
                      style: ElevatedButton.styleFrom(backgroundColor: _isSubscribed ? Colors.white12 : AppThemes.kGreen, foregroundColor: _isSubscribed ? Colors.white : Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 10)),
                      child: Text(_isSubscribed ? '✓ SUBSCRIBED' : '+ SUBSCRIBE', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 11.5)),
                    ),
                  ),
                const Divider(color: Colors.white10, height: 26),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.video_library, color: AppThemes.kGreen, size: 16),
                      const SizedBox(width: 6),
                      Text('VIDEOS (${_videos.length})', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _videos.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.video_library_outlined, color: Colors.white24, size: 50),
                              const SizedBox(height: 10),
                              const Text('No uploads yet', style: TextStyle(color: Colors.white38, fontSize: 12.5)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _videos.length,
                          itemBuilder: (context, i) {
                            final vid = _videos[i];
                            final id = vid['id']?.toString() ?? '';
                            String name = '';
                            String fName = (vid['filename'] ?? '').toString().trim();
                            String tName = (vid['title'] ?? '').toString().trim();
                            if (fName.isNotEmpty && fName != 'null') {
                              name = fName;
                            } else if (tName.isNotEmpty && tName != 'null') {
                              name = tName;
                            } else {
                              name = 'MayaJaal Video';
                            }
                            final views = vid['views'] ?? 0;
                            final thumb = vid['thumbnail']?.toString() ?? '';
                            final streamUrl = id.isNotEmpty ? '$kBackendBaseUrl/stream/$id' : '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(color: AppThemes.kCardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppThemes.kBorder)),
                              child: ListTile(
                                leading: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(7), border: Border.all(color: AppThemes.kBorder)),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: buildMediaThumbnail(thumb, name, streamUrl, isSmall: true),
                                  ),
                                ),
                                title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Row(
                                  children: [
                                    const Icon(Icons.visibility, color: Colors.white38, size: 10),
                                    const SizedBox(width: 3),
                                    Text('$views views', style: const TextStyle(color: Colors.white38, fontSize: 9.5)),
                                  ],
                                ),
                                onTap: () {
                                  SoundService.playClick();
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

// ═══════════════════════════════════════════════════════════════════════════════
// STATS SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  Map<String, dynamic> _dashboard = {};
  List<Map<String, dynamic>> _links = [];
  int _currentTier = 1;
  int _nextBoost = 1000;
  int _rankIndex = 0;

  late AnimationController _rankAnimCtrl;
  late Animation<double> _rankScale;

  @override
  void initState() {
    super.initState();
    _rankAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _rankScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 60),
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

      final ok = await SecurityGuard.validateSession();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppThemes.kCardBg,
              content: Text('🔒 Session expired. Please login again.', style: TextStyle(color: Colors.orangeAccent)),
            ),
          );
        }
        if (mounted) setState(() => _loading = false);
        return;
      }

      final dash = await MayaJaalAccount.getDashboard();
      final links = await MayaJaalAccount.getUserLinks(limit: 50);

      final totalViews = (dash['totalViews'] ?? 0) as int;
      final tierInfo = MayaJaalAccount.getTierInfo(totalViews);
      final newRankIndex = CyberRank.getIndex(totalViews);

      if (newRankIndex != _rankIndex && _rankIndex != 0) {
        _rankAnimCtrl.forward(from: 0);
      }

      if (mounted) {
        setState(() {
          _dashboard = dash;
          _links = links;
          _currentTier = (tierInfo['tier'] ?? 1) as int;
          _nextBoost = (tierInfo['next'] ?? 0) as int;
          _rankIndex = newRankIndex;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Stats load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.kBg,
      appBar: AppBar(
        title: const Text('CREATOR STATS', style: TextStyle(letterSpacing: 1.2, fontSize: 13, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppThemes.kGreen),
            onPressed: () {
              SoundService.playClick();
              Haptic.light();
              setState(() => _loading = true);
              _loadData();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppThemes.kGreen))
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
          children: const [
            Icon(Icons.link_off, color: Colors.orangeAccent, size: 50),
            SizedBox(height: 14),
            Text('NOT LOGGED IN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            SizedBox(height: 8),
            Text('Please login to view creator stats.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12)),
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
      color: AppThemes.kGreen,
      backgroundColor: AppThemes.kCardBg,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppThemes.kCardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppThemes.kBorder)),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: AppThemes.kGreen, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('LOGGED IN AS', style: TextStyle(color: Colors.white38, fontSize: 8.5, letterSpacing: 1.2)),
                        const SizedBox(height: 1),
                        Text(MayaJaalAccount.cachedEmail ?? 'N/A', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _rankScale,
              builder: (c, child) => Transform.scale(scale: _rankScale.value, child: child),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppThemes.kCardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppThemes.kBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppThemes.kBorder)),
                      child: Center(child: Text(rank['emoji'] as String, style: const TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CYBER RANK', style: TextStyle(color: rankColor, fontSize: 8.5, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(rank['name'] as String, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                          if (nextRank != null)
                            Text('${(nextRank['min'] as int) - totalViews} views to ${nextRank['name']}', style: const TextStyle(color: Colors.white38, fontSize: 9.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppThemes.kCardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppThemes.kBorder)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL VIEWS', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  Text('$totalViews', style: const TextStyle(color: AppThemes.kGreen, fontSize: 34, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  const Text('Verified platform views', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  const Divider(color: Colors.white10, height: 22),
                  Row(
                    children: [
                      Expanded(child: _statChip('👁 Total Views', '$totalViews')),
                      const SizedBox(width: 6),
                      Expanded(child: _statChip('📅 Today', '$todayViews')),
                      const SizedBox(width: 6),
                      Expanded(child: _statChip('🔗 Links', '$totalLinks')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppThemes.kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppThemes.kBorder)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 18),
                      const SizedBox(width: 6),
                      Text('TIER $_currentTier', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _tierStat('Current Tier', 'Tier $_currentTier')),
                      const SizedBox(width: 6),
                      Expanded(child: _tierStat('Next Boost', '$_nextBoost views')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('Keep sharing your videos to unlock higher ranks and recognition across the MayaJaal creator community.', style: TextStyle(color: Colors.white38, fontSize: 9.5)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('YOUR LINKS', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            _links.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppThemes.kCardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppThemes.kBorder)),
                    child: const Center(child: Text('No links yet. Use the bot to upload videos and start sharing.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11))),
                  )
                : Column(
                    children: _links.map((link) {
                      final views = (link['views'] ?? 0) as int;
                      final name = (link['filename'] ?? link['originalUrl'] ?? 'link').toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppThemes.kCardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppThemes.kBorder)),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppThemes.kBorder)),
                              child: const Icon(Icons.play_circle_outline, color: AppThemes.kGreen, size: 18),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.visibility, color: Colors.white38, size: 10),
                                      const SizedBox(width: 3),
                                      Text('$views views', style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppThemes.kCardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppThemes.kBorder)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(Icons.info_outline, color: AppThemes.kGreen, size: 14), SizedBox(width: 6), Text('INFO', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 1.0))]),
                  SizedBox(height: 6),
                  Text('• Views are validated after 10+ seconds of real playback', style: TextStyle(color: Colors.white60, fontSize: 10.5)),
                  Text('• Cyber Rank is calculated from cumulative verified views', style: TextStyle(color: Colors.white60, fontSize: 10.5)),
                  Text('• 28-day auto lifecycle on all stream links', style: TextStyle(color: Colors.white60, fontSize: 10.5)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppThemes.kBorder)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8.5), textAlign: TextAlign.center),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _tierStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppThemes.kBorder)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8.5)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
