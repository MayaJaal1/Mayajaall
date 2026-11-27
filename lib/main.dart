import 'maya_ai.dart';
import 'maya_ads.dart';
import 'dart:async';
import 'live_adventures.dart';
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
import 'package:better_player/better_player.dart' hide VideoPlayerValue;
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:webview_flutter/webview_flutter.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIG & NETWORK BASE URLS
// ═══════════════════════════════════════════════════════════════════════════════
const String webClientId =
    '96139047750-5ooi0pbvch98qu447somuurh6k6fmhcj.apps.googleusercontent.com';
const String oneSignalAppId = '06b99c2b-b3b4-413b-b6cc-480a624f4e25';
const String kBackendBaseUrl = 'https://www.mayajaal.online';
const int kAppCurrentVersionCode = 7;

const List<String> kAllowedEmailDomains = ['@gmail.com', '@googlemail.com'];

const int kMinAccountAgeSeconds = 60;
const int kMaxLoginAttempts = 5;
const int kLoginWindowMinutes = 10;
const String _kHmacSecret =
    'MJ_HMAC_v1_a7f3b92e_d4c8_11ef_9b8a_00ff_secret_2026';

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

final ValueNotifier<String> themeNotifier = ValueNotifier<String>(
  'Cyber Emerald',
);
final ValueNotifier<String> languageNotifier = ValueNotifier<String>('English');
final ValueNotifier<bool> soundEnabledNotifier = ValueNotifier<bool>(true);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
bool _pendingMayaPushInbox = false;
void _openPendingMayaPushInbox() {
  if (!_pendingMayaPushInbox ||
      FirebaseAuth.instance.currentUser == null ||
      navigatorKey.currentState == null)
    return;
  _pendingMayaPushInbox = false;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = navigatorKey.currentContext;
    if (context != null && FirebaseAuth.instance.currentUser != null)
      showTopNotificationDropdown(context);
  });
}

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
              border: Border.all(
                color: AppThemes.kGreen.withOpacity(0.8),
                width: 1.2,
              ),
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
// Muted, visible-only previews. Keep posters mounted while a decoder starts.
class VideoLoopThumbnail extends StatefulWidget {
  final String videoUrl;
  final String sourceUrl;
  final String title;
  final bool isSmall;
  final BoxFit fit;
  final String? fallbackThumb;
  final void Function(String base64Thumb)? onFrameCaptured;
  const VideoLoopThumbnail({
    super.key,
    required this.videoUrl,
    required this.title,
    this.isSmall = false,
    this.fallbackThumb,
    this.onFrameCaptured,
    this.sourceUrl = '',
    this.fit = BoxFit.cover,
  });
  @override
  State<VideoLoopThumbnail> createState() => _VideoLoopThumbnailState();
}

class _VideoLoopThumbnailState extends State<VideoLoopThumbnail>
    with WidgetsBindingObserver {
  static final _active = <_VideoLoopThumbnailState>{};
  VideoPlayerController? _controller;
  Timer? _visibilityTimer;
  bool _foreground = true, _visible = false, _failed = false;
  bool _ready = false, _rewinding = false, _captured = false;
  int _generation = 0;
  bool _starting = false;
  double _distance = double.infinity, _lastTop = double.infinity;
  DateTime _settled = DateTime.now();
  final _captureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
    _visibilityTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _checkVisibility(),
    );
  }

  @override
  void didUpdateWidget(covariant VideoLoopThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.sourceUrl != widget.sourceUrl) {
      _stop();
      _failed = false;
      _captured = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _checkVisibility();
  }

  void _checkVisibility() {
    if (!mounted) return;
    final box = context.findRenderObject();
    var visible = false;
    if (_foreground &&
        TickerMode.of(context) &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        box is RenderBox &&
        box.attached &&
        box.hasSize &&
        box.size.shortestSide > 0) {
      var clip = Offset.zero & MediaQuery.sizeOf(context);
      // Also respect nested scroll views, not just the full phone screen.
      context.visitAncestorElements((element) {
        final render = element.renderObject;
        if (render is RenderAbstractViewport && render is RenderBox) {
          final RenderBox viewportBox = render as RenderBox;
          if (viewportBox.hasSize) {
            clip = clip.intersect(
              viewportBox.localToGlobal(Offset.zero) & viewportBox.size,
            );
          }
        }
        return true;
      });
      final rect = box.localToGlobal(Offset.zero) & box.size;
      _distance = (rect.center.dy - clip.center.dy).abs();
      if ((rect.top - _lastTop).abs() > 5) {
        _lastTop = rect.top;
        _settled = DateTime.now();
      }
      final overlap = rect.intersect(clip);
      visible =
          overlap.width > 0 &&
          overlap.height > 0 &&
          overlap.width * overlap.height >=
              math.min(rect.width * rect.height, clip.width * clip.height) *
                  .55;
    }
    _visible = visible;
    if (!visible) {
      if (_controller != null || _starting) {
        _stop();
        if (mounted) setState(() {});
      }
    } else if (!_failed &&
        !_starting &&
        _controller == null &&
        widget.videoUrl.isNotEmpty &&
        DateTime.now().difference(_settled) >=
            const Duration(milliseconds: 450)) {
      // One visible preview decoder for the whole app, with center hysteresis.
      final current =
          _active.where((s) => s != this && s._visible && s.mounted).toList();
      if (current.any((s) => s._distance <= _distance + 60)) return;
      for (final other in _active.toList()) {
        if (other != this) {
          other._stop();
          if (other.mounted) other.setState(() {});
        }
      }
      _active.add(this);
      _starting = true;
      unawaited(_start());
    }
  }

  Future<void> _start() async {
    final generation = ++_generation;
    VideoPlayerController? controller;
    try {
      var address = widget.videoUrl;
      if (_isSocialLink(widget.sourceUrl)) {
        final media = await MayaResolvedMedia.load(Uri.parse(widget.sourceUrl));
        if (!mounted || generation != _generation || !_visible) return;
        final direct =
            media.variants
                .where((v) => v.url.path.contains('/q/file/'))
                .toList();
        if (direct.isNotEmpty) {
          address = direct.last.url.toString();
        } else {
          final preview = await MayaChannelsApi.request(
            '/preview',
            method: 'POST',
            body: {'url': widget.sourceUrl},
          );
          address = '${preview['stream_url'] ?? ''}';
        }
        if (!mounted || generation != _generation || !_visible) return;
        unawaited(MayaPosterCache.remember(widget.sourceUrl, media.thumbnail));
      }
      final channelSource = Uri.tryParse(widget.sourceUrl);
      if (channelSource != null &&
          _isMayaJaalHost(channelSource.host) &&
          channelSource.pathSegments.length == 2 &&
          channelSource.pathSegments.first == 'channel' &&
          (channelSource.queryParameters['post'] ?? '').isNotEmpty) {
        final post = await MayaChannelsApi.request(
          '/${Uri.encodeComponent(channelSource.pathSegments[1])}/posts/${Uri.encodeComponent(channelSource.queryParameters['post']!)}',
        );
        if (!mounted || generation != _generation || !_visible) return;
        address =
            '${post['preview'] ?? ''}'.isNotEmpty
                ? '${post['preview']}'
                : '${post['media'] ?? ''}';
        unawaited(
          MayaPosterCache.remember(
            widget.sourceUrl,
            '${post['thumbnail'] ?? ''}',
          ),
        );
      }
      final uri = Uri.tryParse(address);
      final options = VideoPlayerOptions(mixWithOthers: true);
      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
        controller = VideoPlayerController.networkUrl(
          uri,
          videoPlayerOptions: options,
        );
      } else if (address.startsWith('/') || uri?.scheme == 'file') {
        controller = VideoPlayerController.file(
          uri?.scheme == 'file' ? File.fromUri(uri!) : File(address),
          videoPlayerOptions: options,
        );
      } else {
        throw const FormatException('No playable preview');
      }
      _controller = controller;
      await controller.initialize().timeout(const Duration(seconds: 12));
      if (!mounted || generation != _generation) return;
      await controller.setVolume(0);
      await controller.setLooping(true);
      if (!mounted || generation != _generation) return;
      controller.addListener(_onFrame);
      if (_visible) await controller.play();
    } catch (_) {
      if (mounted && generation == _generation) {
        _stop();
        setState(() => _failed = true);
      }
    } finally {
      if (generation == _generation) _starting = false;
    }
  }

  void _onFrame() {
    final controller = _controller;
    if (!mounted || controller == null || !controller.value.isInitialized)
      return;
    if (controller.value.hasError) {
      _stop();
      setState(() => _failed = true);
      return;
    }
    if (!_ready &&
        controller.value.position >= const Duration(milliseconds: 350)) {
      setState(() => _ready = true);
      unawaited(_capture());
    }
    if (!_rewinding &&
        controller.value.position >= const Duration(seconds: 5)) {
      _rewinding = true;
      unawaited(
        controller
            .seekTo(Duration.zero)
            .then((_) async {
              if (mounted && _controller == controller && _visible)
                await controller.play();
            })
            .catchError((Object _) {})
            .whenComplete(() => _rewinding = false),
      );
    }
  }

  Future<void> _capture() async {
    if (_captured ||
        (widget.onFrameCaptured == null && widget.sourceUrl.isEmpty))
      return;
    _captured = true;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted || !_ready) return;
    ui.Image? image;
    try {
      final boundary = _captureKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary || boundary.debugNeedsPaint)
        return;
      image = await boundary.toImage(pixelRatio: .5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (mounted && bytes != null) {
        final frame = base64Encode(bytes.buffer.asUint8List());
        widget.onFrameCaptured?.call(frame);
        if (widget.sourceUrl.isNotEmpty)
          unawaited(MayaPosterCache.remember(widget.sourceUrl, frame));
      }
    } catch (_) {
    } finally {
      image?.dispose();
    }
  }

  void _stop() {
    _generation++;
    _starting = false;
    final old = _controller;
    _controller = null;
    _ready = false;
    _rewinding = false;
    _active.remove(this);
    old?.removeListener(_onFrame);
    if (old != null) unawaited(old.dispose());
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      _MayaPoster(
        thumb: widget.fallbackThumb,
        title: widget.title,
        isSmall: widget.isSmall,
        sourceUrl: widget.sourceUrl,
        fit: widget.fit,
      ),
      if (_ready && _controller != null)
        Positioned.fill(
          child: RepaintBoundary(
            key: _captureKey,
            child: ClipRect(
              child: FittedBox(
                fit: widget.fit,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

// ImageProvider is retained across player timer/progress rebuilds. In particular,
// don't base64Decode into a new MemoryImage every 350 ms.
// Durable source posters survive a backend restart; stream tokens never act as cache keys.
bool _isMayaJaalHost(String host) =>
    host == 'mayajaal.online' || host.endsWith('.mayajaal.online');

class MayaPosterCache {
  static final changed = ValueNotifier<int>(0);
  static bool _metadataBusy = false;
  static final _posterAttempts = <String, DateTime>{};
  static Future<bool> recover(String source) async {
    if (source.isEmpty || _metadataBusy) return false;
    final key = _key(source);
    if (_posterAttempts[key] != null &&
        DateTime.now().difference(_posterAttempts[key]!).inSeconds < 60)
      return true;
    if (_posterAttempts.length > 120)
      _posterAttempts.remove(_posterAttempts.keys.first);
    _posterAttempts[key] = DateTime.now();
    _metadataBusy = true;
    try {
      final uri = Uri.tryParse(source);
      if (_isSocialLink(source)) {
        final media = await MayaResolvedMedia.load(Uri.parse(source));
        await remember(source, media.thumbnail);
      } else if (uri != null &&
          _isMayaJaalHost(uri.host) &&
          uri.pathSegments.length == 2 &&
          uri.pathSegments.first == 'channel' &&
          (uri.queryParameters['post'] ?? '').isNotEmpty) {
        final post = await MayaChannelsApi.request(
          '/${Uri.encodeComponent(uri.pathSegments[1])}/posts/${Uri.encodeComponent(uri.queryParameters['post']!)}',
        );
        await remember(source, '${post['thumbnail'] ?? ''}');
      }
    } catch (_) {
    } finally {
      _metadataBusy = false;
    }
    return true;
  }

  static final _memory = <String, String>{};
  static final _pending = <String>{};
  static Future<void> _writes = Future<void>.value();
  static String _key(String source) =>
      '${FirebaseAuth.instance.currentUser?.uid ?? 'guest'}:${MayaCommunityApi.videoKey('', source)}';
  static String? peek(String source) =>
      source.isEmpty ? null : _memory[_key(source)];
  static Future<String?> read(String source) async {
    if (source.isEmpty) return null;
    final key = _key(source);
    if (_memory.containsKey(key)) return _memory[key];
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('media_poster_v3_$key');
    if (value != null) _put(key, value);
    return value;
  }

  static void _put(String key, String value) {
    if (_memory[key] == value) return;
    if (_memory.length >= 60) _memory.remove(_memory.keys.first);
    _memory[key] = value;
    changed.value++;
  }

  static Future<void> remember(String source, String image) async {
    if (source.isEmpty || image.isEmpty) return;
    final key = _key(source);
    if (!_pending.add(key)) return;
    final client = http.Client();
    ui.Codec? codec;
    ui.Image? picture;
    try {
      final cached = await read(source);
      if (cached != null) return;
      List<int> bytes;
      if (image.startsWith('https://')) {
        final response = await client
            .send(http.Request('GET', Uri.parse(image)))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode != 200 ||
            !(response.headers['content-type'] ?? '').startsWith('image/'))
          return;
        bytes = <int>[];
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 8),
        )) {
          bytes.addAll(chunk);
          if (bytes.length > 4 * 1024 * 1024) return;
        }
      } else {
        bytes = base64Decode(image);
      }
      codec = await ui.instantiateImageCodec(
        Uint8List.fromList(bytes),
        targetWidth: 360,
        allowUpscaling: false,
      );
      picture = (await codec.getNextFrame()).image;
      final data = await picture.toByteData(format: ui.ImageByteFormat.png);
      if (data == null || data.lengthInBytes > 512 * 1024) return;
      final value = base64Encode(data.buffer.asUint8List());
      _put(key, value);
      final next = _writes.then((_) async {
        final prefs = await SharedPreferences.getInstance();
        final keys = prefs.getStringList('media_poster_v3_index') ?? <String>[];
        keys.remove(key);
        keys.insert(0, key);
        await prefs.setString('media_poster_v3_$key', value);
        for (final old in keys.skip(60)) {
          await prefs.remove('media_poster_v3_$old');
        }
        await prefs.setStringList(
          'media_poster_v3_index',
          keys.take(60).toList(),
        );
      });
      _writes = next.catchError((Object _) {});
      await next;
    } catch (_) {
    } finally {
      client.close();
      picture?.dispose();
      codec?.dispose();
      _pending.remove(key);
    }
  }
}

class _MayaPoster extends StatefulWidget {
  const _MayaPoster({
    required this.thumb,
    required this.title,
    this.isSmall = false,
    this.sourceUrl = '',
    this.fit = BoxFit.cover,
  });
  final String? thumb;
  final String sourceUrl;
  final String title;
  final bool isSmall;
  final BoxFit fit;
  @override
  State<_MayaPoster> createState() => _MayaPosterState();
}

class _MayaPosterState extends State<_MayaPoster> {
  ImageProvider? _image;
  String _activeThumb = '';
  bool _broken = false, _recovering = false, _attempted = false;
  Timer? _posterTimer;
  @override
  void initState() {
    super.initState();
    MayaPosterCache.changed.addListener(_cacheChanged);
    _read();
    unawaited(_loadCached());
    _posterTimer = Timer.periodic(
      const Duration(milliseconds: 650),
      (_) => _recoverVisible(),
    );
  }

  void _cacheChanged() {
    final cached = MayaPosterCache.peek(widget.sourceUrl);
    if (mounted && cached != null && cached != _activeThumb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _read();
          setState(() {});
        }
      });
    }
  }

  Future<void> _loadCached() async {
    if (widget.sourceUrl.isNotEmpty) {
      await MayaPosterCache.read(widget.sourceUrl);
      if (mounted) {
        _read();
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _posterTimer?.cancel();
    MayaPosterCache.changed.removeListener(_cacheChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MayaPoster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thumb != widget.thumb ||
        oldWidget.sourceUrl != widget.sourceUrl) {
      _attempted = false;
      _read();
      unawaited(_loadCached());
    }
  }

  void _read() {
    final thumb = MayaPosterCache.peek(widget.sourceUrl) ?? widget.thumb ?? '';
    if (thumb == _activeThumb) return;
    _activeThumb = thumb;
    _broken = false;
    try {
      if (thumb.isEmpty) {
        _image = null;
      } else if (thumb.startsWith('http')) {
        _image = NetworkImage(thumb);
      } else {
        _image = MemoryImage(base64Decode(thumb));
      }
    } catch (_) {
      _image = null;
    }
  }

  Future<void> _recoverVisible() async {
    if (!mounted ||
        _attempted ||
        _recovering ||
        widget.sourceUrl.isEmpty ||
        (_image != null && !_broken) ||
        !(ModalRoute.of(context)?.isCurrent ?? true) ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)
      return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final viewport = Offset.zero & MediaQuery.sizeOf(context);
    if (!rect.overlaps(viewport)) return;
    _recovering = true;
    try {
      _attempted = await MayaPosterCache.recover(widget.sourceUrl);
    } finally {
      _recovering = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      _image == null
          ? buildAutoThumbnail(widget.title, isSmall: widget.isSmall)
          : Image(
            image: _image!,
            fit: widget.fit,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) {
              _broken = true;
              return buildAutoThumbnail(widget.title, isSmall: widget.isSmall);
            },
          );
}

const _mayaMint = Color(0xFF69E6A6);

class MayaBrandTitle extends StatelessWidget {
  const MayaBrandTitle({super.key, this.section});
  final String? section;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
              errorBuilder:
                  (_, __, ___) => const Icon(
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
            fontFamily: 'sans-serif',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const Text(
          'Jaal',
          style: TextStyle(
            fontFamily: 'sans-serif',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppThemes.kGreen,
          ),
        ),
        if (section != null) ...[
          const SizedBox(width: 10),
          Text(
            section!,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _mayaMint,
            ),
          ),
        ],
      ],
    ),
  );
}

class MayaSectionTitle extends StatelessWidget {
  const MayaSectionTitle(this.label, this.icon, {super.key});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: _mayaMint, size: 23),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Roboto',
            color: Colors.white,
            fontSize: 20,
            letterSpacing: .15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// GLOBAL MEDIA THUMBNAIL DISPATCHER
// ═══════════════════════════════════════════════════════════════════════════════
String _storedVideoThumbnail(Map<dynamic, dynamic> data) {
  for (final key in const ['thumbnail', 'thumbnailUrl', 'thumb', 'poster']) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.length > 80 &&
        !value.startsWith('http') &&
        !value.startsWith('/'))
      return value;
  }
  for (final key in const [
    'thumbnailUrl',
    'thumbnail',
    'thumbnail_url',
    'thumbUrl',
    'thumb',
    'poster',
    'posterUrl',
  ]) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isEmpty || value == 'null') continue;
    if (value.startsWith('/') && !value.startsWith('//'))
      return '$kBackendBaseUrl$value';
    return value;
  }
  return '';
}

Widget buildMediaThumbnail(
  String? thumb,
  String title,
  String videoUrl, {
  bool isSmall = false,
  bool loopPreview = false,
  String sourceUrl = '',
  BoxFit fit = BoxFit.cover,
  void Function(String base64Thumb)? onFrameCaptured,
}) {
  if (loopPreview && (videoUrl.isNotEmpty || _isSocialLink(sourceUrl))) {
    return VideoLoopThumbnail(
      videoUrl: videoUrl.isEmpty ? sourceUrl : videoUrl,
      title: title,
      isSmall: isSmall,
      fallbackThumb: thumb,
      onFrameCaptured: onFrameCaptured,
      sourceUrl: sourceUrl,
      fit: fit,
    );
  }
  return _MayaPoster(
    thumb: thumb,
    title: title,
    isSmall: isSmall,
    sourceUrl: sourceUrl,
    fit: fit,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// 🆕 TERABOX API RESOLVER (With Cookie Support)
// ═══════════════════════════════════════════════════════════════════════════════
class TeraBoxResolver {
  static const endpoint = String.fromEnvironment('MAYAJAAL_TERABOX_RESOLVER');

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
      final api = Uri.tryParse(endpoint);
      if (api == null || api.scheme != 'https' || api.host.isEmpty) {
        return {
          'success': 'false',
          'error': 'TeraBox playback is temporarily unavailable.',
        };
      }
      final response = await http
          .post(
            api,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'url': teraboxUrl}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final videoUrl = Uri.tryParse(data['stream_url']?.toString() ?? '');
        if (data['success'] == true &&
            videoUrl != null &&
            videoUrl.scheme == 'https' &&
            videoUrl.host.isNotEmpty) {
          return {
            'success': 'true',
            'videoUrl': videoUrl.toString(),
            'fileName': data['name']?.toString() ?? 'TeraBox Video',
            'thumbnail': data['thumbnail']?.toString() ?? '',
            'size': data['size_formatted']?.toString() ?? 'Unknown',
            'owner': data['owner']?.toString() ?? 'Unknown',
          };
        }
      }
    } catch (e) {
      debugPrint('TeraBox Resolver Error: $e');
    }
    return {
      'success': 'false',
      'videoUrl': '',
      'fileName': '',
      'thumbnail': '',
    };
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
        if (!isBadTitle(c, videoId)) {
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
        t.toLowerCase() == 'mayajaal video' ||
        t.toLowerCase() == 'video';
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
          final uSnap =
              await FirebaseDatabase.instance.ref('users/$ownerUid').once();
          if (uSnap.snapshot.value != null && uSnap.snapshot.value is Map) {
            final u = Map<String, dynamic>.from(uSnap.snapshot.value as Map);
            final n = (u['name'] ?? '').toString().trim();
            final e = (u['email'] ?? '').toString().trim();
            if (n.isNotEmpty &&
                n.toLowerCase() != 'null' &&
                n.toLowerCase() != 'user') {
              ownerName = n;
            } else if (e.isNotEmpty) {
              ownerName = e.split('@').first;
            }
          }
        } catch (_) {}
      }

      if (ownerName.isEmpty &&
          uploader.isNotEmpty &&
          uploader.toLowerCase() != 'mayajaal' &&
          uploader.toLowerCase() != 'null') {
        ownerName = uploader.replaceAll('@', '').trim();
      }

      final display =
          ownerName.isNotEmpty
              ? (ownerName.startsWith('@') ? ownerName : '@$ownerName')
              : '@mayajaal';

      return {'display': display, 'name': ownerName, 'uid': ownerUid};
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
        stored = 'and-${a.id}-${a.model}'.replaceAll(
          RegExp(r'[^a-zA-Z0-9-]'),
          '',
        );
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
  static const _email = 'mayajaalsupport@gmail.com';
  static const _titles = {
    'privacy': 'Privacy Policy',
    'terms': 'Terms & Conditions',
    'dmca': 'DMCA & Copyright Policy',
    'partner': 'Creator Program Terms',
    'support': 'Help & Support',
  };

  static const _sections = <String, List<(String, String)>>{
    'privacy': [
      (
        'About this policy',
        'This policy explains how MayaJaal handles information when you use the Android app, web dashboard or official Telegram bots.',
      ),
      (
        '1. Information we collect',
        'We collect your verified email address and display name when you sign in. We process media and details such as file size and duration when you upload or convert a file. Watch history, likes, dislikes, saved videos and signed-in download history may be associated with your account. Downloaded files are stored on your device.',
      ),
      (
        '2. Device information and cookies',
        'We may collect device identifiers, IP address, operating system, browser information and playback quality to prevent abuse and troubleshoot streaming. Cookies and session data help keep you signed in and remember settings.',
      ),
      (
        '3. How we use information',
        'We use information to provide playback, link conversion, account features and support. We also use it for view counts, creator ranks and reminders sent 24 hours before eligible 28-day links expire.',
      ),
      (
        '4. Sharing information',
        'We do not sell, rent or trade creator data, viewing history or engagement records to advertisers. We may disclose information in response to valid legal requests.',
      ),
      (
        'Optional in-app advertising',
        'Where enabled, MayaJaal uses InMobi to deliver and measure ads. The SDK may process advertising identifiers, device and network information for advertising and fraud prevention. Non-targeted ads may be enabled where permitted for the app audience and region. Where consent is required, ads remain disabled until an appropriate choice is made. Manage or withdraw your choice in App Settings > Privacy preferences. Watching optional ads never creates cash or creator-view earnings. External sites may have their own advertising and privacy policies.',
      ),
      (
        '5. Content and sharing',
        'Creators choose where to share their links and are responsible for having permission to distribute the media they upload or convert.',
      ),
      (
        '6. Platform operations',
        'Use of the streaming and sharing features is governed by the Terms & Conditions and applicable policies.',
      ),
      (
        '7. Protecting information',
        'We use safeguards to protect account and service data. No internet transmission or storage method can guarantee absolute security.',
      ),
      (
        '8. Account and download choices',
        'You can manage your account in the app or dashboard. Delete completed files from the Downloads tab. To request permanent account and associated data deletion, use Delete My Account in the app or contact support for a verified request.',
      ),
      (
        '9. Children’s privacy',
        'We do not knowingly collect information from children below the applicable age of digital consent. A parent or guardian can request account deletion. We remove child sexual abuse material and cooperate with authorities as required.',
      ),
      (
        '10. Changes and contact',
        'We may publish updates to this policy. Continued use after a published revision is subject to the updated policy. Contact the compliance desk for privacy questions.',
      ),
    ],
    'terms': [
      (
        'Using MayaJaal',
        'These terms apply to the Android app, web dashboard and official Telegram bots. By creating an account or using the service, you agree to these terms.',
      ),
      (
        '1. Acceptable use',
        'Only upload, convert or share content you have the right to use. Do not share unlawful content, violate privacy or copyright, disrupt the service or attempt unauthorized access.',
      ),
      (
        '2. Accounts and eligibility',
        'You must meet the applicable age of digital consent to create an account independently. Keep your account secure and review activity under it. MayaJaal may suspend or terminate accounts that violate these terms.',
      ),
      (
        '3. Privacy',
        'The Privacy Policy explains how we handle your information. MayaJaal does not sell creator analytics, settlement records or viewing histories.',
      ),
      (
        '4. Service and external sites',
        'MayaJaal is provided as available and as is. Third-party ads, sites and posts may be subject to separate policies and availability.',
      ),
      (
        '5. Link expiry and renewal',
        'Converted links have a 28-day default lifetime. The official expiry bot sends reminders 24 hours before expiration. Eligible links can be renewed during that window where renewal is available in the dashboard or app. Expired or inactive content may be removed under the storage policy.',
      ),
      (
        '6. App features',
        'MayaJaal supports playback history, saved videos, reactions, link sharing and downloads for supported files. Download availability and quality depend on the source. Do not automate engagement or manipulate view counts.',
      ),
      (
        '7. Intellectual property',
        'MayaJaal trademarks, logos and software are protected by applicable intellectual property laws.',
      ),
      (
        '8. Copyright complaints',
        'Rights holders and authorized representatives can use the reporting process in our DMCA & Copyright Policy.',
      ),
      (
        '9. Child safety',
        'Child sexual abuse material, underage explicit media and non-consensual sexual exploitation are prohibited. MayaJaal removes prohibited material, may terminate accounts and cooperates with authorities as required. Use the compliance email for urgent reports.',
      ),
      (
        '10. Traffic integrity',
        'Bot traffic, click farms, proxy networks, emulator farms and deceptive exchanges may lead to invalidated views and account action.',
      ),
      (
        '11. Limitation of liability',
        'To the extent permitted by law, MayaJaal and its operators are not liable for indirect, incidental, consequential, special or punitive losses arising from interruptions or third-party service failures.',
      ),
      (
        '12. Governing law and changes',
        'These terms are governed by the laws of India. MayaJaal may publish revised terms. Contact the compliance desk with questions.',
      ),
    ],
    'dmca': [
      (
        'About this policy',
        'This policy describes how to report suspected copyright infringement and request review of a takedown under applicable law, including 17 U.S.C. § 512 where applicable.',
      ),
      (
        '1. Private content',
        'MayaJaal does not provide a public search index of private content. Creators decide whether to share their converted links publicly.',
      ),
      (
        '2. Reviewing claims',
        'Creators are responsible for their right to share content. Rights holders and authorized representatives can submit a written notice for review.',
      ),
      (
        '3. What to include in a notice',
        'Include your physical or electronic signature, identification of the copyrighted work, exact MayaJaal links to the reported material, and your name, address, phone number and email. If you represent the rights holder, explain your authority.\n\nInclude a statement that you have a good-faith belief that the use is unauthorized by the rights holder, their agent or the law. State that the information is accurate and, under penalty of perjury, that you own or are authorized to act for the owner of the exclusive right at issue.',
      ),
      (
        '4. Sending the notice',
        'Put your notice and exact URLs in the body of a plain-text email to the compliance desk. General domain names or file names are insufficient. Executables, encrypted archives and unsolicited download attachments will not be reviewed.',
      ),
      (
        '5. Review and takedown',
        'MayaJaal reviews notices and acts promptly on valid reports. Access to identified content may be disabled or removed. To dispute a takedown, contact the compliance desk and include the affected links and reason for review.',
      ),
      (
        '6. Repeat infringement',
        'Accounts with verified repeat violations may lose streaming privileges and access to their account.',
      ),
    ],
    'partner': [
      (
        'Who these terms apply to',
        'These terms govern MayaJaal creator participation, qualified views, ranking and content sharing.',
      ),
      (
        '1. Qualified views',
        'A qualified view requires a genuine signed-in viewer to start playback and watch continuously for at least 10 seconds. Automated loops, refreshes and scripts do not count.',
      ),
      (
        '2. Fraud and artificial traffic',
        'Using multiple accounts to inflate views, fake self-clicks, bots, click farms, emulators, proxy networks or deceptive traffic exchanges is prohibited. MayaJaal may invalidate views or suspend or terminate accounts for violations.',
      ),
      (
        '3. Authentication',
        'Use an eligible Gmail account and sign in through Google. Attempts to abuse the sign-in process may trigger a temporary restriction. Keep your account and any creator credentials private.',
      ),
      (
        '4. Link renewal',
        'Converted links have a 28-day default lifetime. The expiry bot alerts creators 24 hours before expiration. Deactivated links stop earning views.',
      ),
      (
        '5. Creator ranks',
        'Cyber Rank reflects cumulative verified views. A rank does not guarantee payment.',
      ),
      (
        '6. Independent participation',
        'Participation does not establish employment, agency, a franchise or a financial relationship with MayaJaal.',
      ),
    ],
    'support': [
      (
        'About MayaJaal',
        'MayaJaal brings media playback, downloads, public channels and your personal library together. Use Home to paste a link, Telegram to browse shared links, Channels to explore public posts, and History to find videos you watched.',
      ),
      (
        'Open a shared link',
        'From YouTube, Instagram or Facebook, tap Share and choose MayaJaal. You can also paste the link in Home. The media page opens without a countdown. Use Play to watch, or choose a download quality when the source makes one available. Supported TeraBox links use the 10-second preview and Play flow.',
      ),
      (
        'Downloading and Completed',
        'When a download starts, the Downloads screen shows its progress. Open Completed to play saved videos, view photos or open documents in a compatible viewer. Use Delete to remove a saved file. Signed-in download history syncs when connected.',
      ),
      (
        'Public channels',
        'Browse channels and like posts when signed in. Channel owners can publish posts, manage admins, transfer ownership or delete their channel. Where media uploads are available, attached files are reviewed before they appear publicly.',
      ),
      (
        'Your account and policies',
        'You can revisit watch history and saved videos in the app. Open the menu for Privacy Policy, Terms & Conditions, DMCA & Copyright Policy, Creator Program Terms or Help & Support. Use Delete My Account to request permanent account removal.',
      ),
      (
        'Get help',
        'Contact us for app troubleshooting, official Telegram bot setup, link renewal or account recovery. Include the affected feature and the error message, and avoid sending passwords or verification codes.',
      ),
      (
        'Response times',
        'Automated support is available 24/7. We aim to respond within 12–24 business hours.',
      ),
    ],
  };

  static Future<void> _open(BuildContext context, Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (!context.mounted) return;
    await Clipboard.setData(
      ClipboardData(text: uri.scheme == 'mailto' ? uri.path : uri.toString()),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the link. Copied to clipboard.'),
        ),
      );
    }
  }

  static void showPolicy(BuildContext context, String type) {
    final title = _titles[type];
    final sections = _sections[type];
    if (title == null || sections == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (pageContext) => Scaffold(
              backgroundColor: AppThemes.kBg,
              appBar: AppBar(
                automaticallyImplyLeading: false,
                title: Text(title),
                actions: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(pageContext).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ],
              ),
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    if (type != 'support' && type != 'dmca')
                      const Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: Text(
                          'Effective October 2026',
                          style: TextStyle(color: AppThemes.kDimGreen),
                        ),
                      ),
                    for (final (heading, body) in sections) ...[
                      Text(
                        heading,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppThemes.kGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.55,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.email_outlined),
                      title: const Text(_email),
                      subtitle: const Text(
                        'Official compliance and support email',
                      ),
                      onTap:
                          () => _open(
                            pageContext,
                            Uri(scheme: 'mailto', path: _email),
                          ),
                    ),
                    if (type == 'support') ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.send_outlined),
                        title: const Text('@MayaJaalSupport'),
                        subtitle: const Text('Telegram Helpdesk'),
                        onTap:
                            () => _open(
                              pageContext,
                              Uri.https('t.me', '/MayaJaalSupport'),
                            ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.photo_camera_outlined),
                        title: const Text('@maya_jaal_official'),
                        subtitle: const Text(
                          'Instagram updates and creator announcements',
                        ),
                        onTap:
                            () => _open(
                              pageContext,
                              Uri.https(
                                'www.instagram.com',
                                '/maya_jaal_official/',
                              ),
                            ),
                      ),
                    ],
                    for (final related in const ['privacy', 'terms', 'dmca'])
                      if (related != type && type != 'support')
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_titles[related]!),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => showPolicy(pageContext, related),
                        ),
                  ],
                ),
              ),
            ),
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
  return mayaCoreLocales[lang]?[key] ??
      localizedStrings[lang]?[key] ??
      mayaCoreLocales['English']?[key] ??
      localizedStrings['English']?[key] ??
      key;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HAPTIC FEEDBACK CONTROLLER
// ═══════════════════════════════════════════════════════════════════════════════
class Haptic {
  static Future<void> light() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static Future<void> medium() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static Future<void> heavy() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  static Future<void> selection() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
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

  static bool isAccountOldEnough(
    User user, {
    int seconds = kMinAccountAgeSeconds,
  }) {
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
        await ref.update({'lastSeen': DateTime.now().millisecondsSinceEpoch});
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
            if (File(p).existsSync()) {
              rooted = true;
              break;
            }
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
        attempts =
            (jsonDecode(raw) as List).map((e) => (e as num).toInt()).toList();
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
        attempts =
            (jsonDecode(raw) as List).map((e) => (e as num).toInt()).toList();
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
      debugPrint(
        '⚠️ Emulator detected (logged, not blocked): ${device['model']}',
      );
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
    {
      'name': 'Neon Rookie',
      'emoji': '🥉',
      'color': AppThemes.kSilver,
      'min': 0,
    },
    {
      'name': 'Cyber Trader',
      'emoji': '🥈',
      'color': AppThemes.kNeonCyan,
      'min': 1000,
    },
    {
      'name': 'Matrix Master',
      'emoji': '🥇',
      'color': AppThemes.kGreen,
      'min': 10000,
    },
    {
      'name': 'Quantum Elite',
      'emoji': '💎',
      'color': AppThemes.kNeonPurple,
      'min': 100000,
    },
    {
      'name': 'MayaJaal Legend',
      'emoji': '👑',
      'color': AppThemes.kGold,
      'min': 1000000,
    },
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
    if (user == null)
      throw FirebaseAuthException(
        code: 'unknown',
        message: 'No user returned.',
      );

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
      await OneSignal.logout();
    } catch (_) {}
    try {
      final googleSignIn = GoogleSignIn(serverClientId: webClientId);
      try {
        await googleSignIn.signOut();
      } catch (_) {}
      try {
        await googleSignIn.disconnect();
      } catch (_) {}
    } catch (_) {}

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
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
      throw FirebaseAuthException(
        code: 'no-user',
        message: 'No user logged in.',
      );
    }

    final uid = user.uid;
    final deviceId = await DeviceIdHelper.get();

    try {
      // Remove owned channel content and memberships while the sign-in is valid.
      try {
        await MayaChannelsApi.request('/account/data', method: 'DELETE');
      } on HttpException catch (error) {
        if (error.message != 'Not Found' &&
            !error.message.startsWith('Install the updated channels service'))
          rethrow;
      }
      // Remove this account's comments and reactions before deleting its sign-in.
      try {
        await MayaCommunityApi.request('/account', method: 'DELETE');
      } on HttpException catch (error) {
        if (!error.message.contains('not installed')) rethrow;
      }
      // 1. Wipe user profile node
      await _rtdb.child('users/$uid').remove();

      // 2. Wipe device binding
      try {
        await _rtdb.child('deviceBindings/$deviceId').remove();
      } catch (_) {}

      // 3. Wipe all video links owned by this user
      try {
        final linksSnap =
            await _rtdb
                .child('links')
                .orderByChild('ownerUid')
                .equalTo(uid)
                .once();
        if (linksSnap.snapshot.value != null &&
            linksSnap.snapshot.value is Map) {
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
        if (linksSnap.snapshot.value != null &&
            linksSnap.snapshot.value is Map) {
          final allLinks = Map<String, dynamic>.from(
            linksSnap.snapshot.value as Map,
          );
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

      final url = Uri.parse(
        '$kBackendBaseUrl/api/user-stats?key=$apiKey&uid=$cachedUid',
      );
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
      final snap =
          await _rtdb
              .child('links')
              .orderByChild('ownerUid')
              .equalTo(cachedUid!)
              .once();
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

  static Future<List<Map<String, dynamic>>> getUserLinks({
    int limit = 50,
  }) async {
    if (cachedUid == null) return [];
    try {
      final snap =
          await _rtdb
              .child('links')
              .orderByChild('ownerUid')
              .equalTo(cachedUid!)
              .once();
      final val = snap.snapshot.value;
      if (val == null) return [];
      final map = Map<String, dynamic>.from(val as Map);
      final arr =
          map.entries.map((e) {
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
    return {'tier': 4 + (views ~/ 10000), 'next': 10000 - (views % 10000)};
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIREBASE SERVICE — REALTIME CLOUD INTEGRATION & NOTIFICATIONS
// ═══════════════════════════════════════════════════════════════════════════════
class FirebaseService {
  static final _noticeRefresh = ValueNotifier<int>(0);
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
    late StreamController<List<Map<String, dynamic>>> output;
    StreamSubscription<DatabaseEvent>? subscription;
    Timer? timer;
    var firebaseRows = <Map<String, dynamic>>[],
        channelRows = <Map<String, dynamic>>[];
    var polling = false;
    void emit() {
      if (output.isClosed) return;
      final rows = [...firebaseRows, ...channelRows];
      rows.sort(
        (a, b) =>
            ((b['time'] as num?) ?? 0).compareTo((a['time'] as num?) ?? 0),
      );
      output.add(rows);
    }

    Future<void> poll() async {
      if (polling || FirebaseAuth.instance.currentUser?.uid != uid) return;
      polling = true;
      try {
        final result = await MayaChannelsApi.request('/account/notifications');
        channelRows =
            (result['notifications'] as List? ?? [])
                .whereType<Map>()
                .map((r) => Map<String, dynamic>.from(r))
                .toList();
        emit();
      } catch (_) {
        // Keep the existing Firebase inbox available during a network outage.
      } finally {
        polling = false;
      }
    }

    void refresh() => unawaited(poll());
    output = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        subscription = _rtdb.child('users/$uid/notifications').onValue.listen((
          event,
        ) {
          final value = event.snapshot.value;
          firebaseRows =
              value is Map
                  ? value.entries.where((e) => e.value is Map).map((e) {
                    final row = Map<String, dynamic>.from(e.value as Map);
                    row['id'] = '${e.key}';
                    return row;
                  }).toList()
                  : [];
          emit();
        }, onError: (_) => emit());
        _noticeRefresh.addListener(refresh);
        unawaited(poll());
        timer = Timer.periodic(
          const Duration(seconds: 15),
          (_) => unawaited(poll()),
        );
      },
      onCancel: () async {
        timer?.cancel();
        _noticeRefresh.removeListener(refresh);
        await subscription?.cancel();
      },
    );
    return output.stream;
  }

  static Future<void> markNotificationRead(String uid, String notifId) async {
    try {
      if (notifId.startsWith('channel_')) {
        await MayaChannelsApi.request(
          '/account/notifications/read',
          method: 'POST',
          body: {'id': notifId},
        );
        _noticeRefresh.value++;
        return;
      }
      await _rtdb.child('users/$uid/notifications/$notifId/read').set(true);
    } catch (_) {}
  }

  static Future<void> markAllRead(String uid) async {
    try {
      await MayaChannelsApi.request(
        '/account/notifications/read',
        method: 'POST',
        body: {},
      );
      _noticeRefresh.value++;
    } catch (_) {}
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

  static Stream<int> getUnreadCount(String uid) => getNotifications(
    uid,
  ).map((rows) => rows.where((r) => r['read'] != true).length);

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

  static Future<void> updateProfile(
    String uid,
    Map<String, dynamic> data,
  ) async {
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

  static Future<bool> isSubscribed(
    String subscriberUid,
    String channelUid,
  ) async {
    try {
      final snap =
          await _rtdb.child('subscriptions/$channelUid/$subscriberUid').once();
      return snap.snapshot.value != null;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> toggleSubscription(
    String subscriberUid,
    String channelUid,
  ) async {
    try {
      final ref = _rtdb.child('subscriptions/$channelUid/$subscriberUid');
      final snap = await ref.once();
      final isSubbed = snap.snapshot.value != null;

      if (isSubbed) {
        await ref.remove();
        await _rtdb.child('userSubs/$subscriberUid/$channelUid').remove();

        await _rtdb.child('users/$channelUid/subscribersCount').runTransaction((
          mutableData,
        ) {
          int count = 0;
          if (mutableData != null && mutableData is int) {
            count = mutableData;
          }
          return Transaction.success(math.max(0, count - 1));
        });

        return false;
      } else {
        await ref.set(DateTime.now().millisecondsSinceEpoch);
        await _rtdb
            .child('userSubs/$subscriberUid/$channelUid')
            .set(DateTime.now().millisecondsSinceEpoch);

        await _rtdb.child('users/$channelUid/subscribersCount').runTransaction((
          mutableData,
        ) {
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

  static Future<List<Map<String, dynamic>>> getUserVideos(
    String uid, {
    int limit = 30,
  }) async {
    try {
      final snap =
          await _rtdb
              .child('links')
              .orderByChild('ownerUid')
              .equalTo(uid)
              .once();
      final val = snap.snapshot.value;
      if (val == null) return [];
      final map = Map<String, dynamic>.from(val as Map);
      final list =
          map.entries.map((e) {
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
      final all =
          map.entries
              .map((e) {
                final d = Map<String, dynamic>.from(e.value as Map);
                d['id'] = e.key;
                return d;
              })
              .where((v) => v['id'] != currentVideoId)
              .toList();

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

      final sorted = List<Map<String, dynamic>>.from(all)..sort(
        (a, b) =>
            ((b['views'] ?? 0) as int).compareTo((a['views'] ?? 0) as int),
      );
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

  static Future<bool> toggleLike(
    String videoId,
    String uid,
    String ownerUid,
    String videoTitle,
  ) async {
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
        await _rtdb
            .child('links/$videoId/shares/$id')
            .set(DateTime.now().millisecondsSinceEpoch);
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
  const RealFireParticles({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  State<RealFireParticles> createState() => _RealFireParticlesState();
}

class _RealFireParticlesState extends State<RealFireParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_Particle> _particles = [];
  final math.Random _rand = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..repeat();
    _ctrl.addListener(() {
      if (!mounted) return;
      setState(() {
        // Naye particles add karein
        if (_particles.length < 60) {
          _particles.add(
            _Particle(
              x: _rand.nextDouble() * widget.width,
              y: widget.height,
              vx: (_rand.nextDouble() - 0.5) * 2,
              vy: -(1.5 + _rand.nextDouble() * 3),
              radius: 4 + _rand.nextDouble() * 8,
              life: 1.0,
              color:
                  _rand.nextBool()
                      ? AppThemes.kFireOrange
                      : AppThemes.kFireYellow,
            ),
          );
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
class NotificationDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> notification;
  const NotificationDetailsScreen({super.key, required this.notification});
  @override
  State<NotificationDetailsScreen> createState() =>
      _NotificationDetailsScreenState();
}

class _NotificationDetailsScreenState extends State<NotificationDetailsScreen> {
  bool _busy = false;
  late String _status = '${widget.notification['request_status'] ?? ''}';
  Future<void> _respond(bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await MayaChannelsApi.request(
        '/account/requests/${widget.notification['request_id']}/respond',
        method: 'POST',
        body: {'accept': accept},
      );
      FirebaseService._noticeRefresh.value++;
      if (mounted) setState(() => _status = '${result['status']}');
    } catch (e) {
      if (mounted) _channelNotice(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final date =
        DateTime.fromMillisecondsSinceEpoch(
          (n['time'] as num?)?.toInt() ?? 0,
        ).toLocal();
    return Scaffold(
      backgroundColor: AppThemes.kBg,
      appBar: AppBar(title: const Text('Notification')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Icon(
              Icons.notifications_active_outlined,
              size: 38,
              color: _mayaMint,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '${n['title'] ?? 'Notification'}',
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${date.day}/${date.month}/${date.year} · ${TimeOfDay.fromDateTime(date).format(context)}',
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 24),
          SelectableText(
            '${n['message'] ?? ''}',
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              height: 1.6,
            ),
          ),
          if (n['request_id'] != null &&
              n['type'] == 'channel_role_request') ...[
            const SizedBox(height: 24),
            if (_status == 'pending')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _respond(false),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : () => _respond(true),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              )
            else
              Text(
                'Request $_status',
                style: const TextStyle(color: _mayaMint),
              ),
          ],
          if (n['channel_id'] != null) ...[
            const SizedBox(height: 24),
            TextButton.icon(
              icon: const Icon(Icons.forum_outlined),
              label: const Text('Open channel'),
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => MayaChannelPage(
                            channel: ChannelScreen.channels.child(
                              '${n['channel_id']}',
                            ),
                          ),
                    ),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showMayaNotificationSettings(BuildContext context) async {
  try {
    final data = await MayaChannelsApi.request(
      '/account/notification-preferences',
    );
    if (!context.mounted) return;
    var enabled = data['push'] == true;
    var saving = false;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (sheet) => StatefulBuilder(
            builder:
                (c, update) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ListTile(
                        title: Text(
                          'Notification preferences',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          'Your in-app notifications always stay in the bell inbox.',
                        ),
                      ),
                      SwitchListTile(
                        title: const Text('Notify me on this phone'),
                        subtitle: const Text(
                          'Channel updates, reactions and invitations',
                        ),
                        value: enabled,
                        onChanged:
                            saving
                                ? null
                                : (value) async {
                                  update(() => saving = true);
                                  try {
                                    if (value) {
                                      final allowed = await _PermissionQueue.run(
                                        () => OneSignal
                                            .Notifications.requestPermission(
                                          true,
                                        ),
                                      );
                                      if (!allowed) {
                                        if (c.mounted)
                                          _channelNotice(
                                            c,
                                            'Allow notifications in your phone settings.',
                                          );
                                        return;
                                      }
                                      final uid =
                                          FirebaseAuth
                                              .instance
                                              .currentUser
                                              ?.uid;
                                      if (uid == null) return;
                                      await OneSignal.login(uid);
                                      await OneSignal.User.pushSubscription
                                          .optIn();
                                    } else {
                                      await OneSignal.User.pushSubscription
                                          .optOut();
                                    }
                                    final result =
                                        await MayaChannelsApi.request(
                                          '/account/notification-preferences',
                                          method: 'PATCH',
                                          body: {'push': value},
                                        );
                                    if (c.mounted) {
                                      update(() => enabled = value);
                                      if (value &&
                                          result['push_configured'] != true)
                                        _channelNotice(
                                          c,
                                          'Preference saved. Phone alerts are temporarily unavailable.',
                                        );
                                    }
                                  } catch (e) {
                                    if (c.mounted) _channelNotice(c, e);
                                  } finally {
                                    if (c.mounted) update(() => saving = false);
                                  }
                                },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
          ),
    );
  } catch (e) {
    if (context.mounted) _channelNotice(context, e);
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
            margin: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              left: 12,
              right: 12,
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.65,
            ),
            decoration: BoxDecoration(
              color: AppThemes.kCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppThemes.kBorder),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black87,
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
                          border: Border.all(color: AppThemes.kBorder),
                        ),
                        child: const Icon(
                          Icons.notifications_active,
                          color: AppThemes.kGreen,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Notifications',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Mark all read',
                        icon: const Icon(Icons.done_all, size: 20),
                        onPressed: () {
                          SoundService.playClick();
                          FirebaseService.markAllRead(uid);
                        },
                      ),
                      IconButton(
                        tooltip: 'Notification preferences',
                        icon: const Icon(Icons.tune, size: 20),
                        onPressed: () {
                          Navigator.pop(ctx);
                          showMayaNotificationSettings(context);
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white60,
                          size: 18,
                        ),
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
                              Icon(
                                Icons.notifications_off_outlined,
                                color: Colors.white24,
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'No new notifications',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: list.length,
                        separatorBuilder:
                            (_, __) =>
                                const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (c, i) {
                          final item = list[i];
                          final isRead = item['read'] == true;
                          final time = item['time'] as int? ?? 0;
                          final dt = DateTime.fromMillisecondsSinceEpoch(time);

                          return ListTile(
                            onTap: () {
                              SoundService.playClick();
                              if (!isRead) {
                                FirebaseService.markNotificationRead(
                                  uid,
                                  item['id'] as String,
                                );
                              }
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => NotificationDetailsScreen(
                                        notification: item,
                                      ),
                                ),
                              );
                            },
                            title: Text(
                              item['title'] ?? '',
                              style: TextStyle(
                                color: isRead ? Colors.white60 : Colors.white,
                                fontWeight:
                                    isRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                fontSize: 15,
                                fontFamily: 'Roboto',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              item['message'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                                height: 1.4,
                                fontFamily: 'Roboto',
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!isRead)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(bottom: 4),
                                    decoration: const BoxDecoration(
                                      color: AppThemes.kRed,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                Text(
                                  '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                    fontSize: 9.0,
                                  ),
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
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLOUD-SYNCED WATCH HISTORY & SAVED VIDEOS
// ═══════════════════════════════════════════════════════════════════════════════
class WatchHistory {
  static final savedChanges = ValueNotifier<int>(0);
  static Future<void> _cloudWriteChain = Future<void>.value();
  static final changes = ValueNotifier<int>(0);
  static Future<void> _writeChain = Future<void>.value();
  static Future<void> _exclusive(Future<void> Function() action) {
    final next = _writeChain.then((_) => action());
    _writeChain = next.catchError((Object _) {});
    return next;
  }

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  static String get _historyKey => 'watch_history_v2_$_uid';
  static String get _savedKey => 'saved_videos_v1_$_uid';

  static DatabaseReference get _rtdb => FirebaseDatabase.instance.ref();

  static String recordKey(Map<String, dynamic> item) {
    final url = item['url']?.toString() ?? '';
    if (_isSocialLink(url)) return MayaCommunityApi.videoKey('', url);
    final id = item['id']?.toString() ?? '';
    return id.isNotEmpty ? id : url;
  }

  static List<Map<String, dynamic>> localRecords(
    SharedPreferences prefs,
    String key,
  ) {
    try {
      final data = jsonDecode(prefs.getString(key) ?? '[]');
      if (data is List) {
        final records = data.whereType<Map>().map(
          (item) => Map<String, dynamic>.from(item),
        );
        return (key.startsWith('watch_history_v2_')
                ? records.take(20)
                : records)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static int recordedAt(Map<String, dynamic> item) =>
      DateTime.tryParse(
        item['time']?.toString() ?? '',
      )?.millisecondsSinceEpoch ??
      (item['syncedAt'] is num ? (item['syncedAt'] as num).toInt() : 0);

  static List<Map<String, dynamic>> mergeRecords(
    Iterable<Map<String, dynamic>> records, {
    int limit = 20,
  }) {
    final sorted =
        records.toList()
          ..sort((a, b) => recordedAt(b).compareTo(recordedAt(a)));
    final byId = <String, Map<String, dynamic>>{};
    for (final record in sorted) {
      final key = recordKey(record);
      if (key.isEmpty) continue;
      final existing = byId.putIfAbsent(key, () => {...record});
      if (_storedVideoThumbnail(existing).isEmpty) {
        final thumb = _storedVideoThumbnail(record);
        if (thumb.isNotEmpty) existing['thumbnail'] = thumb;
      }
    }
    return byId.values.take(limit).toList();
  }

  static Future<void> recordPlayback(Map<String, dynamic> item) {
    final uid = _uid;
    return _exclusive(() async {
      final key = 'watch_history_v2_$uid';
      try {
        final prefs = await SharedPreferences.getInstance();
        final records = mergeRecords([item, ...localRecords(prefs, key)]);
        await prefs.setString(key, jsonEncode(records));
        changes.value++;
        if (_uid == uid) {
          unawaited(
            syncWatchRecordCloud(
              records.firstWhere(
                (record) => recordKey(record) == recordKey(item),
                orElse: () => item,
              ),
            ),
          );
        }
      } catch (_) {}
    });
  }

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
        final snap =
            await _rtdb
                .child('users/$_uid/watchHistory')
                .limitToLast(limit)
                .once();
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

  static Future<void> saveThumbnail(String url, String base64Thumb) {
    final uid = _uid;
    if (url.isEmpty || base64Thumb.isEmpty) return Future<void>.value();
    return _exclusive(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        for (final key in ['watch_history_v2_$uid', 'saved_videos_v1_$uid']) {
          final records = localRecords(prefs, key);
          Map<String, dynamic>? changed;
          for (final item in records) {
            if (item['url'] == url &&
                (_storedVideoThumbnail(item).isEmpty ||
                    _storedVideoThumbnail(item).startsWith('https://'))) {
              item['thumbnail'] = base64Thumb;
              changed = item;
            }
          }
          if (changed != null) {
            await prefs.setString(key, jsonEncode(records));
            if (key.startsWith('watch_history') && _uid == uid)
              unawaited(syncWatchRecordCloud(changed));
          }
        }
        changes.value++;
        savedChanges.value++;
      } catch (_) {}
    });
  }

  static Future<void> syncWatchRecordCloud(Map<String, dynamic> item) {
    final uid = _uid;
    final next = _cloudWriteChain.then((_) async {
      if (uid == 'guest' || _uid != uid) return;
      try {
        final root = _rtdb.child('users/$uid/watchHistory');
        final safeKey = recordKey(item);
        await root.child(safeKey).set({
          ...item,
          'syncedAt': DateTime.now().millisecondsSinceEpoch,
        });
        final snapshot = await root.get();
        if (_uid != uid) return;
        final rows =
            snapshot.children.where((c) => c.value is Map).toList()..sort(
              (a, b) => recordedAt(
                Map<String, dynamic>.from(b.value as Map),
              ).compareTo(
                recordedAt(Map<String, dynamic>.from(a.value as Map)),
              ),
            );
        final removed = <String, Object?>{
          for (final row in rows.skip(20)) row.key!: null,
        };
        if (removed.isNotEmpty) await root.update(removed);
      } catch (e) {
        debugPrint('History sync: $e');
      }
    });
    _cloudWriteChain = next.catchError((Object _) {});
    return next;
  }

  static Future<void> syncSavedRecordCloud(
    Map<String, dynamic> item,
    bool isAdd,
  ) async {
    savedChanges.value++;
    final uid = _uid;
    if (uid == 'guest') return;
    try {
      final root = _rtdb.child('users/$uid/savedVideos');
      final canonical = recordKey(item);
      final snapshot = await root.get();
      if (_uid != uid) return;
      final updates = <String, Object?>{};
      for (final child in snapshot.children) {
        if (child.value is Map &&
            recordKey(Map<String, dynamic>.from(child.value as Map)) ==
                canonical) {
          updates[child.key!] = null;
        }
      }
      if (isAdd)
        updates[canonical] = {
          ...item,
          'savedAt': DateTime.now().millisecondsSinceEpoch,
        };
      if (updates.isNotEmpty) await root.update(updates);
    } catch (e) {
      debugPrint('Saved videos sync: $e');
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

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDI5hgBbaUeTpXcPIlAnq5yDjIenfY-ylM",
        authDomain: "mayajaal-app.firebaseapp.com",
        databaseURL:
            "https://mayajaal-app-default-rtdb.asia-southeast1.firebasedatabase.app",
        projectId: "mayajaal-app",
        storageBucket: "mayajaal-app.firebasestorage.app",
        messagingSenderId: "96139047750",
        appId: "1:96139047750:android:7dbfb9487d023c20012b47",
      ),
    );
    debugPrint("✅ Firebase Initialized Successfully");
    await MayaJaalAccount.init();
    final uiPrefs = await SharedPreferences.getInstance();
    themeNotifier.value = uiPrefs.getString('app_theme') ?? 'Cyber Emerald';
    languageNotifier.value = uiPrefs.getString('language') ?? 'English';
    soundEnabledNotifier.value = uiPrefs.getBool('sound_enabled') ?? true;
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }

  try {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(oneSignalAppId);
    OneSignal.Notifications.addClickListener((event) {
      _pendingMayaPushInbox = true;
      Timer(const Duration(milliseconds: 700), _openPendingMayaPushInbox);
    });
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
      child: LayoutBuilder(
        builder: (context, c) {
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
                    shadows: [
                      Shadow(
                        color: AppThemes.kGreen.withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
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
    _pulse = Tween<double>(
      begin: 0.90,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
    _rotate = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.linear));
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
                      builder:
                          (c, _) => Transform.rotate(
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
                      builder:
                          (c, _) => Transform.scale(
                            scale: _pulse.value,
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black,
                                border: Border.all(
                                  color: AppThemes.kGreen.withOpacity(0.8),
                                  width: 1.5,
                                ),
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
                                  errorBuilder:
                                      (c, e, s) => const Icon(
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppThemes.kGreen,
                      ),
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
    _a = Tween<double>(
      begin: 0.92,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
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
                  builder:
                      (c, _) => Transform.scale(
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
                              errorBuilder:
                                  (c, e, s) => Container(
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
                      Shadow(
                        color: AppThemes.kGreen.withOpacity(0.7),
                        blurRadius: 12,
                      ),
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
    final channelId = _mayaChannelId(uri);
    if (channelId != null) return '$kBackendBaseUrl/channel/$channelId';
    String videoId = '';
    final token = uri.queryParameters['t'] ?? uri.queryParameters['s'] ?? '';

    if (uri.path.startsWith('/v/') ||
        uri.path.startsWith('/s/') ||
        uri.path.startsWith('/stream/') ||
        uri.path.startsWith('/api/v/')) {
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
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder:
              (_) => LoginScreen(
                onLoginSuccess: () {
                  final pending = _pendingVideoTargetUrl;
                  _pendingVideoTargetUrl = null;
                  if (pending != null && pending.isNotEmpty) {
                    navigatorKey.currentState?.pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => _mayaLinkScreen(pending),
                      ),
                    );
                  }
                },
              ),
        ),
      );
      return;
    }

    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => _mayaLinkScreen(target)),
    );
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
    final primaryColor = mayaThemeColors[themeName] ?? _mayaMint;

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
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppThemes.kCardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppThemes.kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppThemes.kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primaryColor, width: 1.5)),
      ),
      cardTheme: CardThemeData(
        color: AppThemes.kCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: const Color(0xFF082015),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        thumbColor: primaryColor,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primaryColor),

      fontFamily: 'Roboto',
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
// Keep permission explanations and native pickers from overlapping system prompts.
class _PermissionQueue {
  static Future<void> _previous = Future<void>.value();

  static Future<T> run<T>(Future<T> Function() action) async {
    final previous = _previous;
    final completed = Completer<void>();
    _previous = completed.future;
    try {
      await previous;
      return await action();
    } finally {
      completed.complete();
    }
  }
}

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
  bool _notificationRequestStarted = false;

  Future<void> _requestNotificationPermission(String uid) async {
    _openPendingMayaPushInbox();
    try {
      await OneSignal.login(uid);
    } catch (_) {}
    if (_notificationRequestStarted || !mounted) return;
    _notificationRequestStarted = true;
    try {
      await _PermissionQueue.run(() async {
        if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
        final prefs = await SharedPreferences.getInstance();
        const key = 'maya_native_notification_permission_requested';
        if (prefs.getBool(key) ?? false) return;
        final status = await Permission.notification.status;
        if (status.isGranted || status.isPermanentlyDenied) return;
        if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
        await OneSignal.Notifications.requestPermission(false);
        await prefs.setBool(key, true);
      });
    } catch (_) {
      // Notifications are optional.
    }
  }

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
        if (snapshot.connectionState == ConnectionState.waiting ||
            !_gateChecked) {
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
            unawaited(_requestNotificationPermission(user.uid));
            await MayaJaalAccount.syncUserToRTDB(user);
            await MayaJaalAccount.loadApiKey();
          });

          if (!_initialHandled &&
              _initialPendingUrl != null &&
              _initialPendingUrl!.isNotEmpty) {
            _initialHandled = true;
            final url = _initialPendingUrl!;
            _initialPendingUrl = null;
            _MyAppState.instance?.clearPending();
            return _mayaLinkScreen(url);
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
                        BoxShadow(
                          color: AppThemes.kRed.withOpacity(0.4),
                          blurRadius: 25,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.gpp_bad,
                      color: AppThemes.kRed,
                      size: 44,
                    ),
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemes.kRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(23),
                        ),
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
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.logout,
                      color: AppThemes.kDimGreen,
                      size: 16,
                    ),
                    label: const Text(
                      'LOGOUT',
                      style: TextStyle(
                        color: AppThemes.kDimGreen,
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
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
                            BoxShadow(
                              color: AppThemes.kGreen.withOpacity(0.4),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/icon/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder:
                                (c, e, s) => const Icon(
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(29),
                        ),
                      ),
                      child:
                          _loading
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2.5,
                                ),
                              )
                              : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(
                                    'https://developers.google.com/identity/images/g-logo.png',
                                    height: 24,
                                    errorBuilder:
                                        (c, e, s) => const Icon(
                                          Icons.g_mobiledata,
                                          color: Colors.red,
                                          size: 28,
                                        ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Sign in with Google',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'sans-serif',
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.5),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 11.5,
                        ),
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
// MAYAJAAL BUILT-IN BROWSER (Telegram Web + ordinary web links)
// ═══════════════════════════════════════════════════════════════════════════════
class MayaJaalBrowserScreen extends StatefulWidget {
  final String initialUrl;
  final bool showAppBar;
  const MayaJaalBrowserScreen({
    super.key,
    this.initialUrl = 'https://web.telegram.org/k/',
    this.showAppBar = true,
  });

  @override
  State<MayaJaalBrowserScreen> createState() => _MayaJaalBrowserScreenState();
}

class _MayaJaalBrowserScreenState extends State<MayaJaalBrowserScreen> {
  late final WebViewController _controller;
  late final TextEditingController _addressController;
  bool _loading = true;
  bool _openingTeraBox = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _pageTitle = 'Telegram Web';

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.initialUrl);
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(AppThemes.kBg)
          ..addJavaScriptChannel(
            'MayaJaalTelegramLink',
            onMessageReceived: (message) => _openTeraBoxLink(message.message),
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (request) {
                if (request.isMainFrame && _openTeraBoxLink(request.url)) {
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
              onPageStarted: (url) {
                if (!mounted) return;
                setState(() {
                  _loading = true;
                  _addressController.text = url;
                });
                _refreshNavigation();
              },
              onPageFinished: (url) async {
                if (!mounted) return;
                final title = await _controller.getTitle();
                if (!mounted) return;
                if (Uri.tryParse(url)?.host == 'web.telegram.org') {
                  await _controller.runJavaScript(_telegramLinkHandler);
                }
                if (!mounted) return;
                setState(() {
                  _loading = false;
                  _addressController.text = url;
                  _pageTitle =
                      (title == null || title.isEmpty)
                          ? 'MayaJaal Browser'
                          : title;
                });
                _refreshNavigation();
              },
              onWebResourceError: (error) {
                debugPrint('MayaJaal Browser: ${error.description}');
              },
            ),
          )
          ..loadRequest(Uri.parse(widget.initialUrl));
  }

  static const _teraBoxHosts = {
    'terabox.com',
    '1024terabox.com',
    'freeterabox.com',
    'teraboxapp.com',
    'terabox.club',
    'terabox.link',
  };

  static final _telegramLinkHandler = '''
    (() => {
      if (window.location.origin !== 'https://web.telegram.org') return;
      if (window.mayaJaalTelegramLinkInstalled) return;
      window.mayaJaalTelegramLinkInstalled = true;
      const hosts = [${_teraBoxHosts.map((host) => "'$host'").join(',')}];
      document.addEventListener('click', (event) => {
        const anchor = event.target.closest?.('a[href]');
        if (!anchor) return;
        const url = new URL(anchor.href, location.href);
        if (!['https:', 'http:'].includes(url.protocol)) return;
        if (!hosts.some(host => url.hostname === host ||
            url.hostname.endsWith('.' + host))) return;
        if (!url.pathname.startsWith('/s/')) return;
        event.preventDefault();
        event.stopImmediatePropagation();
        MayaJaalTelegramLink.postMessage(url.href);
      }, true);
    })();
  ''';

  bool _openTeraBoxLink(String url) {
    final uri = Uri.tryParse(url);
    if (!mounted ||
        uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.userInfo.isNotEmpty ||
        uri.pathSegments.length < 2 ||
        uri.pathSegments.first != 's' ||
        uri.pathSegments[1].isEmpty ||
        !_teraBoxHosts.any(
          (host) => uri.host == host || uri.host.endsWith('.$host'),
        )) {
      return false;
    }
    if (!_openingTeraBox) _playTeraBoxLink(uri);
    return true;
  }

  Future<void> _playTeraBoxLink(Uri uri) async {
    _openingTeraBox = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => StreamPreviewScreen(targetUrl: uri.toString()),
        ),
      );
    } finally {
      _openingTeraBox = false;
    }
  }

  Future<void> _refreshNavigation() async {
    final back = await _controller.canGoBack();
    final forward = await _controller.canGoForward();
    if (mounted)
      setState(() {
        _canGoBack = back;
        _canGoForward = forward;
      });
  }

  Future<void> _goToAddress() async {
    var value = _addressController.text.trim();
    if (value.isEmpty) return;
    final hasScheme =
        value.startsWith('http://') || value.startsWith('https://');
    if (!hasScheme) {
      value =
          value.contains('.') && !value.contains(' ')
              ? 'https://$value'
              : 'https://www.google.com/search?q=${Uri.encodeComponent(value)}';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasAuthority) return;
    await _controller.loadRequest(uri);
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.kBg,
      appBar:
          widget.showAppBar
              ? AppBar(
                backgroundColor: AppThemes.kCardBg,
                foregroundColor: Colors.white,
                titleSpacing: 8,
                title: TextField(
                  controller: _addressController,
                  textInputAction: TextInputAction.go,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search or enter URL',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: AppThemes.kBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: AppThemes.kBorder),
                    ),
                  ),
                  onSubmitted: (_) => _goToAddress(),
                ),
                actions: [
                  IconButton(
                    onPressed: _goToAddress,
                    icon: const Icon(Icons.search, color: AppThemes.kGreen),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppThemes.kGreen),
                    onSelected: (v) {
                      if (v == 'telegram')
                        _controller.loadRequest(
                          Uri.parse('https://web.telegram.org/k/'),
                        );
                      if (v == 'home')
                        _controller.loadRequest(
                          Uri.parse('https://www.google.com/'),
                        );
                      if (v == 'refresh') _controller.reload();
                    },
                    itemBuilder:
                        (_) => const [
                          PopupMenuItem(
                            value: 'telegram',
                            child: Text('Telegram Web'),
                          ),
                          PopupMenuItem(
                            value: 'home',
                            child: Text('Browser Home'),
                          ),
                          PopupMenuItem(
                            value: 'refresh',
                            child: Text('Refresh'),
                          ),
                        ],
                  ),
                ],
              )
              : null,
      body: Column(
        children: [
          if (_loading)
            const LinearProgressIndicator(
              minHeight: 2,
              color: AppThemes.kGreen,
              backgroundColor: AppThemes.kBorder,
            ),
          Expanded(child: WebViewWidget(controller: _controller)),
          Container(
            height: 48,
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(top: BorderSide(color: AppThemes.kBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed:
                      _canGoBack
                          ? () async {
                            await _controller.goBack();
                            _refreshNavigation();
                          }
                          : null,
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                ),
                IconButton(
                  onPressed:
                      _canGoForward
                          ? () async {
                            await _controller.goForward();
                            _refreshNavigation();
                          }
                          : null,
                  icon: const Icon(Icons.arrow_forward_ios, size: 18),
                ),
                IconButton(
                  onPressed: () => _controller.reload(),
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  onPressed:
                      () => _controller.loadRequest(
                        Uri.parse('https://web.telegram.org/k/'),
                      ),
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Color(0xFF229ED9),
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
// MAIN NAVIGATION HOLDER (6 TABS)
// ═══════════════════════════════════════════════════════════════════════════════
// Shared full-screen editor route. Existing save/cancel results are preserved.
Future<T?> _mayaOpenEditor<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => Navigator.of(context, rootNavigator: true).push<T>(
  MaterialPageRoute<T>(builder: builder, fullscreenDialog: true),
);

class _MayaEditorPage extends StatelessWidget {
  const _MayaEditorPage({required this.title, required this.content,
    required this.actions});
  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: AppThemes.kBg,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('MAYAJAAL'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          return Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 42, height: 4,
                        decoration: BoxDecoration(color: accent,
                          borderRadius: BorderRadius.circular(8))),
                      const SizedBox(height: 18),
                      DefaultTextStyle.merge(style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w700,
                        color: Colors.white), child: title),
                      const SizedBox(height: 28),
                      content,
                    ],
                  ),
                )),
                Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: OverflowBar(alignment: MainAxisAlignment.end,
                    spacing: 12, overflowSpacing: 8, children: actions)),
              ],
            ),
          ));
        }),
      ),
    );
  }
}

class MainNavigationHolder extends StatefulWidget {
  const MainNavigationHolder({super.key});
  @override
  State<MainNavigationHolder> createState() => _MainNavigationHolderState();
}

class _MainNavigationHolderState extends State<MainNavigationHolder> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;

  bool _readingShare = false;
  bool _adsDrawerOpen = false;

  @override
  void initState() {
    super.initState();
    _shareChannel.setMethodCallHandler((call) async {
      if (call.method == 'shareAvailable') await _openSharedLink();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSharedLink());
  }

  Future<void> _openSharedLink() async {
    if (!mounted || _readingShare) return;
    _readingShare = true;
    try {
      while (mounted) {
        final shared = await _shareChannel.invokeMethod<String>(
          'takeSharedText',
        );
        if (!mounted || shared == null) return;
        for (final match in RegExp(r'https://[^\s<>]+').allMatches(shared)) {
          final url = match.group(0)!;
          final uri = _mediaLink(url);
          if (uri != null &&
              (_isSocialLink(url) || _fileExtension(uri) != null)) {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => MayaSocialMediaScreen(source: uri),
              ),
            );
            break;
          }
          if (uri != null &&
              (_isMayaVideoLink(uri) || _mayaChannelId(uri) != null)) {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => _mayaLinkScreen(uri.toString()),
              ),
            );
            break;
          }
          if (uri != null && TeraBoxResolver.isTeraBoxLink(url)) {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => StreamPreviewScreen(targetUrl: uri.toString()),
              ),
            );
            break;
          }
        }
      }
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    } finally {
      _readingShare = false;
    }
  }

  @override
  void dispose() {
    _shareChannel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppThemes.kBg,
      drawer: const MoreDrawer(),
      onDrawerChanged: (open) { if (mounted) setState(() => _adsDrawerOpen = open); },
      floatingActionButton:
          const bool.fromEnvironment('MAYA_ADS_TRIAL') && _currentIndex == 0
              ? FloatingActionButton.extended(
                  heroTag: 'mayajaal_ads_test_lab_home',
                  backgroundColor: AppThemes.kGreen,
                  foregroundColor: Colors.black,
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Ads Test Lab'),
                  onPressed: () async {
                    try {
                      await const MethodChannel('mayajaal/ads_trial')
                          .invokeMethod<void>('open');
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ads test unavailable: $e')),
                      );
                    }
                  },
                )
              : null,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(onMenuTap: () => _scaffoldKey.currentState?.openDrawer(), adsActive: _currentIndex == 0 && !_adsDrawerOpen),
          const ChannelScreen(),
          const MayaJaalBrowserScreen(
            initialUrl: 'https://web.telegram.org/k/',
            showAppBar: false,
          ),
          if (_currentIndex == 3)
            const LiveAdventuresScreen()
          else
            const SizedBox.shrink(),
          const MayaDownloadsScreen(),
          if (_currentIndex == 5)
            const HistoryScreen()
          else
            const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MayaAdSlot(active: !_adsDrawerOpen && _currentIndex != 2),
          Container(
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border(top: BorderSide(color: AppThemes.kBorder, width: 1.0)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: Colors.black,
          elevation: 0,
          selectedItemColor: AppThemes.kGreen,
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 10,
          unselectedFontSize: 9,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          iconSize: 23,
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
              icon: Icon(Icons.send_rounded, color: Color(0xFF229ED9)),
              activeIcon: Icon(Icons.send_rounded, color: AppThemes.kGreen),
              label: 'Telegram',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore, color: AppThemes.kGreen),
              label: 'World',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.download_outlined),
              activeIcon: Icon(Icons.download, color: AppThemes.kGreen),
              label: 'Downloads',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history, color: AppThemes.kGreen),
              label: 'History',
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

    final gridPaint =
        Paint()
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

  void _drawSmoothTrace(
    Canvas canvas,
    Size size,
    List<double> points,
    Color color,
  ) {
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

    final fillPaint =
        Paint()
          ..shader = LinearGradient(
            colors: [color.withOpacity(0.18), color.withOpacity(0.0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint =
        Paint()
          ..color = color
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    final lastPoint = mapped.last;
    final dotGlow =
        Paint()
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

class _LivePulseCardState extends State<LivePulseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  final List<double> _viewHistory = [
    0.0,
    1.0,
    1.0,
    2.0,
    3.0,
    5.0,
    4.0,
    6.0,
    8.0,
    9.0,
  ];
  final List<double> _linkHistory = [
    0.0,
    0.0,
    1.0,
    1.0,
    1.0,
    2.0,
    2.0,
    2.0,
    3.0,
    3.0,
  ];

  int _prevViews = -1;
  int _prevLinks = -1;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
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
                    builder:
                        (c, _) => Container(
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
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppThemes.kNeonCyan,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Views',
                        style: TextStyle(
                          color: AppThemes.kNeonCyan,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppThemes.kGreen,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Links',
                        style: TextStyle(
                          color: AppThemes.kGreen,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 8,
                          letterSpacing: 0.8,
                        ),
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
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 8,
                          letterSpacing: 0.8,
                        ),
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
                    builder:
                        (c, _) => CustomPaint(
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
  final bool adsActive;
  const HomeScreen({super.key, this.onMenuTap, this.adsActive = true});
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
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
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
    final uri = _mediaLink(input);
    _linkController.clear();
    _linkFocus.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                uri != null &&
                        (_isSocialLink(input) || _fileExtension(uri) != null)
                    ? MayaSocialMediaScreen(source: uri)
                    : _mayaLinkScreen(input),
      ),
    );
  }

  Widget _catCard(IconData icon, String title, String subtitle) {
    return GestureDetector(
      onTap: () {
        SoundService.playClick();
        Haptic.light();
        if (title == 'Favorites')
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SavedVideosScreen()));
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.menu,
                        color: AppThemes.kGreen,
                        size: 24,
                      ),
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
                          errorBuilder:
                              (c, e, s) => const Icon(
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
                      icon: const Icon(
                        Icons.search,
                        color: AppThemes.kGreen,
                        size: 22,
                      ),
                      onPressed: () {
                        SoundService.playClick();
                        Haptic.light();
                        showSearch(
                          context: context,
                          delegate: UserSearchDelegate(),
                        );
                      },
                    ),
                    StreamBuilder<int>(
                      stream:
                          MayaJaalAccount.cachedUid != null
                              ? FirebaseService.getUnreadCount(
                                MayaJaalAccount.cachedUid!,
                              )
                              : Stream.value(0),
                      builder: (context, snapshot) {
                        final unread = snapshot.data ?? 0;
                        return Stack(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.notifications_none,
                                color:
                                    unread > 0
                                        ? AppThemes.kRed
                                        : AppThemes.kGreen,
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
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                  ),
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
                          ],
                        );
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
                      builder:
                          (c, _) => Transform.scale(
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
                                    border: Border.all(
                                      color: AppThemes.kGreen,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.asset(
                                      'assets/icon/logo.png',
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (c, e, s) => Container(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppThemes.kGreen.withOpacity(0.4),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.link,
                                color: AppThemes.kGreen,
                                size: 12,
                              ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
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
                                        hintText:
                                            'Paste Stream URL or TeraBox Link',
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
                                    color: _mayaMint,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _mayaMint.withOpacity(0.4),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
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
                    Expanded(child: const MayaFavoritesTile()),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
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
                      Icon(
                        Icons.arrow_forward_ios,
                        color: AppThemes.kGreen,
                        size: 12,
                      ),
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

class _MoreDrawerState extends State<MoreDrawer> with TickerProviderStateMixin {
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
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MayaJaalBrowserScreen(initialUrl: target.toString()),
        ),
      );
    } catch (e) {
      try {
        await launchUrl(Uri.parse(url));
      } catch (_) {}
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
      builder:
          (c) => AlertDialog(
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
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 9.5,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Version: v1.3.0 (Build 5)',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'MayaJaal is a next-generation video streaming and sharing platform for creators. Convert, share, and enjoy seamlessly with Matrix-grade encryption and quantum-speed streaming.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '👥 Video Sharing Platform · User-Generated Content',
                    style: TextStyle(
                      color: AppThemes.kDimGreen,
                      fontSize: 10.5,
                    ),
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
                child: const Text(
                  'CLOSE',
                  style: TextStyle(color: AppThemes.kGreen),
                ),
              ),
            ],
          ),
    );
  }

  void _showApiKeyDialog(BuildContext context) {
    SoundService.playClick();
    showDialog(
      context: context,
      builder:
          (c) => AlertDialog(
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
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
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
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10.5,
                    ),
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
                          content: Text(
                            '✅ API Key copied',
                            style: TextStyle(color: AppThemes.kGreen),
                          ),
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  'COPY',
                  style: TextStyle(color: AppThemes.kGreen),
                ),
              ),
              TextButton(
                onPressed: () {
                  SoundService.playClick();
                  Navigator.pop(c);
                },
                child: const Text(
                  'CLOSE',
                  style: TextStyle(color: Colors.white54),
                ),
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
      builder:
          (c) => Padding(
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
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10.5,
                  ),
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

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MayaDeleteAccountDialog(),
    );
    if (deleted != true) return;
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
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
                border: Border(
                  bottom: BorderSide(color: AppThemes.kBorder, width: 1.0),
                ),
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
                        errorBuilder:
                            (c, e, s) => const Icon(
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
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white60,
                      size: 20,
                    ),
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
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
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
                            child:
                                user?.photoURL != null
                                    ? ClipOval(
                                      child: Image.network(
                                        user!.photoURL!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (c, e, s) => const Icon(
                                              Icons.person,
                                              color: AppThemes.kGreen,
                                              size: 18,
                                            ),
                                      ),
                                    )
                                    : const Icon(
                                      Icons.person,
                                      color: AppThemes.kGreen,
                                      size: 18,
                                    ),
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
                                    Icon(
                                      Icons.verified,
                                      color: AppThemes.kDimGreen,
                                      size: 9,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Verified Account',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 8.5,
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
                          MaterialPageRoute(
                            builder: (_) => const StatsScreen(),
                          ),
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
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  _staggered(
                    index: 8,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        top: 14,
                        bottom: 6,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 1.5,
                            color: AppThemes.kGreen,
                          ),
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
                            child: Container(
                              height: 0.8,
                              color: Colors.white10,
                            ),
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
                        _launchURL(
                          'https://www.instagram.com/maya_jaal_official',
                        );
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
                        _launchURL(
                          'https://www.youtube.com/@MayaJaalOfficial00',
                        );
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
                      padding: const EdgeInsets.only(
                        left: 16,
                        top: 14,
                        bottom: 6,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 1.5,
                            color: AppThemes.kNeonCyan,
                          ),
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
                            child: Container(
                              height: 0.8,
                              color: Colors.white10,
                            ),
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
                        _launchURL(
                          'https://www.mayajaal.online/dashboard',
                          inApp: false,
                        );
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
                  if (const bool.fromEnvironment('MAYA_ADS_TRIAL'))
                    _snakeItem(
                      context,
                      icon: Icons.science_outlined,
                      color: AppThemes.kNeonCyan,
                      title: 'Ads Test Lab',
                      subtitle: 'InMobi SDK · developer testing only',
                      onTap: () async {
                        Navigator.pop(context);
                        try {
                          await const MethodChannel('mayajaal/ads_trial')
                              .invokeMethod<void>('open');
                        } catch (e) {
                          final ctx = navigatorKey.currentContext;
                          if (ctx != null && ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Ads test unavailable: $e')),
                            );
                          }
                        }
                      },
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.3),
                          ),
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.logout,
                            color: Colors.redAccent,
                            size: 20,
                          ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppThemes.kRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppThemes.kFireOrange.withOpacity(0.8),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppThemes.kRed.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.local_fire_department,
                            color: AppThemes.kFireOrange,
                            size: 22,
                          ),
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
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 9.5,
                            ),
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
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white24,
          size: 12,
        ),
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
            errorBuilder:
                (c, e, s) => Icon(fallbackIcon, color: color, size: 18),
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
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white24,
          size: 12,
        ),
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
      extractPath.addPath(metrics.extractPath(startPos, endPos), Offset.zero);
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

    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawPath(extractPath, paint);

    final corePaint =
        Paint()
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
      final rawSize =
          data['size'] ??
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
      final rawCreated =
          data['createdAt'] ??
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

      return {'sizeBytes': sizeBytes, 'createdAt': createdAtMs};
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
    _snakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (!MayaJaalAccount.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppThemes.kCardBg,
            content: Text(
              'Please login to watch videos',
              style: TextStyle(color: AppThemes.kGreen),
            ),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
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
        _streamUrl = '';
      } catch (_) {
        _rawId = 'stream';
        _streamUrl = '';
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
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
            _videoTitle = result['fileName']!;
          }
          if (result['thumbnail']!.isNotEmpty) {
            _thumbnailUrl = result['thumbnail']!;
          }
          _videoSize = result['size'] ?? 'Unknown';
          _uploaderName = result['owner'] ?? 'Unknown';
          _videoAge = 'Just now';
        } else {
          _resolveError =
              result['error'] ??
              'Could not load this TeraBox video. Try again later.';
        }
      });
    }
  }

  Future<void> _secureInit() async {
    final cachedThumb = await WatchHistory.getCachedThumbnail(widget.targetUrl);
    if (mounted) {
      setState(() {
        if (cachedThumb.isNotEmpty) _thumbnailUrl = cachedThumb;
      });
    }

    final ok = await SecurityGuard.validateSession();
    if (!ok) {
      if (mounted) {
        await MayaJaalAccount.signOut();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
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
      final apiUrl =
          _token.isNotEmpty
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

      final res = await http
          .get(Uri.parse(apiUrl), headers: headers)
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          String newUrl =
              (data['streamUrl'] ?? data['url'] ?? data['video_url'] ?? '')
                  .toString();

          if (newUrl.startsWith('https://mayajaal.online')) {
            newUrl = newUrl.replaceFirst(
              'https://mayajaal.online',
              kBackendBaseUrl,
            );
          }
          if (newUrl.isEmpty) {
            newUrl = '';
          }

          final resolvedTitle = [
                data['title'],
                data['filename'],
                data['file_name'],
                data['fileName'],
              ]
              .map((value) => value?.toString().trim() ?? '')
              .firstWhere(
                (value) => !VideoNameResolver.isBadTitle(value, _rawId),
                orElse: () => '',
              );

          if (mounted) {
            setState(() {
              _streamUrl = newUrl;
              if (resolvedTitle.isNotEmpty) _videoTitle = resolvedTitle;
              _uploaderName = data['uploader']?.toString() ?? _uploaderName;
              final apiThumb = _storedVideoThumbnail(data);
              if (apiThumb.isNotEmpty) {
                _thumbnailUrl = apiThumb;
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
        _isOwnerVerified =
            (ownerData['name'] ?? '').isNotEmpty && _ownerUid.isNotEmpty;
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

  bool _loadingPlayback = false;

  Future<void> _launchNativePlayer() async {
    if (_loadingPlayback) return;
    if (!_isTeraBox && _streamUrl.isEmpty) {
      _loadingPlayback = true;
      try {
        if (await SecurityGuard.validateSession()) {
          await _fetchStreamMetadata();
        }
      } finally {
        _loadingPlayback = false;
      }
      if (!mounted) return;
    }
    if (_resolveError.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppThemes.kCardBg,
          content: Text(
            _resolveError,
            style: const TextStyle(color: AppThemes.kRed),
          ),
        ),
      );
      return;
    }

    if (_streamUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppThemes.kCardBg,
          content: Text(
            'Video URL not ready yet. Please wait.',
            style: TextStyle(color: AppThemes.kGold),
          ),
        ),
      );
      return;
    }

    SoundService.playClick();

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder:
                (_) => NativeVideoPlayerScreen(
                  videoUrl: _streamUrl,
                  title: _videoTitle,
                  uploader: _uploaderName,
                  sourcePageUrl: widget.targetUrl,
                  videoId: _rawId,
                  thumbnailUrl:
                      _thumbnailUrl.isNotEmpty
                          ? _thumbnailUrl
                          : _capturedThumbB64,
                ),
          ),
        )
        .then((_) {
          if (mounted) {
            _startCountdown();
            unawaited(MayaAds.afterVideo(context));
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
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppThemes.kNeonCyan,
                          ),
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
                              shadows: [
                                Shadow(
                                  color: AppThemes.kNeonCyan,
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            'seconds',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                              letterSpacing: 2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppThemes.kNeonCyan.withOpacity(0.5),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppThemes.kNeonCyan.withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          color: AppThemes.kNeonCyan,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _countdown > 3
                            ? 'Preparing your video'
                            : 'Ready in a moment',
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
      builder:
          (c, _) => Transform.scale(
            scale: _pulseAnimation.value,
            child: GestureDetector(
              onTap: _launchNativePlayer,
              child: Container(
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(29),
                  boxShadow: [
                    BoxShadow(
                      color: _mayaMint.withOpacity(0.4),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: SnakeBorderPainter(
                          progress: _snakeCtrl.value,
                          color: _mayaMint,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.play_arrow_rounded,
                          color: _mayaMint,
                          size: 30,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Play video',
                          style: TextStyle(
                            color: _mayaMint,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
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
                      icon: const Icon(
                        Icons.home,
                        color: Colors.white54,
                        size: 18,
                      ),
                      label: const Text(
                        'GO TO HOME PAGE',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppThemes.kBorder,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const MayaAdSlot(),

                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppThemes.kGreen,
                          size: 18,
                        ),
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
                          border: Border.all(
                            color: AppThemes.kGreen,
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.asset(
                            'assets/icon/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder:
                                (c, e, s) => const Icon(
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
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppThemes.kBorder),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: AppThemes.kGreen,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppThemes.kCardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            _isReadyToPlay
                                ? AppThemes.kGreen
                                : AppThemes.kNeonCyan.withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isReadyToPlay
                                  ? AppThemes.kGreen
                                  : AppThemes.kNeonCyan)
                              .withOpacity(0.1),
                          blurRadius: 20,
                        ),
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
                              const Center(
                                child: ProfessionalLoader(
                                  message: 'Loading video details…',
                                ),
                              )
                            else if (_resolveError.isNotEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    _resolveError,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppThemes.kRed,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              )
                            else
                              buildMediaThumbnail(
                                _thumbnailUrl.isNotEmpty ? _thumbnailUrl : null,
                                _videoTitle,
                                _streamUrl,
                                loopPreview: true,
                                onFrameCaptured: (b64) {
                                  if (!mounted) return;
                                  if (_capturedThumbB64.isEmpty) {
                                    setState(() => _capturedThumbB64 = b64);
                                  }
                                },
                              ),
                            if (!_isReadyToPlay &&
                                !_isResolving &&
                                _resolveError.isEmpty)
                              _buildProfessionalCountdown(),
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppThemes.kGreen,
                                    width: 0.8,
                                  ),
                                ),
                                child: const Text(
                                  'Preview',
                                  style: TextStyle(
                                    color: AppThemes.kGreen,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(29),
                      ),
                      child: Center(
                        child: Text(
                          'PLEASE WAIT $_countdown SEC...',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
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
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black,
                                border: Border.all(color: AppThemes.kBorder),
                              ),
                              child: const Icon(
                                Icons.video_collection_outlined,
                                color: AppThemes.kGreen,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'FILE NAME',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 8.5,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    _videoTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black,
                                      border: Border.all(
                                        color: AppThemes.kBorder,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.person_outline,
                                      color: AppThemes.kGreen,
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
                                          'UPLOADER',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.4,
                                            ),
                                            fontSize: 8.5,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                _uploaderName,
                                                style: const TextStyle(
                                                  color: AppThemes.kGreen,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (_isOwnerVerified) ...[
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.verified,
                                                color: AppThemes.kGreen,
                                                size: 13,
                                              ),
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
                              margin: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),

                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black,
                                      border: Border.all(
                                        color: AppThemes.kBorder,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.sd_storage_outlined,
                                      color: AppThemes.kNeonCyan,
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
                                          'FILE SIZE',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.4,
                                            ),
                                            fontSize: 8.5,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _videoSize.isNotEmpty
                                              ? _videoSize
                                              : 'N/A',
                                          style: const TextStyle(
                                            color: AppThemes.kNeonCyan,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
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
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black,
                                  border: Border.all(color: AppThemes.kBorder),
                                ),
                                child: const Icon(
                                  Icons.calendar_today_outlined,
                                  color: AppThemes.kGold,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'UPLOADED',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 8.5,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      _videoAge,
                                      style: const TextStyle(
                                        color: AppThemes.kGold,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppThemes.kBorder,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(23),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.share, color: AppThemes.kGreen, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'SHARE VIDEO',
                            style: TextStyle(
                              color: AppThemes.kGreen,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
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
bool _isMayaVideoLink(Uri uri) =>
    const {'mayajaal.online', 'www.mayajaal.online'}.contains(uri.host) &&
    uri.pathSegments.length == 2 &&
    const {'v', 's', 'stream'}.contains(uri.pathSegments.first);

String? _mayaChannelId(Uri uri) {
  if (uri.scheme != 'https' ||
      !const {'mayajaal.online', 'www.mayajaal.online'}.contains(uri.host) ||
      uri.pathSegments.length != 2 ||
      uri.pathSegments.first != 'channel')
    return null;
  final id = uri.pathSegments.last;
  return RegExp(
        r'^(?:@[A-Za-z][A-Za-z0-9_]{3,31}|[A-Za-z0-9_-]{1,128})$',
      ).hasMatch(id)
      ? id
      : null;
}

Widget _mayaLinkScreen(String target) {
  final uri = Uri.tryParse(target);
  final id = uri == null ? null : _mayaChannelId(uri);
  return id == null
      ? StreamPreviewScreen(targetUrl: target)
      : MayaChannelPage(channel: ChannelScreen.channels.child(id));
}

class MayaChannelsApi {
  static Uri uri(String path, [Map<String, String>? query]) {
    final community = MayaCommunityApi.uri('');
    return community.replace(
      path:
          community.path.replaceFirst(RegExp(r'/community$'), '/channels') +
          path,
      queryParameters: query,
    );
  }

  static Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const HttpException('Sign in to open channels.');
    Future<http.Response> send(bool refresh) async {
      final token = await user.getIdToken(refresh);
      final client = http.Client();
      try {
        final req = http.Request(method, uri(path, query))
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          });
        if (body != null) req.body = jsonEncode(body);
        return await http.Response.fromStream(
          await client.send(req).timeout(const Duration(seconds: 25)),
        ).timeout(const Duration(seconds: 25));
      } finally {
        client.close();
      }
    }

    var response = await send(false);
    if (response.statusCode == 401) response = await send(true);
    Map<String, dynamic> data = {};
    try {
      data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        data['detail'] is String
            ? data['detail']
            : response.statusCode == 404
            ? 'Install the updated channels service on your VPS first.'
            : 'Channel service HTTP ${response.statusCode}. Please retry.',
      );
    }
    return data;
  }

  static Future<void> upload(
    String id, {
    bool avatar = false,
    String? filePath,
    String? fileName,
    String text = '',
  }) async {
    final result =
        filePath != null
            ? null
            : await _PermissionQueue.run(
              () => FilePicker.platform.pickFiles(
                type: avatar ? FileType.image : FileType.custom,
                allowedExtensions:
                    avatar
                        ? null
                        : const [
                          'jpg',
                          'jpeg',
                          'png',
                          'webp',
                          'gif',
                          'mp4',
                          'mov',
                          'mkv',
                          'webm',
                          'pdf',
                          'doc',
                          'docx',
                          'xls',
                          'xlsx',
                          'ppt',
                          'pptx',
                          'txt',
                          'csv',
                          'zip',
                        ],
              ),
            );
    final selectedPath = filePath ?? result?.files.single.path;
    if (selectedPath == null) return;
    final selectedName =
        fileName ?? result?.files.single.name ?? selectedPath.split('/').last;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const HttpException('Sign in again.');
    final token = await user.getIdToken();
    final req =
        http.MultipartRequest('POST', uri('/${Uri.encodeComponent(id)}/upload'))
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['purpose'] = avatar ? 'avatar' : 'post'
          ..fields['text'] = text
          ..files.add(
            await http.MultipartFile.fromPath(
              'file',
              selectedPath,
              filename: selectedName,
            ),
          );
    final client = http.Client();
    try {
      final streamed = await client
          .send(req)
          .timeout(const Duration(minutes: 10));
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(const Duration(minutes: 2));
      if (response.statusCode != 200) {
        String message = 'Upload HTTP ${response.statusCode}';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['detail'] is String) message = data['detail'];
        } catch (_) {}
        throw HttpException(message);
      }
    } finally {
      client.close();
    }
  }
}

class ChannelScreen extends StatefulWidget {
  const ChannelScreen({super.key});
  static DatabaseReference get channels =>
      FirebaseDatabase.instance.ref('publicChannels');
  static Map<String, Object?> fields(Object? value) =>
      value is Map
          ? value.map((key, value) => MapEntry(key.toString(), value))
          : {};
  static String normalizedName(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _channels = [];
  bool _mine = false, _loading = true, _importing = false;
  String _error = '';
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final data = await MayaChannelsApi.request(
        '',
        query: {'q': _search.text.trim(), 'scope': _mine ? 'mine' : 'all'},
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _channels =
            (data['channels'] as List? ?? [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
        _error = '';
        _loading = false;
      });
    } catch (e) {
      if (mounted && generation == _generation)
        setState(() {
          _error = _channelError(e);
          _loading = false;
        });
    }
  }

  Future<void> _open(String id) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => MayaChannelPage(channel: ChannelScreen.channels.child(id)),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _create() async {
    var name = '', handle = '', description = '';
    var private = false;
    final result = await _mayaOpenEditor<Map<String, dynamic>>(
      context: context,
      builder:
          (dialog) => StatefulBuilder(
            builder:
                (c, update) => _MayaEditorPage(
                  title: const Text('Create your channel'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          maxLength: 80,
                          decoration: const InputDecoration(
                            labelText: 'Channel name',
                          ),
                          onChanged: (v) => name = v.trim(),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Private channel'),
                          subtitle: Text(
                            private
                                ? 'Only invited members can discover and read posts.'
                                : 'Anyone can discover this channel.',
                          ),
                          value: private,
                          onChanged: (v) => update(() => private = v),
                        ),
                        if (!private)
                          TextField(
                            maxLength: 33,
                            decoration: const InputDecoration(
                              labelText: 'Public username',
                              hintText: '@my_channel',
                            ),
                            onChanged: (v) => handle = v.trim(),
                          ),
                        TextField(
                          maxLength: 1000,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                          ),
                          onChanged: (v) => description = v.trim(),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed:
                          () => Navigator.pop(dialog, {
                            'name': name,
                            'username': handle,
                            'description': description,
                            'visibility': private ? 'private' : 'public',
                            'display_name':
                                FirebaseAuth
                                    .instance
                                    .currentUser
                                    ?.displayName ??
                                '',
                          }),
                      child: const Text('Create'),
                    ),
                  ],
                ),
          ),
    );
    if (result == null) return;
    try {
      final data = await MayaChannelsApi.request(
        '',
        method: 'POST',
        body: result,
      );
      if (mounted) await _open('${data['id']}');
    } catch (e) {
      if (mounted) _channelNotice(context, e);
    }
  }

  Future<void> _import() async {
    if (_importing) return;
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('Move your existing channels?'),
            content: const Text(
              'Your owned Firebase channels and text posts will move to the new service. A server backup is retained. Use the updated app after migration. Existing public media links cannot become private retroactively.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Import my channels'),
              ),
            ],
          ),
    );
    if (yes != true || !mounted) return;
    setState(() => _importing = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final rows = await ChannelScreen.channels.get();
      var count = 0;
      for (final entry in rows.children) {
        if (ChannelScreen.fields(entry.value)['ownerUid'] != uid) continue;
        await MayaChannelsApi.request(
          '/legacy/import/${entry.key}',
          method: 'POST',
        );
        count++;
      }
      if (mounted) {
        _channelNotice(context, 'Imported $count channels');
        await _load();
      }
    } catch (e) {
      if (mounted) _channelNotice(context, e);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Roboto'),
    ),
    child: Scaffold(
      backgroundColor: AppThemes.kBg,
      appBar: AppBar(
        title: const Text(
          'Channels',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Create channel',
            onPressed: _create,
            icon: const Icon(Icons.add_circle_outline),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'saved') {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder:
                        (_) => MayaChannelLibrary(
                          saved: true,
                          onOpen: (p) => _open('${p['channel_id']}'),
                        ),
                  ),
                );
              } else {
                _import();
              }
            },
            itemBuilder:
                (_) => [
                  const PopupMenuItem(
                    value: 'saved',
                    child: Text('Saved channel posts'),
                  ),
                  PopupMenuItem(
                    value: 'import',
                    enabled: !_importing,
                    child: Text(
                      _importing ? 'Importing…' : 'Import my existing channels',
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search @username or exact channel name',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppThemes.kCardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), _load);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Discover'),
                  selected: !_mine,
                  onSelected: (_) {
                    setState(() {
                      _mine = false;
                      _loading = true;
                    });
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Following & owned'),
                  selected: _mine,
                  onSelected: (_) {
                    setState(() {
                      _mine = true;
                      _loading = true;
                    });
                    _load();
                  },
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Public channels ranked by followers · Private channels stay out of search',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ),
          Expanded(
            child:
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          if (_error.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Text(_error),
                                  TextButton(
                                    onPressed: _load,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          if (_channels.isEmpty && _error.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'No channels here yet. Create one or join with an invitation.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          for (final c in _channels)
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 6,
                              ),
                              leading: _channelAvatar(c['photo']),
                              title: Text(
                                '${c['name']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                c['visibility'] == 'private'
                                    ? 'Private · ${c['followers']} members'
                                    : '@${c['username']} · ${c['followers']} followers',
                              ),
                              trailing: Icon(
                                c['owner'] == true
                                    ? Icons.verified_user_outlined
                                    : Icons.chevron_right,
                                color: _mayaMint,
                              ),
                              onTap: () => _open('${c['id']}'),
                            ),
                        ],
                      ),
                    ),
          ),
        ],
      ),
    ),
  );
}

String _channelError(Object error) =>
    error is HttpException
        ? error.message
        : error is TimeoutException
        ? 'The channel service took too long. Please retry.'
        : 'Could not complete this channel action. Please retry.';
void _channelNotice(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error is String ? error : _channelError(error))),
    );
Future<String?> _channelInput(
  BuildContext context,
  String title,
  String label, {
  required int limit,
}) async {
  final controller = TextEditingController();
  final value = await _mayaOpenEditor<String>(
    context: context,
    builder:
        (c) => _MayaEditorPage(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLength: limit,
            maxLines: limit > 200 ? 4 : 1,
            decoration: InputDecoration(labelText: label),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty)
                  Navigator.pop(c, controller.text.trim());
              },
              child: const Text('Continue'),
            ),
          ],
        ),
  );
  // The dialog route may still animate after its Future completes.
  Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
  return value;
}

Widget _channelAvatar(Object? raw) {
  final photo = raw?.toString() ?? '';
  return CircleAvatar(
    radius: 23,
    backgroundColor: _mayaMint.withOpacity(.10),
    foregroundImage: photo.isEmpty ? null : NetworkImage(photo),
    onForegroundImageError: photo.isEmpty ? null : (_, __) {},
    child: const Icon(Icons.campaign_outlined, color: _mayaMint),
  );
}

class MayaChannelPage extends StatefulWidget {
  const MayaChannelPage({super.key, required this.channel});
  final DatabaseReference channel;
  @override
  State<MayaChannelPage> createState() => _MayaChannelPageState();
}

class _MayaChannelPageState extends State<MayaChannelPage>
    with WidgetsBindingObserver {
  late String _id = widget.channel.key!;
  Map<String, dynamic> _channel = {};
  List<Map<String, dynamic>> _posts = [];
  final _search = TextEditingController();
  final _draft = TextEditingController();
  final _draftFocus = FocusNode();
  String? _draftPath, _draftName;
  bool _choosingAttachment = false;

  String _error = '';
  String? _next;
  bool _loading = true,
      _busy = false,
      _paging = false,
      _expanded = false,
      _foreground = true;
  int _generation = 0;
  Timer? _poll, _debounce;
  final _viewed = <String>{};
  final _postMutations = <String>{};
  Map<String, dynamic>? _invitation;
  bool get _owner => _channel['owner'] == true;
  String get _path => '/${Uri.encodeComponent(_id)}';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
    unawaited(_recoverCamera());
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted &&
          _foreground &&
          (ModalRoute.of(context)?.isCurrent ?? true) &&
          !_busy &&
          !_paging &&
          !_expanded)
        unawaited(_load(quiet: true));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(_load(quiet: true));
  }

  Future<void> _load({bool quiet = false, bool more = false}) async {
    if (more && (_next == null || _paging)) return;
    if (!quiet && !more) _expanded = false;
    final generation = ++_generation;
    if (more && mounted)
      setState(() {
        _paging = true;
        _expanded = true;
      });
    try {
      if (_id.startsWith('join_')) {
        final invite = await MayaChannelsApi.request(
          '/invites/${Uri.encodeComponent(_id.substring(5))}',
        );
        if (invite['joined'] != true) {
          if (mounted && generation == _generation)
            setState(() {
              _invitation = invite;
              _loading = false;
              _error = '';
            });
          return;
        }
        _id = '${invite['id']}';
      }
      final results = await Future.wait([
        MayaChannelsApi.request(_path),
        MayaChannelsApi.request(
          '$_path/posts',
          query: {'q': _search.text.trim(), if (more) 'before': _next!},
        ),
      ]);
      if (!mounted || generation != _generation) return;
      final rows =
          (results[1]['posts'] as List? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      setState(() {
        _channel = results[0];
        _posts =
            more
                ? [
                  ..._posts,
                  ...rows.where((r) => !_posts.any((p) => p['id'] == r['id'])),
                ]
                : rows;
        _next = results[1]['next_before']?.toString();
        _loading = false;
        _error = '';
        _paging = false;
      });
    } catch (e) {
      if (mounted && generation == _generation)
        setState(() {
          if (!quiet || _channel.isEmpty) _error = _channelError(e);
          _loading = false;
          _paging = false;
        });
    }
  }

  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) await _load(quiet: true);
    } catch (e) {
      if (mounted) _channelNotice(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _follow(bool follow) => _action(() async {
    await MayaChannelsApi.request(
      '$_path/follow',
      method: 'POST',
      body: {
        'following': follow,
        'display_name': FirebaseAuth.instance.currentUser?.displayName ?? '',
      },
    );
    if (!follow && _channel['visibility'] == 'private' && mounted) {
      Navigator.of(context).pop();
    }
  });
  Future<void> _join() => _action(() async {
    final result = await MayaChannelsApi.request(
      '/invites/${Uri.encodeComponent(_id.substring(5))}/join',
      method: 'POST',
      body: {
        'display_name': FirebaseAuth.instance.currentUser?.displayName ?? '',
      },
    );
    _id = '${result['id']}';
    _invitation = null;
  });
  Future<void> _edit() async {
    var name = '${_channel['name'] ?? ''}',
        handle = '${_channel['username'] ?? ''}',
        description = '${_channel['description'] ?? ''}';
    var private = _channel['visibility'] == 'private',
        sharing = _channel['sharing'] == true,
        memberPosts = _channel['member_posts'] == true;
    var days = (_channel['expiry_days'] as num?)?.toInt() ?? 0;
    final values = await _mayaOpenEditor<Map<String, dynamic>>(
      context: context,
      builder:
          (dialog) => StatefulBuilder(
            builder:
                (c, update) => _MayaEditorPage(
                  title: const Text('Channel settings'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          initialValue: name,
                          maxLength: 80,
                          decoration: const InputDecoration(
                            labelText: 'Channel name',
                          ),
                          onChanged: (v) => name = v.trim(),
                        ),
                        TextFormField(
                          initialValue: description,
                          maxLength: 1000,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                          ),
                          onChanged: (v) => description = v.trim(),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Private channel'),
                          subtitle: const Text(
                            'Existing members keep access. New members need an invite.',
                          ),
                          value: private,
                          onChanged: (v) => update(() => private = v),
                        ),
                        if (!private)
                          TextFormField(
                            initialValue: handle,
                            maxLength: 33,
                            decoration: const InputDecoration(
                              labelText: '@username',
                              hintText: '@my_channel',
                            ),
                            onChanged: (v) => handle = v.trim(),
                          ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Allow sharing & forwarding'),
                          value: sharing,
                          onChanged: (v) => update(() => sharing = v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Allow member posts'),
                          subtitle: const Text(
                            'Members can publish images, videos, documents and text.',
                          ),
                          value: memberPosts,
                          onChanged: (v) => update(() => memberPosts = v),
                        ),
                        DropdownButtonFormField<int>(
                          value: days,
                          decoration: const InputDecoration(
                            labelText: 'Auto-delete posts',
                          ),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Off')),
                            DropdownMenuItem(
                              value: 1,
                              child: Text('After 1 day'),
                            ),
                            DropdownMenuItem(
                              value: 7,
                              child: Text('After 7 days'),
                            ),
                            DropdownMenuItem(
                              value: 30,
                              child: Text('After 30 days'),
                            ),
                          ],
                          onChanged: (v) => update(() => days = v ?? 0),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Changing auto-delete applies to existing posts by their original date. Expired posts are removed permanently.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white60,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed:
                          () => Navigator.pop(dialog, {
                            'name': name,
                            'description': description,
                            'username': handle,
                            'visibility': private ? 'private' : 'public',
                            'sharing': sharing,
                            'member_posts': memberPosts,
                            'expiry_days': days,
                          }),
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
    if (values != null)
      await _action(() async {
        await MayaChannelsApi.request(_path, method: 'PATCH', body: values);
      });
  }

  Future<void> _publish() async {
    if (_busy || (_draft.text.trim().isEmpty && _draftPath == null)) return;
    final message = _draft.text.trim();
    if (message.length > 5000) {
      _channelNotice(context, 'Keep the message under 5,000 characters.');
      return;
    }
    setState(() => _busy = true);
    try {
      if (_draftPath != null) {
        await MayaChannelsApi.upload(
          _id,
          filePath: _draftPath,
          fileName: _draftName,
          text: message,
        );
      } else {
        await MayaChannelsApi.request(
          '$_path/posts',
          method: 'POST',
          body: {'text': message},
        );
      }
      if (!mounted) return;
      setState(() {
        _draft.clear();
        _draftPath = _draftName = null;
      });
      _draftFocus.unfocus();
      await _load(quiet: true);
    } catch (e) {
      if (mounted) _channelNotice(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload({bool avatar = false}) async {
    if (avatar) {
      await _action(() async {
        await MayaChannelsApi.upload(_id, avatar: true);
      });
    } else {
      await _attachments();
    }
  }

  Future<void> _recoverCamera() async {
    if (!Platform.isAndroid) return;
    try {
      final result = await ImagePicker().retrieveLostData();
      final files = result.files;
      if (mounted && files != null && files.isNotEmpty && _draftPath == null) {
        setState(() {
          _draftPath = files.first.path;
          _draftName = files.first.name;
        });
      }
    } catch (_) {}
  }

  Future<void> _attachments() async {
    if (_busy || _choosingAttachment) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (sheet) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Camera'),
                  onTap: () => Navigator.pop(sheet, 'camera'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Photos & videos'),
                  onTap: () => Navigator.pop(sheet, 'media'),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Files'),
                  onTap: () => Navigator.pop(sheet, 'file'),
                ),
              ],
            ),
          ),
    );
    if (choice == null || !mounted) return;
    _choosingAttachment = true;
    try {
      String? path, name;
      if (choice == 'camera') {
        final file = await _PermissionQueue.run(
          () => ImagePicker().pickImage(source: ImageSource.camera),
        );
        path = file?.path;
        name = file?.name;
      } else {
        final result = await _PermissionQueue.run(
          () => FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions:
                choice == 'media'
                    ? const [
                      'jpg',
                      'jpeg',
                      'png',
                      'webp',
                      'gif',
                      'mp4',
                      'mov',
                      'mkv',
                      'webm',
                    ]
                    : const [
                      'pdf',
                      'txt',
                      'csv',
                      'doc',
                      'docx',
                      'xls',
                      'xlsx',
                      'ppt',
                      'pptx',
                      'zip',
                    ],
          ),
        );
        path = result?.files.single.path;
        name = result?.files.single.name;
      }
      if (!mounted || path == null) return;
      if (await File(path).length() > 512 * 1024 * 1024) {
        if (mounted) _channelNotice(context, 'Choose a file under 512 MB.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _draftPath = path;
        _draftName = name;
      });
      _draftFocus.requestFocus();
    } catch (e) {
      if (mounted) _channelNotice(context, e);
    } finally {
      _choosingAttachment = false;
    }
  }

  Widget _composer() {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final image =
        _draftPath != null &&
        RegExp(
          r'\.(jpg|jpeg|png|webp|gif)$',
          caseSensitive: false,
        ).hasMatch(_draftPath!);
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: Material(
          color: AppThemes.kBg,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                if (_draftPath != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
                    child: Row(
                      children: [
                        if (image)
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: Image.file(
                              File(_draftPath!),
                              fit: BoxFit.contain,
                            ),
                          )
                        else
                          const Icon(
                            Icons.insert_drive_file_outlined,
                            size: 36,
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _draftName ?? 'Attachment',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove attachment',
                          onPressed:
                              _busy
                                  ? null
                                  : () => setState(() {
                                    _draftPath = _draftName = null;
                                  }),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Add attachment',
                      onPressed: _busy ? null : _attachments,
                      icon: const Icon(Icons.add, size: 29),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _draft,
                        focusNode: _draftFocus,
                        enabled: !_busy,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 5000,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Message or link…',
                          counterText: '',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 13,
                            horizontal: 8,
                          ),
                        ),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Post update',
                      onPressed:
                          _busy ||
                                  (_draft.text.trim().isEmpty &&
                                      _draftPath == null)
                              ? null
                              : _publish,
                      icon: const Icon(Icons.arrow_upward),
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

  Future<void> _preference(String key, bool value) => _action(() async {
    await MayaChannelsApi.request(
      '$_path/preferences',
      method: 'PATCH',
      body: {key: value},
    );
  });
  Future<void> _report() async {
    final text = await _channelInput(
      context,
      'Report channel',
      'What is the problem?',
      limit: 2000,
    );
    if (text != null)
      await _action(() async {
        await MayaChannelsApi.request(
          '$_path/report',
          method: 'POST',
          body: {'reason': text},
        );
        if (mounted) _channelNotice(context, 'Report received.');
      });
  }

  Future<void> _members() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => MayaChannelMembers(channelId: _id)),
    );
    if (mounted) await _load(quiet: true);
  }

  Future<void> _openMedia(Map<String, dynamic> p) async {
    final url = _mediaLink('${p['media'] ?? ''}');
    if (url == null) return;
    if (p['kind'] == 'image') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder:
              (_) => Scaffold(
                appBar: AppBar(title: Text('${p['filename'] ?? 'Image'}')),
                body: Center(
                  child: InteractiveViewer(
                    child: Image.network(
                      url.toString(),
                      errorBuilder:
                          (_, __, ___) => const Text(
                            'Reopen the channel to refresh this image.',
                          ),
                    ),
                  ),
                ),
              ),
        ),
      );
    } else if (p['kind'] == 'video') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder:
              (_) => NativeVideoPlayerScreen(
                videoUrl: url.toString(),
                title: '${p['text'] ?? p['filename'] ?? 'Video'}',
                uploader: '${_channel['name']}',
                sourcePageUrl: '$kBackendBaseUrl/channel/$_id?post=${p['id']}',
                channelId: _id,
                channelPostId: '${p['id']}',
                videoId: '${p['id']}',
                thumbnailUrl: '${p['thumbnail'] ?? ''}',
              ),
        ),
      );
      if (mounted) unawaited(MayaAds.afterVideo(context));
    } else {
      unawaited(
        MayaDownloads.start(
          FirebaseAuth.instance.currentUser?.uid ?? 'guest',
          url,
          '${p['filename'] ?? 'Channel attachment'}',
          thumbnail: '${p['thumbnail'] ?? ''}',
        ),
      );
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const MayaDownloadsScreen()),
      );
    }
  }

  Future<void> _openLink(String text) async {
    final match = RegExp(r'https://[^\s<>]+').firstMatch(text);
    if (match == null) return;
    final uri = _mediaLink(
      match.group(0)!.replaceFirst(RegExp(r'[.,;!?)]+$'), ''),
    );
    if (uri == null) return;
    if (_mayaChannelId(uri) != null || _isMayaVideoLink(uri)) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => _mayaLinkScreen(uri.toString())),
      );
    } else if (_isSocialLink(uri.toString()) || _fileExtension(uri) != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => MayaSocialMediaScreen(source: uri)),
      );
    } else {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _postAction(
    Map<String, dynamic> post,
    String action, {
    int? value,
  }) async {
    if (action == 'share') {
      await Share.share('${post['text'] ?? ''}\n${_channel['link']}');
      return;
    }
    if (action == 'translate') {
      final yes = await showDialog<bool>(
        context: context,
        builder:
            (c) => AlertDialog(
              title: const Text('Translate this message?'),
              content: const Text(
                'This opens Google Translate and sends this message text to Google.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Translate'),
                ),
              ],
            ),
      );
      if (yes == true)
        await launchUrl(
          Uri.https('translate.google.com', '/', {
            'sl': 'auto',
            'tl': Localizations.localeOf(context).languageCode,
            'text': '${post['text'] ?? ''}',
          }),
          mode: LaunchMode.externalApplication,
        );
      return;
    }
    if (action == 'forward') {
      final mine = await MayaChannelsApi.request('', query: {'scope': 'mine'});
      if (!mounted) return;
      final choices =
          (mine['channels'] as List? ?? [])
              .whereType<Map>()
              .where((c) => c['can_post'] == true && c['id'] != _id)
              .toList();
      final target = await showModalBottomSheet<String>(
        context: context,
        builder:
            (sheet) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  const ListTile(title: Text('Forward to a channel')),
                  for (final c in choices)
                    ListTile(
                      title: Text('${c['name']}'),
                      onTap: () => Navigator.pop(sheet, '${c['id']}'),
                    ),
                  if (choices.isEmpty)
                    const ListTile(
                      title: Text('No other channels you can publish to.'),
                    ),
                ],
              ),
            ),
      );
      if (target != null)
        await _action(() async {
          await MayaChannelsApi.request(
            '$_path/posts/${post['id']}/action',
            method: 'POST',
            body: {'action': 'forward', 'target': target},
          );
        });
      return;
    }
    if (action == 'delete') {
      final yes = await showDialog<bool>(
        context: context,
        builder:
            (c) => AlertDialog(
              title: const Text('Delete this post?'),
              content: const Text(
                'The post and unreferenced uploaded file will be removed from the channel.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
      );
      if (yes != true) return;
    }
    if (action == 'view') {
      if (!_viewed.add('${post['id']}')) return;
      try {
        final data = await MayaChannelsApi.request(
          '$_path/posts/${post['id']}/action',
          method: 'POST',
          body: {'action': 'view'},
        );
        if (mounted) setState(() => post['views'] = data['views']);
      } catch (_) {
        _viewed.remove('${post['id']}');
      }
      return;
    }
    final id = '${post['id']}';
    if (!_postMutations.add(id)) return;
    try {
      final updated = await MayaChannelsApi.request(
        '$_path/posts/$id/action',
        method: 'POST',
        body: {
          'action': action,
          if (value != null) 'value': post['reaction'] == value ? 0 : value,
          if (action == 'save') 'saved': post['saved'] != true,
        },
      );
      if (!mounted) return;
      setState(() {
        if (action == 'delete') {
          _posts.removeWhere((item) => item['id'] == id);
        } else {
          final index = _posts.indexWhere((item) => item['id'] == id);
          if (index >= 0) _posts[index] = updated;
        }
      });
    } catch (error) {
      if (mounted) _channelNotice(context, error);
    } finally {
      _postMutations.remove(id);
    }
  }

  Future<void> _info() async {
    final data = _channel;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppThemes.kCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder:
          (sheet) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: .9,
            minChildSize: .5,
            maxChildSize: .96,
            builder:
                (c, scroll) => ListView(
                  controller: scroll,
                  padding: const EdgeInsets.all(22),
                  children: [
                    Center(
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: GestureDetector(
                          onTap: () {
                            final image = '${data['photo'] ?? ''}';
                            if (image.isNotEmpty)
                              showDialog<void>(
                                context: sheet,
                                builder:
                                    (_) => Dialog(
                                      child: InteractiveViewer(
                                        child: Image.network(image),
                                      ),
                                    ),
                              );
                          },
                          child: _channelAvatar(data['photo']),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${data['name']}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (data['visibility'] == 'public')
                      Text(
                        '@${data['username']}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _mayaMint),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Chip(
                          label: Text(
                            _owner
                                ? 'Owner'
                                : data['following'] == true
                                ? 'Following'
                                : 'Not following',
                          ),
                        ),
                        if (data['visibility'] == 'public' || _owner)
                          IconButton(
                            tooltip: 'Forward channel link',
                            onPressed:
                                () => Share.share(
                                  '${data['invite_link'] ?? data['link']}',
                                ),
                            icon: const Icon(Icons.forward_outlined),
                          ),
                        if (data['visibility'] == 'public' || _owner)
                          IconButton(
                            tooltip: 'Share channel',
                            onPressed:
                                () => Share.share(
                                  '${data['invite_link'] ?? data['link']}',
                                ),
                            icon: const Icon(Icons.share_outlined),
                          ),
                        IconButton(
                          tooltip: 'Search messages',
                          onPressed: () {
                            Navigator.pop(sheet);
                            _searchPosts();
                          },
                          icon: const Icon(Icons.search),
                        ),
                      ],
                    ),
                    Text(
                      '${data['description'] ?? ''}',
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        height: 1.5,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.perm_media_outlined),
                            title: const Text('Media & links'),
                            onTap: () {
                              Navigator.pop(sheet);
                              _mediaLibrary();
                            },
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(sheet);
                            _storage();
                          },
                          child: const Text('Manage storage'),
                        ),
                      ],
                    ),
                    if (data['following'] == true)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mute notifications'),
                        value: data['muted'] == true,
                        onChanged: (v) {
                          Navigator.pop(sheet);
                          _preference('muted', v);
                        },
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        data['visibility'] == 'private'
                            ? Icons.lock_outline
                            : Icons.public,
                      ),
                      title: Text(
                        data['visibility'] == 'private'
                            ? 'Private channel'
                            : 'Public channel',
                      ),
                      subtitle: Text(
                        data['visibility'] == 'private'
                            ? 'Only invited members can read posts.'
                            : 'Discoverable by @username and exact name.',
                      ),
                    ),
                    if (data['following'] == true) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Profile privacy'),
                        subtitle: const Text(
                          'Hide your display name in the owner’s member list.',
                        ),
                        value: data['profile_visible'] != true,
                        onChanged: (v) {
                          Navigator.pop(sheet);
                          _preference('profile_visible', !v);
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Translate messages'),
                        subtitle: const Text(
                          'Show a Translate action on text posts.',
                        ),
                        value: data['translate'] == true,
                        onChanged: (v) {
                          Navigator.pop(sheet);
                          _preference('translate', v);
                        },
                      ),
                    ],
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.cleaning_services_outlined),
                      title: const Text('Clear cached media images'),
                      subtitle: const Text(
                        'This device only. Cloud posts and downloads are kept.',
                      ),
                      onTap: () {
                        for (final p in _posts) {
                          final url = '${p['thumbnail'] ?? ''}';
                          if (url.isNotEmpty)
                            imageCache.evict(NetworkImage(url));
                        }
                        Navigator.pop(sheet);
                        _channelNotice(context, 'Channel image cache cleared.');
                      },
                    ),
                    if (_owner) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.tune),
                        title: const Text('Channel settings'),
                        onTap: () {
                          Navigator.pop(sheet);
                          _edit();
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.people_outline),
                        title: const Text('Members & blocked users'),
                        subtitle: const Text(
                          'Visible to the channel owner only',
                        ),
                        onTap: () {
                          Navigator.pop(sheet);
                          _members();
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.photo_camera_outlined),
                        title: const Text('Change channel photo'),
                        onTap: () {
                          Navigator.pop(sheet);
                          _upload(avatar: true);
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.link),
                        title: const Text('Copy invitation link'),
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: '${data['invite_link']}'),
                          );
                          Navigator.pop(sheet);
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.refresh),
                        title: const Text('Revoke old invitation link'),
                        onTap: () {
                          Navigator.pop(sheet);
                          _rotateInvite();
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        title: const Text('Delete channel'),
                        onTap: () {
                          Navigator.pop(sheet);
                          _delete();
                        },
                      ),
                    ],
                    if (!_owner && data['following'] == true)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.remove_circle_outline),
                        title: const Text('Unfollow channel'),
                        onTap: () {
                          Navigator.pop(sheet);
                          _confirmUnfollow();
                        },
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.flag_outlined),
                      title: const Text('Report channel'),
                      onTap: () {
                        Navigator.pop(sheet);
                        _report();
                      },
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _confirmUnfollow() async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('Unfollow this channel?'),
            content: Text(
              _channel['visibility'] == 'private'
                  ? 'You will need an invitation to rejoin.'
                  : 'You can follow it again from Discover.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Unfollow'),
              ),
            ],
          ),
    );
    if (yes == true) await _follow(false);
  }

  Future<void> _rotateInvite() async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('Revoke the invitation link?'),
            content: const Text(
              'The old link will stop working. Existing members keep access.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Create new link'),
              ),
            ],
          ),
    );
    if (yes == true)
      await _action(() async {
        await MayaChannelsApi.request('$_path/invite', method: 'POST');
      });
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('Delete this channel permanently?'),
            content: const Text(
              'This removes all posts, uploads and memberships. This cannot be undone in the app.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (yes == true)
      await _action(() async {
        await MayaChannelsApi.request(_path, method: 'DELETE');
        if (mounted) Navigator.pop(context);
      });
  }

  Future<void> _searchPosts() async {
    final q = await _channelInput(
      context,
      'Search channel',
      'Message text or link',
      limit: 100,
    );
    if (q != null && mounted) {
      _search.text = q;
      await _load();
    }
  }

  Future<void> _mediaLibrary() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => MayaChannelLibrary(
              channelId: _id,
              onOpen: (p) async {
                if ('${p['media'] ?? ''}'.isNotEmpty)
                  await _openMedia(p);
                else
                  await _openLink('${p['text'] ?? ''}');
              },
            ),
      ),
    );
  }

  Future<void> _storage() async {
    final bytes = _posts.fold<int>(
      0,
      (sum, p) => sum + ((p['bytes'] as num?)?.toInt() ?? 0),
    );
    await showModalBottomSheet<void>(
      context: context,
      builder:
          (sheet) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: const Text('Channel storage'),
                  subtitle: Text(
                    '${(bytes / 1048576).toStringAsFixed(1)} MB in loaded posts · Upload limit: 512 MB per file by default',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Manage downloaded files on this device'),
                  onTap: () {
                    Navigator.pop(sheet);
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const MayaDownloadsScreen(),
                      ),
                    );
                  },
                ),
                if (_owner)
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Remove cloud media from the post menu'),
                    subtitle: Text(
                      'Deleting a post removes its unreferenced uploaded file.',
                    ),
                  ),
              ],
            ),
          ),
    );
  }

  @override
  void dispose() {
    _generation++;
    _poll?.cancel();
    _debounce?.cancel();
    _search.dispose();
    _draft.dispose();
    _draftFocus.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Roboto'),
    ),
    child: Scaffold(
      backgroundColor: AppThemes.kBg,
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _channel.isEmpty ? null : () => _info(),
          child: Row(
            children: [
              _channelAvatar(_channel['photo']),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_channel['name'] ?? _invitation?['name'] ?? 'Channel'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _owner
                          ? 'Owner'
                          : _channel['visibility'] == 'private'
                          ? 'Private channel'
                          : '${_channel['followers'] ?? 0} followers',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (_channel.isNotEmpty && !_owner && _channel['following'] != true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton(
                onPressed: _busy ? null : () => _follow(true),
                child: const Text(
                  'Follow',
                  style: TextStyle(
                    color: _mayaMint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (_channel.isNotEmpty)
            IconButton(
              tooltip: 'Channel details',
              onPressed: () => _info(),
              icon: const Icon(Icons.more_vert),
            ),
        ],
      ),
      bottomNavigationBar: _channel['can_post'] == true ? _composer() : null,
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _invitation != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 54,
                        color: _mayaMint,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${_invitation!['name']}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Join this channel to see its posts.'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : _join,
                        child: const Text('Join channel'),
                      ),
                    ],
                  ),
                ),
              )
              : _error.isNotEmpty && _channel.isEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error, textAlign: TextAlign.center),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                ),
              )
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.only(top: 10, bottom: 24),
                  children: [
                    if (_search.text.isNotEmpty)
                      ListTile(
                        title: Text('Search: ${_search.text}'),
                        trailing: IconButton(
                          onPressed: () {
                            _search.clear();
                            _load();
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    if (_posts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 90,
                          horizontal: 20,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 48,
                              color: _mayaMint,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'A fresh space for updates',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Messages, photos, videos and files will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                    for (final p in _posts) ...[
                      MayaChannelPost(
                        key: ValueKey(p['id']),
                        post: p,
                        canDelete:
                            _owner ||
                            p['author'] ==
                                FirebaseAuth.instance.currentUser?.uid,
                        sharing:
                            _channel['visibility'] == 'public' &&
                            _channel['sharing'] == true,
                        translate: _channel['translate'] == true,
                        onVisible: () => _postAction(p, 'view'),
                        onMedia: () => _openMedia(p),
                        onLink: () => _openLink('${p['text'] ?? ''}'),
                        onAction:
                            (action, value) =>
                                _postAction(p, action, value: value),
                      ),
                      if (_channel['visibility'] == 'public' && _search.text.isEmpty && _posts.length >= 3 && identical(p, _posts[2]))
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: MayaAdSlot(nativeAd: true)),
                    ],
                    if (_next != null)
                      TextButton(
                        onPressed: _paging ? null : () => _load(more: true),
                        child: Text(
                          _paging ? 'Loading…' : 'Load earlier posts',
                        ),
                      ),
                  ],
                ),
              ),
    ),
  );
}

class MayaChannelPost extends StatefulWidget {
  const MayaChannelPost({
    super.key,
    required this.post,
    required this.canDelete,
    required this.sharing,
    required this.translate,
    required this.onVisible,
    required this.onMedia,
    required this.onLink,
    required this.onAction,
  });
  final Map<String, dynamic> post;
  final bool canDelete, sharing, translate;
  final VoidCallback onVisible, onMedia, onLink;
  final void Function(String, int?) onAction;
  @override
  State<MayaChannelPost> createState() => _MayaChannelPostState();
}

class _MayaChannelPostState extends State<MayaChannelPost> {
  Timer? _timer;
  bool _sent = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 600),
      (_) => _visible(),
    );
  }

  void _visible() {
    if (!mounted || _sent || !(ModalRoute.of(context)?.isCurrent ?? true))
      return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final clip = Offset.zero & MediaQuery.sizeOf(context);
    final overlap = rect.intersect(clip);
    if (overlap.width > 0 &&
        overlap.height > 0 &&
        overlap.width * overlap.height >=
            math.min(rect.width * rect.height, clip.width * clip.height) * .6) {
      _sent = true;
      _timer?.cancel();
      widget.onVisible();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final text = '${p['text'] ?? ''}';
    final kind = '${p['kind'] ?? 'text'}';
    final created =
        DateTime.fromMillisecondsSinceEpoch(
          ((p['created'] as num?)?.toInt() ?? 0) * 1000,
        ).toLocal();
    Widget action(
      IconData icon,
      String label,
      String value, {
      int? vote,
      bool selected = false,
    }) => Expanded(
      child: TextButton(
        onPressed: () => widget.onAction(value, vote),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          minimumSize: const Size(0, 40),
          foregroundColor: selected ? _mayaMint : Colors.white70,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.only(top: 8, bottom: 12),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (p['forwarded'] == true)
                  const Text(
                    'Forwarded update',
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                const Spacer(),
                Text(
                  '${created.day}/${created.month} · ${TimeOfDay.fromDateTime(created).format(context)}',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
                if (widget.canDelete)
                  PopupMenuButton<String>(
                    iconSize: 18,
                    onSelected: (v) => widget.onAction(v, null),
                    itemBuilder:
                        (_) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete post'),
                          ),
                        ],
                  ),
              ],
            ),
          ),
          if (kind == 'image')
            GestureDetector(
              onTap: widget.onMedia,
              child: Image.network(
                '${p['thumbnail'] ?? ''}'.isNotEmpty
                    ? '${p['thumbnail']}'
                    : '${p['media'] ?? ''}',
                gaplessPlayback: true,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                cacheWidth: (MediaQuery.sizeOf(context).width *
                        MediaQuery.devicePixelRatioOf(context))
                    .round()
                    .clamp(1, 1440),
                errorBuilder:
                    (_, __, ___) => Image.network(
                      '${p['media'] ?? ''}',
                      fit: BoxFit.contain,
                      errorBuilder:
                          (_, __, ___) => const SizedBox(
                            height: 180,
                            child: Center(
                              child: Text('Image unavailable · tap to reopen'),
                            ),
                          ),
                    ),
              ),
            ),
          if (kind == 'video')
            GestureDetector(
              onTap: widget.onMedia,
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: AspectRatio(
                  aspectRatio:
                      (p['width'] is num &&
                              p['height'] is num &&
                              (p['height'] as num) > 0)
                          ? (p['width'] as num) / (p['height'] as num)
                          : 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      buildMediaThumbnail(
                        '${p['thumbnail'] ?? p['media'] ?? ''}',
                        text,
                        '${p['preview'] ?? ''}'.isNotEmpty
                            ? '${p['preview']}'
                            : '${p['media'] ?? ''}',
                        loopPreview: true,
                        fit: BoxFit.contain,
                      ),
                      if (kind == 'video')
                        const Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (kind == 'document')
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.description_outlined,
                color: _mayaMint,
                size: 34,
              ),
              title: Text('${p['filename'] ?? 'Document'}'),
              subtitle: Text(
                '${(((p['bytes'] as num?)?.toInt() ?? 0) / 1048576).toStringAsFixed(1)} MB',
              ),
              trailing: const Icon(Icons.download_outlined),
              onTap: widget.onMedia,
            ),
          if (text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: GestureDetector(
                onTap: text.contains('https://') ? widget.onLink : null,
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: text.contains('https://') ? _mayaMint : Colors.white,
                  ),
                ),
              ),
            ),
          if (widget.translate && text.isNotEmpty)
            TextButton(
              onPressed: () => widget.onAction('translate', null),
              child: const Text('Translate'),
            ),
          Row(
            children: [
              const Icon(
                Icons.visibility_outlined,
                size: 14,
                color: Colors.white54,
              ),
              const SizedBox(width: 5),
              Text(
                "${p['views'] ?? 0} ${(p['views'] ?? 0) == 1 ? 'view' : 'views'}",
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
          Row(
            children: [
              action(
                Icons.thumb_up_outlined,
                '${p['likes'] ?? 0}',
                'reaction',
                vote: 1,
                selected: p['reaction'] == 1,
              ),
              action(
                Icons.thumb_down_outlined,
                '${p['unlikes'] ?? 0}',
                'reaction',
                vote: -1,
                selected: p['reaction'] == -1,
              ),
              action(
                p['saved'] == true ? Icons.bookmark : Icons.bookmark_border,
                '',
                'save',
                selected: p['saved'] == true,
              ),
              if (widget.sharing) ...[
                action(Icons.share_outlined, '', 'share'),
                action(Icons.forward_outlined, '', 'forward'),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class MayaChannelLibrary extends StatefulWidget {
  const MayaChannelLibrary({
    super.key,
    this.channelId = '',
    this.saved = false,
    required this.onOpen,
  });
  final String channelId;
  final bool saved;
  final Future<void> Function(Map<String, dynamic>) onOpen;
  @override
  State<MayaChannelLibrary> createState() => _MayaChannelLibraryState();
}

class _MayaChannelLibraryState extends State<MayaChannelLibrary> {
  List<Map<String, dynamic>> _rows = [];
  String? _next;
  String _error = '';
  bool _loading = true, _busy = false;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    _busy = true;
    try {
      final data = await MayaChannelsApi.request(
        widget.saved ? '/account/saved/posts' : '/${widget.channelId}/posts',
        query: {
          if (!widget.saved) 'kind': 'media',
          if (more && _next != null) 'before': _next!,
        },
      );
      if (!mounted) return;
      final rows =
          (data['posts'] as List? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      setState(() {
        _rows = more ? [..._rows, ...rows] : rows;
        _next = data['next_before']?.toString();
        _loading = false;
        _error = '';
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = _channelError(e);
          _loading = false;
        });
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.saved ? 'Saved channel posts' : 'Media & links'),
    ),
    body:
        _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_error.isNotEmpty)
                    ListTile(
                      title: Text(_error),
                      trailing: TextButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ),
                  if (_rows.isEmpty && _error.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No posts here yet.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final p in _rows)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      leading: SizedBox(
                        width: 80,
                        height: 54,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: buildMediaThumbnail(
                            '${p['thumbnail'] ?? ''}',
                            '${p['filename'] ?? 'Update'}',
                            '',
                          ),
                        ),
                      ),
                      title: Text(
                        '${p['text'] ?? ''}'.isNotEmpty
                            ? '${p['text']}'
                            : '${p['filename'] ?? 'Media update'}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        '${p['kind'] ?? 'text'} · ${p['views'] ?? 0} views',
                      ),
                      onTap: () => widget.onOpen(p),
                    ),
                  if (_next != null)
                    TextButton(
                      onPressed: () => _load(more: true),
                      child: const Text('Load more'),
                    ),
                ],
              ),
            ),
  );
}

class MayaChannelMembers extends StatefulWidget {
  const MayaChannelMembers({super.key, required this.channelId});
  final String channelId;
  @override
  State<MayaChannelMembers> createState() => _MayaChannelMembersState();
}

class _MayaChannelMembersState extends State<MayaChannelMembers> {
  List<Map<String, dynamic>> _members = [];
  String _error = '';
  bool _loading = true, _busy = false, _more = false;
  int _offset = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool more = false}) async {
    try {
      final data = await MayaChannelsApi.request(
        '/${widget.channelId}/members',
        query: {'offset': more ? '$_offset' : '0'},
      );
      if (!mounted) return;
      final rows =
          (data['members'] as List? ?? [])
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
      setState(() {
        _members = more ? [..._members, ...rows] : rows;
        _offset = _members.length;
        _more = data['more'] == true;
        _loading = false;
        _error = '';
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = _channelError(e);
          _loading = false;
        });
    }
  }

  Future<void> _manage(String uid, String action) async {
    if (_busy) return;
    if (action == 'transfer') {
      final yes = await showDialog<bool>(
        context: context,
        builder:
            (c) => AlertDialog(
              title: const Text('Transfer channel ownership?'),
              content: const Text(
                'An invitation appears in the member’s Notifications. Ownership changes only after they accept.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Send request'),
                ),
              ],
            ),
      );
      if (yes != true) return;
    }
    _busy = true;
    try {
      await MayaChannelsApi.request(
        '/${widget.channelId}/members/${Uri.encodeComponent(uid)}',
        method: 'POST',
        body: {'action': action},
      );
      if (mounted) {
        if (action == 'transfer' || action == 'admin')
          _channelNotice(
            context,
            'Invitation sent. The member must accept in Notifications.',
          );
        await _load();
      }
    } catch (e) {
      if (mounted) _channelNotice(context, e);
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Members & blocked users')),
    body:
        _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
              children: [
                if (_error.isNotEmpty) ListTile(title: Text(_error)),
                for (final m in _members)
                  ListTile(
                    leading: Icon(
                      m['blocked'] == true ? Icons.block : Icons.person_outline,
                    ),
                    title: Text(
                      '${m['display_name'] ?? ''}'.isEmpty
                          ? 'MayaJaal member'
                          : '${m['display_name']}',
                    ),
                    subtitle: Text(
                      '${m['uid']} · ${m['blocked'] == true ? 'Blocked' : m['role']}',
                    ),
                    trailing:
                        m['role'] == 'owner'
                            ? const Icon(Icons.verified_user_outlined)
                            : PopupMenuButton<String>(
                              onSelected: (v) => _manage('${m['uid']}', v),
                              itemBuilder:
                                  (_) => [
                                    PopupMenuItem(
                                      value:
                                          m['blocked'] == true
                                              ? 'unblock'
                                              : 'block',
                                      child: Text(
                                        m['blocked'] == true
                                            ? 'Unblock member'
                                            : 'Block member',
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value:
                                          m['role'] == 'admin'
                                              ? 'member'
                                              : 'admin',
                                      child: Text(
                                        m['role'] == 'admin'
                                            ? 'Remove admin'
                                            : 'Make admin',
                                      ),
                                    ),
                                    if (m['blocked'] != true)
                                      const PopupMenuItem(
                                        value: 'transfer',
                                        child: Text('Transfer ownership'),
                                      ),
                                  ],
                            ),
                  ),
                if (_more)
                  TextButton(
                    onPressed: () => _load(more: true),
                    child: const Text('Load more members'),
                  ),
              ],
            ),
  );
}

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadGallery(request: true));
    });
  }

  Future<void> _loadGallery({bool request = false}) async {
    try {
      const options = PermissionRequestOption();
      final permission = await _PermissionQueue.run(() async {
        if (!mounted) return null;
        final current = await PhotoManager.getPermissionState(
          requestOption: options,
        );
        if (!mounted || !request || current.isAuth || current.hasAccess)
          return current;
        return PhotoManager.requestPermissionExtend(requestOption: options);
      });
      if (!mounted || permission == null) return;
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

      if (!mounted) return;
      if (albums.isEmpty) {
        setState(() {
          _permissionDenied = false;
          _loading = false;
        });
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
          _permissionDenied = false;
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
      body:
          _loading
              ? const Center(
                child: CircularProgressIndicator(color: AppThemes.kGreen),
              )
              : _permissionDenied
              ? _buildPermissionDenied()
              : Column(
                children: [
                  _buildTabs(),
                  const SizedBox(height: 4),
                  Expanded(
                    child:
                        _currentAssets.isEmpty ? _buildEmpty() : _buildGrid(),
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
            const Icon(
              Icons.photo_library_outlined,
              color: AppThemes.kGreen,
              size: 70,
            ),
            const SizedBox(height: 14),
            const Text(
              'GALLERY PERMISSION NEEDED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please allow gallery access to view photos and videos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                SoundService.playClick();
                unawaited(
                  _PermissionQueue.run(() async {
                    if (!mounted) return;
                    await PhotoManager.openSetting();
                  }),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemes.kGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'OPEN SETTINGS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
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
            'No ${_selectedTab == 'videos'
                ? 'videos'
                : _selectedTab == 'images'
                ? 'photos'
                : 'media'} found',
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
            border:
                active
                    ? Border.all(
                      color: AppThemes.kGreen.withOpacity(0.6),
                      width: 1.0,
                    )
                    : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: active ? AppThemes.kGreen : Colors.white38,
                size: 14,
              ),
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
              errorBuilder:
                  (c, e, s) => Container(
                    color: AppThemes.kCardBg,
                    child: const Icon(
                      Icons.broken_image,
                      color: Colors.white24,
                    ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppThemes.kBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_arrow,
                      color: AppThemes.kGreen,
                      size: 9,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _formatDuration(asset.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
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

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _openPreview(AssetEntity asset) {
    showDialog(
      context: context,
      builder:
          (c) => Dialog(
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
                      errorBuilder:
                          (c, e, s) => const Icon(
                            Icons.broken_image,
                            color: Colors.white24,
                            size: 50,
                          ),
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
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 20,
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
        final snap =
            await FirebaseDatabase.instance
                .ref('users/$uid/savedVideos')
                .once();
        if (snap.snapshot.value != null && snap.snapshot.value is Map) {
          final map = Map<String, dynamic>.from(snap.snapshot.value as Map);
          final cloudList =
              map.values
                  .map((v) => Map<String, dynamic>.from(v as Map))
                  .toList();
          cloudList.sort(
            (a, b) => (b['savedAt'] ?? 0).compareTo(a['savedAt'] ?? 0),
          );
          if (mounted) {
            setState(() {
              _saved = WatchHistory.mergeRecords(
                cloudList,
                limit: cloudList.length,
              );
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
    await prefs.setBool('saved_${uid}_${item['id']}', false);
    await WatchHistory.syncSavedRecordCloud(item, false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.kBg,
      appBar: AppBar(title: Text(tr('favorites'))),
      body:
          _loading
              ? const Center(
                child: CircularProgressIndicator(color: AppThemes.kGreen),
              )
              : _saved.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bookmark_border,
                      size: 50,
                      color: Colors.white24,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No saved videos yet',
                      style: TextStyle(color: Colors.white38, fontSize: 12.5),
                    ),
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

                  final thumbStreamUrl =
                      streamUrl.isNotEmpty
                          ? streamUrl
                          : (id.isNotEmpty
                              ? '$kBackendBaseUrl/stream/$id'
                              : url);

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
                            sourceUrl: url,
                            loopPreview: true,
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
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'By: ${item['uploader'] ?? 'Node'}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.white38,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _removeSaved(i),
                      ),
                      onTap: () {
                        SoundService.playClick();
                        Haptic.light();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _mayaPlaybackEntry(url),
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
    WatchHistory.changes.addListener(_historyChanged);
    _loadHistory();
  }

  void _historyChanged() {
    if (mounted) unawaited(_loadHistory());
  }

  @override
  void dispose() {
    WatchHistory.changes.removeListener(_historyChanged);
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();
    final key = 'watch_history_v2_${uid ?? 'guest'}';

    if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
    setState(() {
      _history = WatchHistory.localRecords(prefs, key);
      _loading = false;
    });
    if (uid == null) return;

    try {
      final snap = await FirebaseDatabase.instance
          .ref('users/$uid/watchHistory')
          .orderByChild('syncedAt')
          .limitToLast(60)
          .once()
          .timeout(const Duration(seconds: 8));
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
      final cloud = snap.snapshot.children
          .map((child) => child.value)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item));
      setState(() {
        _history = WatchHistory.mergeRecords([
          ...WatchHistory.localRecords(prefs, key),
          ...cloud,
        ]);
      });
    } catch (_) {}
  }

  Future<void> _deleteItem(int index) async {
    SoundService.playClick();
    Haptic.light();
    final item = _history[index];
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();
    final key = 'watch_history_v2_${uid ?? 'guest'}';

    setState(() => _history.removeAt(index));
    await prefs.setString(key, jsonEncode(_history));

    if (uid != null && uid != 'guest') {
      final safeKey = (item['id'] ?? '').toString();
      if (safeKey.isNotEmpty) {
        await FirebaseDatabase.instance
            .ref('users/$uid/watchHistory/$safeKey')
            .remove();
      }
    }
  }

  Future<void> _clearAll() async {
    SoundService.playClick();
    Haptic.medium();
    final uid = FirebaseAuth.instance.currentUser?.uid;
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
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
          const SnackBar(
            backgroundColor: AppThemes.kCardBg,
            content: Text(
              'Already saved!',
              style: TextStyle(color: AppThemes.kGreen),
            ),
          ),
        );
      }
      return;
    }

    savedList.insert(0, item);
    await prefs.setString(key, jsonEncode(savedList));
    await WatchHistory.syncSavedRecordCloud(item, true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppThemes.kCardBg,
          content: Text(
            '✅ Video Saved to Cloud!',
            style: TextStyle(color: AppThemes.kGreen),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.kBg,
      appBar: AppBar(
        title: const Text(
          'Watch history',
          style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.orangeAccent),
              onPressed: _clearAll,
            ),
        ],
      ),
      body:
          _loading
              ? const Center(
                child: CircularProgressIndicator(color: AppThemes.kGreen),
              )
              : _history.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 50, color: Colors.white24),
                    const SizedBox(height: 10),
                    Text(
                      tr('no_history'),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                itemCount: _history.length,
                itemBuilder: (c, i) {
                  final item = _history[i];
                  final thumb = _storedVideoThumbnail(item);
                  String title = item['title']?.toString().trim() ?? '';
                  if (title.isEmpty || title == 'null') {
                    title = item['id']?.toString() ?? 'MayaJaal Video';
                  }
                  final url = item['url']?.toString() ?? '';
                  final streamUrl = item['streamUrl']?.toString() ?? '';
                  final id = item['id']?.toString() ?? '';

                  final thumbStreamUrl = streamUrl;

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
                            sourceUrl: url,
                            loopPreview: true,
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
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'By: ${item['uploader'] ?? 'Node'}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.white38,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.bookmark_add_outlined,
                              size: 18,
                              color: AppThemes.kNeonCyan,
                            ),
                            onPressed: () => _saveItem(item),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.redAccent,
                            ),
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
                            builder: (_) => _mayaPlaybackEntry(url),
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

  final List<String> _themes = mayaThemeColors.keys.toList();
  final List<String> _languages = mayaLanguageNames.keys.toList();
  final List<String> _downloadLocations = [
    'Internal Storage / Mayajaall',
    'Internal Storage / Download',
    'Internal Storage / Movies',
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
      _downloadLocation =
          prefs.getString('download_location') ??
          'Internal Storage / Mayajaall';
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
          content: Text(
            '✅ Settings Saved Successfully!',
            style: TextStyle(color: AppThemes.kGreen),
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.kBg,
      appBar: AppBar(title: Text(tr('settings')), actions: [IconButton(tooltip: 'AI translation trial', icon: const Icon(Icons.translate), onPressed: () => MayaAI.open(context))]),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: [
          ListTile(
            leading: const Icon(
              Icons.volume_up,
              color: AppThemes.kGreen,
              size: 20,
            ),
            title: Text(
              tr('sound_effects'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
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
            leading: const Icon(
              Icons.palette_outlined,
              color: AppThemes.kNeonCyan,
              size: 20,
            ),
            title: Text(
              tr('dark_theme'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              _currentTheme,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: Colors.white24,
            ),
            onTap: _showThemeDialog,
          ),
          Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(
              Icons.language,
              color: AppThemes.kGreen,
              size: 20,
            ),
            title: Text(
              tr('language'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              _language,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: Colors.white24,
            ),
            onTap: _showLanguageDialog,
          ),
          Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.shield_outlined, color: _mayaMint),
            title: Text(tr('comment_settings')),
            subtitle: const Text('Blocked words, abusive language and replies'),
            trailing: const Icon(Icons.chevron_right),
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MayaCommentSettings(),
                  ),
                ),
          ),
          if (MayaAds.available) ...[
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: AppThemes.kGreen, size: 20),
              title: const Text('Privacy preferences', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: const Text('Manage data and privacy choices', style: TextStyle(color: Colors.white38, fontSize: 11)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white24),
              onTap: () => MayaAds.settings(context),
            ),
          ],
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(
              Icons.download,
              color: AppThemes.kGold,
              size: 20,
            ),
            title: Text(
              tr('download_location'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              _downloadLocation,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: Colors.white24,
            ),
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
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemes.kGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '> MayaJaal v1.3.0 // Quantum Build',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppThemes.kCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (c) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(c).height * .72,
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      tr('dark_theme'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      'Professional dark palettes · live preview',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(c),
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.6,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: _themes.length,
                      itemBuilder: (_, i) {
                        final name = _themes[i];
                        final color = mayaThemeColors[name]!;
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            setState(() => _currentTheme = name);
                            themeNotifier.value = name;
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('app_theme', name);
                            if (c.mounted) Navigator.pop(c);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: color.withOpacity(
                                  _currentTheme == name ? 1 : .3,
                                ),
                                width: _currentTheme == name ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 10,
                                      backgroundColor: color,
                                    ),
                                    const Spacer(),
                                    if (_currentTheme == name)
                                      Icon(
                                        Icons.check_circle,
                                        color: color,
                                        size: 19,
                                      ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showLanguageDialog() {
    String query = '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppThemes.kCardBg,
      builder:
          (c) => StatefulBuilder(
            builder: (c, update) {
              final languages =
                  _languages
                      .where(
                        (name) => ('$name ${mayaLanguageNames[name]}')
                            .toLowerCase()
                            .contains(query.toLowerCase()),
                      )
                      .toList();
              return SizedBox(
                height: MediaQuery.sizeOf(c).height * .8,
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        tr('language'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                      subtitle: Text(
                        '${_languages.length} languages · core controls translated',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(c),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search language',
                        ),
                        onChanged: (value) => update(() => query = value),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Some detailed screens currently use English.',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: languages.length,
                        itemBuilder: (_, i) {
                          final name = languages[i];
                          return ListTile(
                            title: Text(mayaLanguageNames[name]!),
                            subtitle: Text(name),
                            trailing:
                                _language == name
                                    ? const Icon(
                                      Icons.check_circle,
                                      color: _mayaMint,
                                    )
                                    : null,
                            onTap: () async {
                              setState(() => _language = name);
                              languageNotifier.value = name;
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setString('language', name);
                              if (c.mounted) Navigator.pop(c);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  void _showDownloadLocationDialog() {
    SoundService.playClick();
    showDialog(
      context: context,
      builder:
          (c) => AlertDialog(
            backgroundColor: AppThemes.kCardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppThemes.kBorder),
            ),
            title: Text(
              tr('download_location'),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  _downloadLocations.map((loc) {
                    return RadioListTile<String>(
                      title: Text(
                        loc,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
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

class MayaPlaybackVariant {
  final String label;
  final Uri url;
  final String codec;
  const MayaPlaybackVariant(this.label, this.url, {this.codec = ''});
}

Widget _mayaPlaybackEntry(String source) {
  final local = Uri.tryParse(source);
  if (local != null && _mayaChannelId(local) != null) {
    if ((local.queryParameters['post'] ?? '').isNotEmpty)
      return MayaChannelPostEntry(source: local);
    return _mayaLinkScreen(source);
  }
  if (local?.scheme == 'file') {
    final file = File.fromUri(local!);
    return MayaOfflineVideo(file: file, name: file.uri.pathSegments.last);
  }
  final uri = Uri.tryParse(source);
  if (uri != null && _isSocialLink(source))
    return MayaSocialMediaScreen(source: uri);
  return StreamPreviewScreen(targetUrl: source);
}

Future<void> _mayaKeepAwake(bool enabled) async {
  try {
    await const MethodChannel(
      'mayajaal/share',
    ).invokeMethod<void>('keepScreenOn', enabled);
  } catch (_) {}
}

class NativeVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String uploader;
  final String sourcePageUrl;
  final String videoId;
  final String thumbnailUrl;
  final List<MayaPlaybackVariant> variants;
  final String channelId, channelPostId;

  const NativeVideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.uploader,
    required this.sourcePageUrl,
    required this.videoId,
    this.thumbnailUrl = '',
    this.variants = const [],
    this.channelId = '',
    this.channelPostId = '',
  });

  @override
  State<NativeVideoPlayerScreen> createState() =>
      _NativeVideoPlayerScreenState();
}

class _NativeVideoPlayerScreenState extends State<NativeVideoPlayerScreen>
    with WidgetsBindingObserver {
  BetterPlayerController? _betterPlayerController;
  VideoPlayerController? _directPlayer;
  int _playbackAttempt = 0;
  bool _expiryRecoveryUsed = false, _refreshingSocialLink = false;
  int _preparationRetries = 0;
  bool _directPlayerReady = false;
  final GlobalKey _videoKey = GlobalKey();

  bool _isInitialized = false;
  bool _hasError = false;
  String _streamError = 'Stream Connection Error';
  String _decoderHint = '';

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

  String _selectedQuality = 'Original';
  String? _qualityUrl;
  List<MayaPlaybackVariant> _activeVariants = [];
  bool _qualityChanging = false;
  Timer? _positionTicker;
  bool _screenLocked = false;
  bool _recordedPlayback = false;
  int _adPlayMs = 0;
  bool _adPreloadRequested = false;
  final MayaVideoAdSchedule _adSchedule = MayaVideoAdSchedule();
  final Stopwatch _adClock = Stopwatch()..start();
  int _lastAdTick = 0;
  int? _lastAdPosition;
  bool _adBreakRunning = false;

  Future<void> _runScheduledAd() async {
    if (_adBreakRunning || !mounted || !_playing || !MayaAds.canShow || !MayaAds.scheduledVideoAvailable) return;
    final attempt = _playbackAttempt;
    _adBreakRunning = true;
    try {
      await _directPlayer?.pause();
      await _betterPlayerController?.pause();
      if (!mounted || attempt != _playbackAttempt || ModalRoute.of(context)?.isCurrent != true) return;
      if (MayaAds.canShow) await MayaAds.playScheduledVideo();
    } catch (e) { debugPrint('Maya video ad: $e'); }
    finally {
      // Activity results can arrive just before Flutter is resumed.
      for (var i = 0; i < 12 && mounted && WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      if (mounted && attempt == _playbackAttempt && !_hasError && ModalRoute.of(context)?.isCurrent == true && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        try { await _directPlayer?.play(); await _betterPlayerController?.play(); } catch (_) {}
      }
      _lastAdPosition = null;
      _lastAdTick = _adClock.elapsedMilliseconds;
      _adBreakRunning = false;
    }
  }
  int _quarterTurns = 0;
  bool get _social => _isSocialLink(widget.sourcePageUrl);
  bool get _channelVideo =>
      widget.channelId.isNotEmpty && widget.channelPostId.isNotEmpty;
  String get _channelPostPath =>
      '/${Uri.encodeComponent(widget.channelId)}/posts/${Uri.encodeComponent(widget.channelPostId)}';
  Duration get _position =>
      _directPlayer?.value.position ??
      _betterPlayerController?.videoPlayerController?.value.position ??
      Duration.zero;
  Duration get _duration =>
      _directPlayer?.value.duration ??
      _betterPlayerController?.videoPlayerController?.value.duration ??
      Duration.zero;
  bool get _playing =>
      _directPlayer?.value.isPlaying ??
      _betterPlayerController?.isPlaying() ??
      false;
  double get _aspect =>
      _directPlayer?.value.aspectRatio ??
      _betterPlayerController?.videoPlayerController?.value.aspectRatio ??
      16 / 9;

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
  Map<String, dynamic> _community = {};
  String get _communityKey =>
      MayaCommunityApi.videoKey(widget.videoId, widget.sourcePageUrl);
  String _ownerUid = '';

  StreamSubscription? _statsSub;
  StreamSubscription? _likeSub;
  StreamSubscription? _unlikeSub;

  bool _viewReported = false;
  Timer? _watchTimer;
  int _watchedSeconds = 0;

  List<Map<String, dynamic>> _relatedVideos = [];
  bool _relatedLoading = true;
  int _relatedGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MayaAds.beginVideo();
    unawaited(MayaAds.load());
    _activeVariants = widget.variants;
    if (widget.variants.isNotEmpty) {
      _selectedQuality =
          widget.variants
              .firstWhere(
                (v) => v.url.toString() == widget.videoUrl,
                orElse: () => widget.variants.first,
              )
              .label;
    }
    if (!_channelVideo) _loadUserPrefs();
    unawaited(_loadCommunity());
    _initVideo();
    if (!_social && !_channelVideo) {
      _startStatsListeners();
      _fetchOwner().then((_) => _loadRelatedVideos());
      _fetchVideoMeta();
    } else {
      _loadRelatedVideos();
    }
    _positionTicker = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (mounted && _isInitialized) {
        final tick = _adClock.elapsedMilliseconds;
        final elapsed = tick - _lastAdTick;
        final position = _position.inMilliseconds;
        final previous = _lastAdPosition;
        _lastAdTick = tick;
        _lastAdPosition = position;
        final active = !_adBreakRunning && _playing && !_hasError && ModalRoute.of(context)?.isCurrent == true && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
        // Count real foreground watching, not pauses, buffering, seeks or speed jumps.
        final advance = previous == null ? 0 : position - previous;
        if (active && elapsed > 0 && elapsed <= 1200 && advance > 0 && advance <= elapsed * 3 + 350) {
          _adPlayMs += elapsed;
          if (MayaAds.scheduledVideoAvailable) {
            final due = _adSchedule.add(elapsed);
            if (due && MayaAds.canShow) unawaited(_runScheduledAd());
          } else if (MayaAds.canShow && _adPlayMs >= 45000 && !_adPreloadRequested) {
            _adPreloadRequested = true;
            unawaited(MayaAds.prepareInterstitial());
          }
        }
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _directPlayer?.pause();
      _betterPlayerController?.pause();
      unawaited(_mayaKeepAwake(false));
    } else {
      unawaited(_mayaKeepAwake(_isInitialized && !_hasError));
    }
  }

  Future<void> _recordStarted() async {
    if (_recordedPlayback) return;
    _recordedPlayback = true;
    if (_channelVideo) {
      unawaited(
        MayaChannelsApi.request(
          '$_channelPostPath/action',
          method: 'POST',
          body: {'action': 'view'},
        ).then((_) => _loadCommunity()).catchError((Object _) {}),
      );
    }
    if (_social)
      unawaited(
        MayaCommunityApi.request(
          '/$_communityKey/view',
          method: 'POST',
        ).then((_) => _loadCommunity()).catchError((Object _) {}),
      );
    await WatchHistory.recordPlayback({
      'url': widget.sourcePageUrl,
      'id': widget.videoId,
      'title': widget.title,
      'uploader': widget.uploader,
      'thumbnail': widget.thumbnailUrl,
      'streamUrl': _qualityUrl ?? widget.videoUrl,
      'time': DateTime.now().toIso8601String(),
    });
    unawaited(_loadRelatedVideos());
    if (widget.thumbnailUrl.startsWith('https://')) {
      try {
        final response = await http
            .get(Uri.parse(widget.thumbnailUrl))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200 &&
            response.bodyBytes.length < 600000 &&
            (response.headers['content-type'] ?? '').startsWith('image/')) {
          await WatchHistory.saveThumbnail(
            widget.sourcePageUrl,
            base64Encode(response.bodyBytes),
          );
        }
      } catch (_) {}
    }
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
    if (_social || _channelVideo) return;
    if (_viewReported) return;
    _viewReported = true;

    try {
      final uri = Uri.parse(widget.sourcePageUrl);
      final token = uri.queryParameters['t'] ?? uri.queryParameters['s'] ?? '';
      final deviceId = await DeviceIdHelper.get();

      final url =
          token.isNotEmpty
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

      await http
          .post(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 10));
      debugPrint('✅ Qualified 10s View Reported to Server');
    } catch (e) {
      debugPrint('View report error: $e');
    }
  }

  void _startWatchTracking() {
    _watchTimer?.cancel();
    _watchTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      final playing =
          _directPlayer?.value.isPlaying ??
          _betterPlayerController?.isPlaying() ??
          false;
      if (playing && _watchedSeconds < 10) {
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

    _likeSub = FirebaseService.isLikedStream(widget.videoId, uid).listen((
      liked,
    ) {
      if (mounted) {
        setState(() => _isLiked = liked);
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('liked_${uid}_${widget.videoId}', liked);
        });
      }
    });

    _unlikeSub = FirebaseService.isUnlikedStream(widget.videoId, uid).listen((
      unliked,
    ) {
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
      final snap =
          await FirebaseDatabase.instance
              .ref('links/${widget.videoId}/ownerUid')
              .once();
      _ownerUid = snap.snapshot.value?.toString() ?? '';
    } catch (_) {}
  }

  Future<void> _loadRelatedVideos() async {
    final generation = ++_relatedGeneration;
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final local =
        WatchHistory.localRecords(
          prefs,
          'watch_history_v2_$uid',
        ).where((r) => r['id'] != widget.videoId).take(20).toList();
    if (!mounted || generation != _relatedGeneration) return;
    setState(() {
      _relatedVideos = local;
      _relatedLoading = false;
    });
  }

  Future<void> _loadUserPrefs() async {
    try {
      final uid = MayaJaalAccount.cachedUid;
      if (uid != null) {
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _isSaved = WatchHistory.localRecords(
            prefs,
            'saved_videos_v1_$uid',
          ).any(
            (item) =>
                WatchHistory.recordKey(item) ==
                WatchHistory.recordKey({
                  'id': widget.videoId,
                  'url': widget.sourcePageUrl,
                }),
          );
          _isLiked = prefs.getBool('liked_${uid}_${widget.videoId}') ?? false;
          _isUnliked =
              prefs.getBool('unliked_${uid}_${widget.videoId}') ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _retryVideo({bool automatic = false}) async {
    if (_refreshingSocialLink) return;
    _refreshingSocialLink = true;
    if (!automatic) {
      _expiryRecoveryUsed = false;
      _preparationRetries = 0;
    }
    final position = _position;
    try {
      if (_social) {
        final media = await MayaResolvedMedia.load(
          Uri.parse(widget.sourcePageUrl),
          force: true,
        );
        if (!mounted) return;
        final selected =
            media.variants.where((v) => v.label == _selectedQuality).toList();
        final url = selected.isNotEmpty ? selected.first.url : media.stream;
        if (url == null)
          throw const HttpException(
            'The source did not return a playable video.',
          );
        _qualityUrl = url.toString();
        _activeVariants = media.variants;
        if (selected.isEmpty && media.variants.isNotEmpty) {
          _selectedQuality =
              media.variants
                  .firstWhere(
                    (v) => v.url == url,
                    orElse: () => media.variants.first,
                  )
                  .label;
        }
      }
      if (_channelVideo) {
        final post = await MayaChannelsApi.request(_channelPostPath);
        if (!mounted) return;
        _qualityUrl = '${post['media'] ?? ''}';
      }
      await _initVideo(refreshLink: true);
      for (
        var i = 0;
        i < 120 && mounted && !_isInitialized && !_hasError;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (mounted && _isInitialized && position > Duration.zero)
        await _seekTo(position);
    } catch (error) {
      if (mounted)
        setState(() {
          _hasError = true;
          _streamError =
              error is HttpException
                  ? error.message
                  : 'Could not refresh this source';
        });
    } finally {
      _refreshingSocialLink = false;
    }
  }

  Future<Uri> _refreshPlaybackLink(Uri page) async {
    final token = page.queryParameters['t'] ?? page.queryParameters['s'] ?? '';
    final path = '/api/stream-info/${Uri.encodeComponent(widget.videoId)}';
    final endpoint = Uri.parse(
      '$kBackendBaseUrl$path',
    ).replace(queryParameters: token.isEmpty ? null : {'t': token});
    final deviceId = await DeviceIdHelper.get();
    final response = await http
        .get(
          endpoint,
          headers: SecurityGuard.signedHeaders(
            method: 'GET',
            path: path,
            body: '',
            deviceId: deviceId,
            uid: MayaJaalAccount.cachedUid,
          ),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200)
      throw HttpException('Video API HTTP ${response.statusCode}');
    final data = jsonDecode(response.body);
    if (data is! Map || data['success'] != true) {
      throw const HttpException(
        'Video API did not return playback information',
      );
    }
    final url = _mediaLink(
      (data['streamUrl'] ?? data['url'] ?? data['video_url'] ?? '').toString(),
    );
    if (url == null)
      throw const HttpException('Video API did not return a stream URL');
    return url;
  }

  Future<void> _checkStreamFailure(
    int attempt,
    Uri uri,
    Map<String, String> headers,
  ) async {
    final client = http.Client();
    String message;
    var status = 0;
    try {
      final request =
          http.Request('GET', uri)
            ..headers.addAll(headers)
            ..headers['Range'] = 'bytes=0-0';
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 25));
      status = response.statusCode;
      final type = response.headers['content-type'] ?? '';
      if (status != 200 && status != 206) {
        message = 'Stream server returned HTTP $status';
        if (type.contains('json')) {
          final bytes = <int>[];
          await for (final chunk in response.stream.timeout(
            const Duration(seconds: 5),
          )) {
            bytes.addAll(chunk.take(4096 - bytes.length));
            if (bytes.length >= 4096) break;
          }
          try {
            final data = jsonDecode(utf8.decode(bytes));
            if (data is Map && data['detail'] is String) {
              final detail = (data['detail'] as String).replaceAll(
                RegExp(r'https?://[^\s]+'),
                '[media URL]',
              );
              message +=
                  ': ${detail.length > 250 ? detail.substring(0, 250) : detail}';
            }
          } catch (_) {}
        }
      } else if (type.contains('text/html') ||
          type.contains('application/json')) {
        message = 'Stream URL returned a page (HTTP $status)';
      } else {
        message =
            _decoderHint.isEmpty
                ? 'Player could not initialize (stream HTTP $status)'
                : 'Player: ${_decoderHint.replaceAll(RegExp(r"https?://[^\s]+"), "[media URL]")}';
      }
    } on TimeoutException {
      message = 'The stream is taking longer than expected. Please retry.';
    } catch (_) {
      message = 'Could not reach the stream server from this phone';
    } finally {
      client.close();
    }
    if (!mounted || attempt != _playbackAttempt || !_hasError) return;
    if (((_social && status == 410) ||
            (_channelVideo && (status == 403 || status == 410))) &&
        !_expiryRecoveryUsed) {
      _expiryRecoveryUsed = true;
      await _retryVideo(automatic: true);
      return;
    }
    if (status == 503 &&
        _preparationRetries < 2 &&
        message.toLowerCase().contains('preparing')) {
      _preparationRetries++;
      setState(() => _streamError = 'Preparing this quality…');
      await Future<void>.delayed(const Duration(seconds: 5));
      if (mounted &&
          attempt == _playbackAttempt &&
          (ModalRoute.of(context)?.isCurrent ?? true))
        await _initVideo();
      return;
    }
    setState(() => _streamError = message);
  }

  Future<void> _initVideo({bool refreshLink = false}) async {
    unawaited(_mayaKeepAwake(false));
    final attempt = ++_playbackAttempt;
    final oldController = _betterPlayerController;
    final oldDirect = _directPlayer;
    _betterPlayerController = null;
    _directPlayer = null;
    oldController?.dispose();
    if (oldDirect != null) unawaited(oldDirect.dispose());
    setState(() {
      _hasError = false;
      _streamError = 'Stream Connection Error';
      _decoderHint = '';
      _isInitialized = false;
      _directPlayerReady = false;
    });
    String realVideoUrl = (_qualityUrl ?? widget.videoUrl).trim();
    if (_social && _qualityUrl == null) {
      try {
        final media = await MayaResolvedMedia.load(
          Uri.parse(widget.sourcePageUrl),
        );
        if (!mounted || attempt != _playbackAttempt) return;
        if (media.stream == null)
          throw const HttpException(
            'No playable video returned by this source.',
          );
        realVideoUrl = media.stream.toString();
        _qualityUrl = realVideoUrl;
        _activeVariants = media.variants;
      } catch (error) {
        if (mounted && attempt == _playbackAttempt)
          setState(() {
            _hasError = true;
            _streamError = _channelError(error);
          });
        return;
      }
    }
    final sourcePage = Uri.tryParse(widget.sourcePageUrl);
    if (refreshLink && sourcePage != null && _isMayaVideoLink(sourcePage)) {
      try {
        realVideoUrl = (await _refreshPlaybackLink(sourcePage)).toString();
      } catch (error) {
        if (mounted)
          setState(() {
            _hasError = true;
            _streamError =
                error is HttpException
                    ? error.message
                    : 'Could not refresh the video URL';
          });
        return;
      }
      if (!mounted || attempt != _playbackAttempt) return;
    }

    if (realVideoUrl.isEmpty || !realVideoUrl.startsWith('http')) {
      realVideoUrl = '$kBackendBaseUrl/stream/${widget.videoId}';
    }

    if (realVideoUrl.startsWith('https://mayajaal.online')) {
      realVideoUrl = realVideoUrl.replaceFirst(
        'https://mayajaal.online',
        kBackendBaseUrl,
      );
    }

    final stream = Uri.parse(realVideoUrl);
    final isTeraBox = TeraBoxResolver.isTeraBoxLink(widget.sourcePageUrl);
    final isHls = isTeraBox || stream.path.toLowerCase().endsWith('.m3u8');
    final headers = <String, String>{
      if (isTeraBox) ...{
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Referer': 'https://www.terabox.com/',
      },
      'Accept': '*/*',
      'Accept-Encoding': 'identity',
    };

    final config = BetterPlayerConfiguration(
      controlsConfiguration: const BetterPlayerControlsConfiguration(
        showControls: false,
      ),
      allowedScreenSleep: false,
      autoDispose: false,
      autoPlay: true,
      aspectRatio: null,
      fit: BoxFit.contain,
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                _streamError,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
              TextButton(
                onPressed: _retryVideo,
                child: const Text(
                  'RETRY',
                  style: TextStyle(color: AppThemes.kGreen),
                ),
              ),
            ],
          ),
        );
      },
    );

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      realVideoUrl,
      videoFormat: isHls ? BetterPlayerVideoFormat.hls : null,
      headers: headers,
    );

    final controller = BetterPlayerController(config);
    _betterPlayerController = controller;
    final initialized = Completer<void>();
    void showFailure() {
      if (!mounted ||
          !identical(_betterPlayerController, controller) ||
          _hasError)
        return;
      if (!initialized.isCompleted) initialized.complete();
      if (!_isInitialized) {
        _betterPlayerController = null;
        scheduleMicrotask(() {
          controller.dispose();
          if (mounted && attempt == _playbackAttempt) {
            unawaited(_tryDirectPlayback(attempt, stream, headers));
          }
        });
        return;
      }
      unawaited(_mayaKeepAwake(false));
      setState(() => _hasError = true);
      unawaited(_checkStreamFailure(attempt, stream, headers));
    }

    controller.addEventsListener((event) {
      if (!mounted || !identical(_betterPlayerController, controller)) return;
      if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
        _decoderHint =
            '${event.parameters?['exception'] ?? 'Decoder initialization failed'}';
        showFailure();
      } else if (event.betterPlayerEventType ==
              BetterPlayerEventType.initialized &&
          !initialized.isCompleted) {
        initialized.complete();
        setState(() => _isInitialized = true);
        _resetControlTimer();
        _startWatchTracking();
        unawaited(_recordStarted());
        unawaited(_mayaKeepAwake(true));
        _captureThumbnail();
      }
    });
    try {
      await controller
          .setupDataSource(dataSource)
          .timeout(Duration(seconds: isHls ? 30 : 20));
      await initialized.future.timeout(Duration(seconds: isHls ? 30 : 20));
    } catch (_) {
      showFailure();
    }
  }

  Future<void> _tryDirectPlayback(
    int attempt,
    Uri stream,
    Map<String, String> headers,
  ) async {
    final direct = VideoPlayerController.networkUrl(
      stream,
      httpHeaders: headers,
    );
    _directPlayer = direct;
    bool isActive() =>
        mounted &&
        attempt == _playbackAttempt &&
        identical(_directPlayer, direct);
    void showError() {
      if (!isActive() || _hasError) return;
      unawaited(_mayaKeepAwake(false));
      setState(() {
        _hasError = true;
        _directPlayerReady = false;
      });
      unawaited(_checkStreamFailure(attempt, stream, headers));
    }

    try {
      await direct.initialize().timeout(const Duration(seconds: 30));
      if (!isActive()) return;
      direct.addListener(() {
        if (direct.value.hasError) {
          _decoderHint =
              direct.value.errorDescription ?? 'Device decoder failed';
          showError();
        }
      });
      await direct.play();
      if (!isActive() || _hasError) return;
      setState(() {
        _directPlayerReady = true;
        _isInitialized = true;
      });
      _startWatchTracking();
      _resetControlTimer();
      unawaited(_recordStarted());
      unawaited(_mayaKeepAwake(true));
      unawaited(_captureThumbnail());
    } catch (error) {
      _decoderHint = error.toString();
      showError();
    }
  }

  Widget _buildDirectPlayback(VideoPlayerController controller) =>
      _buildUnifiedPlayback();

  Widget _control(IconData icon, String tooltip, VoidCallback action) =>
      IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: tooltip,
        onPressed: action,
        icon: Icon(icon, color: Colors.white),
      );

  Widget _buildUnifiedPlayback() {
    if (_hasError)
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_streamError, textAlign: TextAlign.center),
            ),
            TextButton(onPressed: _retryVideo, child: const Text('Retry')),
          ],
        ),
      );
    if (!_isInitialized)
      return const ProfessionalLoader(message: 'Preparing playback…');
    return LayoutBuilder(
      builder:
          (context, box) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onScreenTapped,
            onDoubleTapDown: (d) => _onDoubleTap(d, box.maxWidth),
            onDoubleTap: () {},
            onLongPressStart: _screenLocked ? null : (_) => _onLongPressStart(),
            onLongPressEnd: _screenLocked ? null : (_) => _onLongPressEnd(),
            onVerticalDragStart:
                _screenLocked
                    ? null
                    : (d) => _onVerticalDragStart(d, box.maxWidth),
            onVerticalDragUpdate:
                _screenLocked
                    ? null
                    : (d) => _onVerticalDragUpdate(d, box.maxHeight),
            onVerticalDragEnd: _screenLocked ? null : _onVerticalDragEnd,
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                _buildScaledVideo(),
                if (_brightness < 1)
                  IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withOpacity(1 - _brightness),
                    ),
                  ),
                if (_showControls && !_screenLocked && !_isLongPressBoost) ...[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      child: Row(
                        children: [
                          _control(
                            Icons.settings_outlined,
                            'Quality',
                            _showQualityDialog,
                          ),
                          Expanded(
                            child: Text(
                              _selectedQuality,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _showSpeedDialog,
                            child: Text('${_playbackSpeed}x'),
                          ),
                          _control(
                            Icons.lock_open,
                            'Lock controls',
                            () => setState(() => _screenLocked = true),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _control(
                          Icons.replay_10,
                          'Back 10 seconds',
                          () => _seekRelative(-10),
                        ),
                        const SizedBox(width: 18),
                        IconButton(
                          iconSize: 48,
                          onPressed: () => unawaited(_togglePlayback()),
                          icon: Icon(
                            _playing
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 18),
                        _control(
                          Icons.forward_10,
                          'Forward 10 seconds',
                          () => _seekRelative(10),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      color: Colors.black54,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Slider(
                            value:
                                _position.inMilliseconds
                                    .toDouble()
                                    .clamp(
                                      0.0,
                                      math
                                          .max(1, _duration.inMilliseconds)
                                          .toDouble(),
                                    )
                                    .toDouble(),
                            max:
                                math
                                    .max(1, _duration.inMilliseconds)
                                    .toDouble(),
                            onChangeStart: (_) => _controlsTimer?.cancel(),
                            onChanged:
                                (v) => unawaited(
                                  _seekTo(Duration(milliseconds: v.toInt())),
                                ),
                            onChangeEnd: (_) => _resetControlTimer(),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              _control(
                                _volume == 0
                                    ? Icons.volume_off
                                    : Icons.volume_up,
                                'Mute',
                                () {
                                  setState(
                                    () => _volume = _volume == 0 ? 1 : 0,
                                  );
                                  _directPlayer?.setVolume(_volume);
                                  _betterPlayerController?.setVolume(_volume);
                                },
                              ),
                              _control(
                                Icons.aspect_ratio,
                                'Fit / fill',
                                () => setState(() => _isZoomed = !_isZoomed),
                              ),
                              _control(
                                Icons.rotate_right,
                                'Rotate video',
                                () => setState(
                                  () => _quarterTurns = (_quarterTurns + 1) % 4,
                                ),
                              ),
                              _control(
                                _isFullscreen
                                    ? Icons.fullscreen_exit
                                    : Icons.fullscreen,
                                'Fullscreen',
                                _toggleSmartFullscreen,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_screenLocked && _showControls)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: _control(
                      Icons.lock,
                      'Unlock controls',
                      () => setState(() => _screenLocked = false),
                    ),
                  ),
                if (_flashFeedback.isNotEmpty)
                  Center(
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        color: Colors.black87,
                        child: Text(
                          _flashFeedback,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppThemes.kGreen),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionTicker?.cancel();
    if (!MayaAds.scheduledVideoAvailable && _adPlayMs >= 60000 && !_hasError && _recordedPlayback) MayaAds.qualifyVideoExit();
    unawaited(_mayaKeepAwake(false));
    _statsSub?.cancel();
    _likeSub?.cancel();
    _unlikeSub?.cancel();
    _controlsTimer?.cancel();
    _feedbackTimer?.cancel();
    _watchTimer?.cancel();
    _playbackAttempt++;
    _betterPlayerController?.dispose();
    final direct = _directPlayer;
    _directPlayer = null;
    if (direct != null) unawaited(direct.dispose());
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _resetControlTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _playing) setState(() => _showControls = false);
    });
  }

  Future<void> _togglePlayback() async {
    if (_playing) {
      await _directPlayer?.pause();
      await _betterPlayerController?.pause();
    } else {
      if (_duration > Duration.zero && _position >= _duration)
        await _seekTo(Duration.zero);
      await _directPlayer?.play();
      await _betterPlayerController?.play();
    }
    unawaited(_mayaKeepAwake(_playing));
    if (mounted) setState(() => _showControls = true);
    _resetControlTimer();
  }

  Future<void> _seekTo(Duration position) async {
    _lastAdPosition = null;
    final end = _duration;
    final target =
        position < Duration.zero
            ? Duration.zero
            : (end > Duration.zero && position > end ? end : position);
    await _directPlayer?.seekTo(target);
    await _betterPlayerController?.seekTo(target);
  }

  void _setSpeed(double speed) {
    _directPlayer?.setPlaybackSpeed(speed);
    _betterPlayerController?.setSpeed(speed);
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
      _setSpeed(2.0);
    });
    _showFeedback('▶▶ 2x');
  }

  void _onLongPressEnd() {
    if (_isLongPressBoost) {
      _setSpeed(_playbackSpeed);
      setState(() => _isLongPressBoost = false);
      _resetControlTimer();
    }
  }

  void _onDoubleTap(TapDownDetails details, double width) {
    if (_screenLocked) return;
    if (details.localPosition.dx < width * .35) {
      _seekRelative(-10);
    } else if (details.localPosition.dx > width * .65) {
      _seekRelative(10);
    } else {
      unawaited(_togglePlayback());
    }
  }

  void _seekRelative(int seconds) {
    unawaited(_seekTo(_position + Duration(seconds: seconds)));
    _showFeedback('${seconds > 0 ? '+' : ''}${seconds}s');
    _resetControlTimer();
  }

  void _toggleSmartFullscreen() {
    SoundService.playClick();
    Haptic.light();
    setState(() => _isFullscreen = !_isFullscreen);

    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      final isWide = _aspect >= 1.2;
      if (isWide) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
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

  Future<void> _loadCommunity() async {
    try {
      final data =
          _channelVideo
              ? await MayaChannelsApi.request(_channelPostPath)
              : await MayaCommunityApi.request('/$_communityKey');
      if (mounted)
        setState(() {
          _community =
              _channelVideo ? {...data, 'dislikes': data['unlikes']} : data;
          if (_channelVideo) _isSaved = data['saved'] == true;
        });
    } catch (_) {}
  }

  Future<void> _socialReact(int value) async {
    try {
      final next = _community['reaction'] == value ? 0 : value;
      if (_channelVideo) {
        await MayaChannelsApi.request(
          '$_channelPostPath/action',
          method: 'POST',
          body: {'action': 'reaction', 'value': next},
        );
      } else {
        await MayaCommunityApi.request(
          '/$_communityKey/reaction',
          method: 'POST',
          body: {'value': next},
        );
      }
      await _loadCommunity();
    } catch (e) {
      if (mounted) _showFeedback(_channelError(e));
    }
  }

  String _compactCount(Object? input) {
    final count = input is num ? input.toInt() : int.tryParse('$input') ?? 0;
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }

  Widget _playerAction(
    IconData icon,
    String label,
    VoidCallback action, {
    bool active = false,
  }) => Expanded(
    child: TextButton(
      onPressed: action,
      style: TextButton.styleFrom(
        foregroundColor: active ? _mayaMint : _mayaMint.withOpacity(.85),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 2),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _handleLike() async {
    if (_social || _channelVideo) {
      await _socialReact(1);
      return;
    }
    SoundService.playClick();
    Haptic.medium();
    final uid = MayaJaalAccount.cachedUid;
    if (uid == null) return;
    final ok = await SecurityGuard.validateSession();
    if (!ok) {
      _showFeedback('🔒 Session expired');
      return;
    }
    await FirebaseService.toggleLike(
      widget.videoId,
      uid,
      _ownerUid,
      widget.title,
    );
  }

  Future<void> _handleDislike() async {
    if (_social || _channelVideo) {
      await _socialReact(-1);
      return;
    }
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
    if (_channelVideo) {
      try {
        final channel = await MayaChannelsApi.request(
          '/${Uri.encodeComponent(widget.channelId)}',
        );
        if (channel['visibility'] != 'public' || channel['sharing'] != true) {
          if (mounted) _showFeedback('Sharing is disabled for this channel.');
          return;
        }
        await Share.share('${widget.title}\n${widget.sourcePageUrl}');
      } catch (e) {
        if (mounted) _showFeedback(_channelError(e));
      }
      return;
    }
    if (!_social) await FirebaseService.recordShare(widget.videoId);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppThemes.kBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder:
          (c) => Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'SHARE VIDEO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.title,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _shareOption(
                      Icons.link,
                      'Copy Link',
                      AppThemes.kNeonCyan,
                      () async {
                        SoundService.playClick();
                        Haptic.medium();
                        await Clipboard.setData(
                          ClipboardData(text: widget.sourcePageUrl),
                        );
                        if (c.mounted) Navigator.pop(c);
                        _showFeedback('🔗 Link Copied!');
                      },
                    ),
                    _shareOption(Icons.share, 'Share Now', AppThemes.kGreen, () {
                      SoundService.playClick();
                      Haptic.medium();
                      Navigator.pop(c);
                      Share.share(
                        '🎬 Watch "${widget.title}" on MayaJaal:\n${widget.sourcePageUrl}',
                      );
                    }),
                    _shareOption(
                      Icons.send_rounded,
                      'Telegram',
                      const Color(0xFF229ED9),
                      () {
                        SoundService.playClick();
                        Haptic.medium();
                        Navigator.pop(c);
                        Share.share(
                          '🎬 Watch "${widget.title}" on MayaJaal:\n${widget.sourcePageUrl}',
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
    );
  }

  Widget _shareOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: AppThemes.kBorder),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Future<void> _startInAppDownload() async {
    if (_channelVideo) {
      try {
        final post = await MayaChannelsApi.request(_channelPostPath);
        final url = _mediaLink('${post['media'] ?? ''}');
        if (url == null || !mounted) return;
        unawaited(
          MayaDownloads.start(
            FirebaseAuth.instance.currentUser?.uid ?? 'guest',
            url,
            widget.title,
            thumbnail: '${post['thumbnail'] ?? ''}',
          ),
        );
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const MayaDownloadsScreen()),
        );
      } catch (e) {
        if (mounted) _showFeedback(_channelError(e));
      }
      return;
    }
    if (_social) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => MayaSocialMediaScreen(
                source: Uri.parse(widget.sourcePageUrl),
                showDownloads: true,
              ),
        ),
      );
      return;
    }
    final url = _mediaLink(_qualityUrl ?? widget.videoUrl);
    if (url == null || url.path.endsWith('.m3u8')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This source does not provide a downloadable file.'),
        ),
      );
      return;
    }
    unawaited(
      MayaDownloads.start(
        FirebaseAuth.instance.currentUser?.uid ?? 'guest',
        url,
        widget.title,
        thumbnail: widget.thumbnailUrl,
      ),
    );
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MayaDownloadsScreen()));
  }

  Future<void> _toggleSave() async {
    if (_channelVideo) {
      try {
        await MayaChannelsApi.request(
          '$_channelPostPath/action',
          method: 'POST',
          body: {'action': 'save', 'saved': !_isSaved},
        );
        await _loadCommunity();
        if (mounted)
          _showFeedback(
            _isSaved
                ? 'Post saved to Saved channel posts'
                : 'Saved post removed',
          );
      } catch (e) {
        if (mounted) _showFeedback(_channelError(e));
      }
      return;
    }
    SoundService.playClick();
    Haptic.medium();
    final uid = MayaJaalAccount.cachedUid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'saved_videos_v1_$uid';
    final savedStr = prefs.getString(key);
    List<Map<String, dynamic>> savedList = [];
    if (savedStr != null) {
      try {
        savedList = (jsonDecode(savedStr) as List).cast<Map<String, dynamic>>();
      } catch (_) {}
    }

    setState(() => _isSaved = !_isSaved);

    final item = {
      'url': widget.sourcePageUrl,
      'title': widget.title,
      'uploader': widget.uploader,
      'id': widget.videoId,
      'thumbnail': widget.thumbnailUrl,
      'streamUrl': _qualityUrl ?? widget.videoUrl,
      'size': _videoSize,
      'age': _videoAge,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
    };

    if (_isSaved) {
      savedList.removeWhere(
        (saved) =>
            WatchHistory.recordKey(saved) == WatchHistory.recordKey(item),
      );
      savedList.insert(0, item);
      await prefs.setString(key, jsonEncode(savedList));
      prefs.setBool('saved_${uid}_${widget.videoId}', true);
      await WatchHistory.syncSavedRecordCloud(item, true);
    } else {
      savedList.removeWhere(
        (saved) =>
            WatchHistory.recordKey(saved) == WatchHistory.recordKey(item),
      );
      await prefs.setString(key, jsonEncode(savedList));
      prefs.setBool('saved_${uid}_${widget.videoId}', false);
      await WatchHistory.syncSavedRecordCloud(item, false);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSaved ? 'Video Saved to Favorites' : 'Removed from Favorites',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showQualityDialog() {
    final variants = _activeVariants;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppThemes.kCardBg,
      builder:
          (sheet) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheet).size.height * .65,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  const ListTile(
                    title: Text('Playback quality'),
                    subtitle: Text(
                      'Available source formats · device decoding limits apply',
                    ),
                  ),
                  if (variants.isEmpty)
                    const ListTile(
                      leading: Icon(Icons.high_quality),
                      title: Text('Original source'),
                      subtitle: Text(
                        'This source provides one stream. No artificial quality labels.',
                      ),
                    ),
                  for (final variant in variants)
                    ListTile(
                      title: Text(variant.label),
                      subtitle: Text(variant.codec),
                      trailing:
                          variant.label == _selectedQuality
                              ? const Icon(Icons.check, color: AppThemes.kGreen)
                              : null,
                      onTap: () {
                        Navigator.pop(sheet);
                        unawaited(_switchQuality(variant));
                      },
                    ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _switchQuality(MayaPlaybackVariant variant) async {
    if (_qualityChanging ||
        variant.url.toString() == (_qualityUrl ?? widget.videoUrl))
      return;
    final position = _position;
    final wasPlaying = _playing;
    final previous = _qualityUrl;
    final previousLabel = _selectedQuality;
    _qualityChanging = true;
    _qualityUrl = variant.url.toString();
    _selectedQuality = variant.label;
    try {
      await _initVideo();
      // Fallback video_player initialization can finish after BetterPlayer fails.
      for (
        var i = 0;
        i < 160 && mounted && !_isInitialized && !_hasError;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (!mounted) return;
      if (_hasError || !_isInitialized) {
        _qualityUrl = previous;
        _selectedQuality = previousLabel;
        await _initVideo();
        _showFeedback(
          'Quality unavailable on this device; restored previous stream',
        );
      } else {
        _setSpeed(_playbackSpeed);
        await _seekTo(position);
        if (!wasPlaying) {
          await _directPlayer?.pause();
          await _betterPlayerController?.pause();
        }
      }
    } finally {
      _qualityChanging = false;
    }
  }

  void _showSpeedDialog() {
    SoundService.playClick();
    Haptic.light();
    showDialog(
      context: context,
      builder:
          (c) => AlertDialog(
            backgroundColor: AppThemes.kCardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppThemes.kBorder),
            ),
            title: const Text(
              'PLAYBACK SPEED',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  _speeds.map((s) {
                    return RadioListTile<double>(
                      value: s,
                      groupValue: _playbackSpeed,
                      activeColor: AppThemes.kGreen,
                      title: Text(
                        '${s}x',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      onChanged: (val) {
                        if (val != null) {
                          SoundService.playClick();
                          Haptic.selection();
                          setState(() => _playbackSpeed = val);
                          _setSpeed(val);
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
    if (!_isInitialized) return const SizedBox.shrink();
    final size =
        _directPlayer?.value.size ??
        _betterPlayerController?.videoPlayerController?.value.size;
    if (size == null || size.width <= 0 || size.height <= 0)
      return const SizedBox.shrink();
    return RepaintBoundary(
      key: _videoKey,
      child: RotatedBox(
        quarterTurns: _quarterTurns,
        child: SizedBox.expand(
          child: FittedBox(
            fit: _isZoomed ? BoxFit.cover : BoxFit.contain,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child:
                  _directPlayer != null
                      ? VideoPlayer(_directPlayer!)
                      : BetterPlayer(controller: _betterPlayerController!),
            ),
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
      final newVol = (_volumeStart + delta).clamp(0.0, 1.0).toDouble();
      setState(() => _volume = newVol);
      _betterPlayerController?.setVolume(newVol);
      _directPlayer?.setVolume(newVol);
      _showFeedback('🔊 ${(newVol * 100).toInt()}%');
    } else if (_isAdjustingBrightness) {
      final newBright = (_brightnessStart + delta).clamp(0.1, 1.0).toDouble();
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
      onTap: _startInAppDownload,
      child: Container(
        width: 96,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppThemes.kBorder),
        ),
        child: Stack(
          children: [
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.download_rounded,
                    color: AppThemes.kGreen,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Download',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen)
      return WillPopScope(
        onWillPop: () async {
          _toggleSmartFullscreen();
          return false;
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(child: _buildUnifiedPlayback()),
        ),
      );
    return Scaffold(
      backgroundColor: AppThemes.kBg,
      appBar: AppBar(
        title: const MayaBrandTitle(section: 'Player'),
        actions: [
          IconButton(tooltip: 'AI translation trial', icon: const Icon(Icons.translate), onPressed: () => MayaAI.open(context)),
          IconButton(
            onPressed: _shareVideoLink,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * .32,
            width: double.infinity,
            child: _buildUnifiedPlayback(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const MayaAdSlot(),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.uploader,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: AppThemes.kDimGreen,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.visibility_outlined,
                      size: 15,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _compactCount(
                        (_social || _channelVideo)
                            ? _community['views']
                            : _stats['views'],
                      ),
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _social ? 'app views' : tr('views'),
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                if (_videoSize.isNotEmpty || _videoAge.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '$_videoSize  $_videoAge',
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _playerAction(
                      ((_social || _channelVideo)
                              ? _community['reaction'] == 1
                              : _isLiked)
                          ? Icons.thumb_up
                          : Icons.thumb_up_outlined,
                      _compactCount(
                        (_social || _channelVideo)
                            ? _community['likes']
                            : _stats['likes'],
                      ),
                      _handleLike,
                      active:
                          (_social || _channelVideo)
                              ? _community['reaction'] == 1
                              : _isLiked,
                    ),
                    _playerAction(
                      ((_social || _channelVideo)
                              ? _community['reaction'] == -1
                              : _isUnliked)
                          ? Icons.thumb_down
                          : Icons.thumb_down_outlined,
                      _compactCount(
                        (_social || _channelVideo)
                            ? _community['dislikes']
                            : _stats['unlikes'],
                      ),
                      _handleDislike,
                      active:
                          (_social || _channelVideo)
                              ? _community['reaction'] == -1
                              : _isUnliked,
                    ),
                    _playerAction(
                      _isSaved ? Icons.bookmark : Icons.bookmark_outline,
                      tr('save'),
                      _toggleSave,
                      active: _isSaved,
                    ),
                    _playerAction(
                      Icons.download_outlined,
                      tr('download'),
                      _startInAppDownload,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (!_channelVideo)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => showMayaComments(context, _communityKey),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppThemes.kCardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppThemes.kBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: _mayaMint,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tr('comments'),
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: Colors.white54,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  tr('watch_history'),
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final item in _relatedVideos)
                  ListTile(
                    key: ValueKey(WatchHistory.recordKey(item)),
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox(
                      width: 96,
                      height: 54,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: buildMediaThumbnail(
                          _storedVideoThumbnail(item),
                          '${item['title'] ?? 'Video'}',
                          '${item['streamUrl'] ?? ''}',
                          sourceUrl: '${item['url'] ?? ''}',
                          loopPreview: true,
                        ),
                      ),
                    ),
                    title: Text(
                      '${item['title'] ?? 'Video'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${item['uploader'] ?? ''}', maxLines: 1),
                    onTap: () {
                      final source = item['url']?.toString() ?? '';
                      if (source.isNotEmpty)
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _mayaPlaybackEntry(source),
                          ),
                        );
                    },
                  ),
                if (_relatedLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
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
    final thumb = _storedVideoThumbnail(v);
    final streamUrl = v['streamUrl']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          SoundService.playClick();
          Haptic.medium();
          final url = '$kBackendBaseUrl/v/$id';
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => _mayaPlaybackEntry(url)),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 160,
          decoration: BoxDecoration(
            color: AppThemes.kCardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppThemes.kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 82,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(9),
                  ),
                  child: buildMediaThumbnail(
                    thumb,
                    title,
                    streamUrl,
                    isSmall: true,
                    loopPreview: true,
                    sourceUrl: '${v['url'] ?? ''}',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            uploader,
                            style: const TextStyle(
                              color: AppThemes.kDimGreen,
                              fontSize: 9.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.visibility,
                          color: Colors.white38,
                          size: 9,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$views',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 8.5,
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
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white38),
        border: InputBorder.none,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white, fontSize: 15),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(
      icon: const Icon(Icons.clear, color: AppThemes.kGreen, size: 20),
      onPressed: () => query = '',
    ),
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
              const Text(
                'Search users by name or email',
                style: TextStyle(color: Colors.white38, fontSize: 12.5),
              ),
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
            return const Center(
              child: CircularProgressIndicator(color: AppThemes.kGreen),
            );
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    color: Colors.white24,
                    size: 50,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No user found for "$query"',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12.5,
                    ),
                  ),
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
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppThemes.kBorder),
                  ),
                  child:
                      photo.isNotEmpty
                          ? ClipOval(
                            child: Image.network(
                              photo,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (c, e, s) => const Icon(
                                    Icons.person,
                                    color: AppThemes.kGreen,
                                    size: 18,
                                  ),
                            ),
                          )
                          : const Icon(
                            Icons.person,
                            color: AppThemes.kGreen,
                            size: 18,
                          ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  email,
                  style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white24,
                  size: 12,
                ),
                onTap: () {
                  SoundService.playClick();
                  close(context, null);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(channelProfile: u),
                    ),
                  );
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
  String get _channelName =>
      widget.channelProfile['name']?.toString() ?? 'User';
  String get _channelEmail => widget.channelProfile['email']?.toString() ?? '';
  String get _channelPhoto =>
      widget.channelProfile['photoURL']?.toString() ?? '';

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
          content: Text(
            '🔒 Session expired',
            style: TextStyle(color: Colors.orangeAccent),
          ),
        ),
      );
      return;
    }
    final newState = await FirebaseService.toggleSubscription(
      myUid,
      _channelUid,
    );
    if (mounted) {
      setState(() => _isSubscribed = newState);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppThemes.kCardBg,
          content: Text(
            newState ? '✅ Subscribed!' : 'Unsubscribed',
            style: const TextStyle(color: AppThemes.kGreen),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = MayaJaalAccount.cachedUid == _channelUid;

    return Scaffold(
      backgroundColor: AppThemes.kBg,
      appBar: AppBar(title: Text('@${_channelName.split(' ').first}')),
      body:
          _loading
              ? const Center(
                child: CircularProgressIndicator(color: AppThemes.kGreen),
              )
              : Column(
                children: [
                  const SizedBox(height: 18),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppThemes.kBorder, width: 1.5),
                    ),
                    child:
                        _channelPhoto.isNotEmpty
                            ? ClipOval(
                              child: Image.network(
                                _channelPhoto,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (c, e, s) => const Icon(
                                      Icons.person,
                                      size: 36,
                                      color: AppThemes.kGreen,
                                    ),
                              ),
                            )
                            : const Icon(
                              Icons.person,
                              size: 36,
                              color: AppThemes.kGreen,
                            ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _channelName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _channelEmail,
                    style: const TextStyle(
                      color: AppThemes.kDimGreen,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StreamBuilder<int>(
                    stream: FirebaseService.getSubscriberCount(_channelUid),
                    builder: (c, s) {
                      final count = s.data ?? 0;
                      return Text(
                        '$count subscribers',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  if (!isOwnProfile)
                    SizedBox(
                      width: 180,
                      child: ElevatedButton(
                        onPressed: _toggleSub,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isSubscribed ? Colors.white12 : AppThemes.kGreen,
                          foregroundColor:
                              _isSubscribed ? Colors.white : Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          _isSubscribed ? '✓ SUBSCRIBED' : '+ SUBSCRIBE',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ),
                  const Divider(color: Colors.white10, height: 26),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.video_library,
                          color: AppThemes.kGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'VIDEOS (${_videos.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child:
                        _videos.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.video_library_outlined,
                                    color: Colors.white24,
                                    size: 50,
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'No uploads yet',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              itemCount: _videos.length,
                              itemBuilder: (context, i) {
                                final vid = _videos[i];
                                final id = vid['id']?.toString() ?? '';
                                String name = '';
                                String fName =
                                    (vid['filename'] ?? '').toString().trim();
                                String tName =
                                    (vid['title'] ?? '').toString().trim();
                                if (fName.isNotEmpty && fName != 'null') {
                                  name = fName;
                                } else if (tName.isNotEmpty &&
                                    tName != 'null') {
                                  name = tName;
                                } else {
                                  name = 'MayaJaal Video';
                                }
                                final views = vid['views'] ?? 0;
                                final thumb =
                                    vid['thumbnail']?.toString() ?? '';
                                final streamUrl =
                                    id.isNotEmpty
                                        ? '$kBackendBaseUrl/stream/$id'
                                        : '';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: AppThemes.kCardBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppThemes.kBorder,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(7),
                                        border: Border.all(
                                          color: AppThemes.kBorder,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: buildMediaThumbnail(
                                          thumb,
                                          name,
                                          streamUrl,
                                          isSmall: true,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Row(
                                      children: [
                                        const Icon(
                                          Icons.visibility,
                                          color: Colors.white38,
                                          size: 10,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          '$views views',
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 9.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      SoundService.playClick();
                                      Haptic.light();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => StreamPreviewScreen(
                                                targetUrl:
                                                    '$kBackendBaseUrl/v/$id',
                                              ),
                                        ),
                                      );
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
    _rankAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
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
              content: Text(
                '🔒 Session expired. Please login again.',
                style: TextStyle(color: Colors.orangeAccent),
              ),
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
        title: const Text(
          'CREATOR STATS',
          style: TextStyle(
            letterSpacing: 1.2,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
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
      body:
          _loading
              ? const Center(
                child: CircularProgressIndicator(color: AppThemes.kGreen),
              )
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
            Text(
              'NOT LOGGED IN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please login to view creator stats.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
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
              decoration: BoxDecoration(
                color: AppThemes.kCardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppThemes.kBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: AppThemes.kGreen, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LOGGED IN AS',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 8.5,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          MayaJaalAccount.cachedEmail ?? 'N/A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _rankScale,
              builder:
                  (c, child) =>
                      Transform.scale(scale: _rankScale.value, child: child),
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
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppThemes.kBorder),
                      ),
                      child: Center(
                        child: Text(
                          rank['emoji'] as String,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CYBER RANK',
                            style: TextStyle(
                              color: rankColor,
                              fontSize: 8.5,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rank['name'] as String,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (nextRank != null)
                            Text(
                              '${(nextRank['min'] as int) - totalViews} views to ${nextRank['name']}',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 9.5,
                              ),
                            ),
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
              decoration: BoxDecoration(
                color: AppThemes.kCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppThemes.kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL VIEWS',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$totalViews',
                    style: const TextStyle(
                      color: AppThemes.kGreen,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Verified platform views',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const Divider(color: Colors.white10, height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _statChip('👁 Total Views', '$totalViews'),
                      ),
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
              decoration: BoxDecoration(
                color: AppThemes.kCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppThemes.kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: Colors.orangeAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'TIER $_currentTier',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _tierStat('Current Tier', 'Tier $_currentTier'),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _tierStat('Next Boost', '$_nextBoost views'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Keep sharing your videos to unlock higher ranks and recognition across the MayaJaal creator community.',
                    style: TextStyle(color: Colors.white38, fontSize: 9.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'YOUR LINKS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            _links.isEmpty
                ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppThemes.kCardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppThemes.kBorder),
                  ),
                  child: const Center(
                    child: Text(
                      'No links yet. Use the bot to upload videos and start sharing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
                )
                : Column(
                  children:
                      _links.map((link) {
                        final views = (link['views'] ?? 0) as int;
                        final name =
                            (link['filename'] ?? link['originalUrl'] ?? 'link')
                                .toString();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppThemes.kCardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppThemes.kBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppThemes.kBorder),
                                ),
                                child: const Icon(
                                  Icons.play_circle_outline,
                                  color: AppThemes.kGreen,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.visibility,
                                          color: Colors.white38,
                                          size: 10,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          '$views views',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
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
              decoration: BoxDecoration(
                color: AppThemes.kCardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppThemes.kBorder),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppThemes.kGreen,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'INFO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• Views are validated after 10+ seconds of real playback',
                    style: TextStyle(color: Colors.white60, fontSize: 10.5),
                  ),
                  Text(
                    '• Cyber Rank is calculated from cumulative verified views',
                    style: TextStyle(color: Colors.white60, fontSize: 10.5),
                  ),
                  Text(
                    '• 28-day auto lifecycle on all stream links',
                    style: TextStyle(color: Colors.white60, fontSize: 10.5),
                  ),
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
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppThemes.kBorder),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 8.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tierStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppThemes.kBorder),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 8.5),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class MayaDownload extends ChangeNotifier {
  MayaDownload(this.uid, this.id, this.title, this.thumbnail);

  final String thumbnail;

  final String uid;
  final String id;
  final String title;
  double? progress;
  bool failed = false;

  void update(double? value, {bool failed = false}) {
    progress = value;
    this.failed = failed;
    notifyListeners();
  }
}

class MayaDownloadHistory {
  static final _syncing = <String>{};

  static DatabaseReference ref(String uid) =>
      FirebaseDatabase.instance.ref('users/$uid/downloadHistory');

  static Future<void> record(
    String uid,
    String id,
    Map<String, Object?>? item,
  ) async {
    if (uid == 'guest') return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'downloadSync:$uid:$id';
    await prefs.setString(key, jsonEncode(item));
    unawaited(sync(uid));
  }

  static Future<void> sync(String uid) async {
    if (FirebaseAuth.instance.currentUser?.uid != uid || !_syncing.add(uid))
      return;
    final prefix = 'downloadSync:$uid:';
    try {
      final prefs = await SharedPreferences.getInstance();
      while (FirebaseAuth.instance.currentUser?.uid == uid) {
        final keys =
            prefs.getKeys().where((key) => key.startsWith(prefix)).toList();
        if (keys.isEmpty) return;
        for (final key in keys) {
          if (FirebaseAuth.instance.currentUser?.uid != uid) return;
          final raw = prefs.getString(key);
          if (raw == null) continue;
          final entry = ref(uid).child(key.substring(prefix.length));
          final data = jsonDecode(raw);
          if (data == null) {
            await entry.remove().timeout(const Duration(seconds: 12));
          } else {
            await entry.set(data).timeout(const Duration(seconds: 12));
          }
          if (prefs.getString(key) == raw) await prefs.remove(key);
        }
      }
    } catch (_) {
      // Retain pending changes for the next sync.
    } finally {
      _syncing.remove(uid);
    }
  }
}

class MayaPublicDownloads {
  static const _channel = MethodChannel('mayajaal/downloads');
  static final _saving = <String>{};

  static Future<void> save(File file, String name, {String? mime}) async {
    if (!Platform.isAndroid) return;
    if (!_saving.add(file.path)) {
      throw StateError('This file is already being saved.');
    }
    try {
      final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
      if (sdk < 29 && !await Permission.storage.request().isGranted) {
        throw StateError('Storage permission is needed on this Android version.');
      }
      final location = await _channel.invokeMethod<String>('publish', {
        'path': file.path,
        'name': name,
        if (mime != null && mime.isNotEmpty) 'mime': mime,
      });
      if (location == null || location.isEmpty) {
        throw StateError('The phone did not confirm the saved file.');
      }
    } finally {
      _saving.remove(file.path);
    }
  }
}

class MayaDownloads {
  static final jobs = ValueNotifier<List<MayaDownload>>([]);

  static Future<Directory> directory(String uid) async {
    final root = await getApplicationSupportDirectory();
    final folder = Uri.encodeComponent(uid);
    return Directory('${root.path}/downloads/$folder').create(recursive: true);
  }

  static Future<String> _cachePoster(String thumbnail) async {
    if (!thumbnail.startsWith('http')) return thumbnail;
    try {
      final response = await http
          .get(Uri.parse(thumbnail))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 &&
          response.bodyBytes.isNotEmpty &&
          response.bodyBytes.length < 600000 &&
          (response.headers['content-type'] ?? '').startsWith('image/')) {
        return base64Encode(response.bodyBytes);
      }
    } catch (_) {}
    return thumbnail;
  }

  static Future<void> start(
    String uid,
    Uri source,
    String title, {
    String thumbnail = '',
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    // Preserve Hindi and other Unicode titles; remove path/control characters.
    final safeTitle = title.replaceAll(RegExp(r'[\x00-\x1f\x7f/\\:*?"<>|]'), '_').trim();
    final cleaned = safeTitle.replaceAll(RegExp(r'^[. ]+|[. ]+$'), '');
    final name = cleaned.isEmpty
        ? 'Download'
        : String.fromCharCodes(cleaned.runes.take(52));
    final poster = _cachePoster(thumbnail);
    final job = MayaDownload(uid, id, name, thumbnail);
    jobs.value = [...jobs.value, job];
    final client =
        HttpClient()..connectionTimeout = const Duration(seconds: 20);
    File? partial;
    IOSink? sink;

    try {
      final folder = await directory(uid);
      partial = File('${folder.path}/$id.part');
      final request = await client.getUrl(source);
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final mime = response.headers.contentType?.mimeType ?? '';
      final extension =
          _fileTypes[mime] ??
          (mime == 'application/octet-stream' || mime == 'binary/octet-stream'
              ? _fileExtension(source) ?? _fileExtension(Uri(path: name))
              : null);
      if (response.statusCode != HttpStatus.ok ||
          extension == null ||
          source.path.toLowerCase().endsWith('.m3u8')) {
        throw const FormatException(
          'This link does not return a supported file.',
        );
      }
      final filename =
          name.toLowerCase().endsWith(extension) ? name : '$name$extension';
      sink = partial.openWrite();
      var received = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        sink.add(chunk);
        received += chunk.length;
        if (response.contentLength > 0) {
          job.update(
            (received / response.contentLength).clamp(0.0, 1.0).toDouble(),
          );
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (received == 0 ||
          (response.contentLength >= 0 && received != response.contentLength)) {
        throw const FormatException('Incomplete download.');
      }
      final completed = await partial.rename('${folder.path}/${id}_$filename');
      // Publish only a fully received file. A failed public export must not
      // destroy the completed private download or its offline playback.
      if (Platform.isAndroid) {
        try {
          await MayaPublicDownloads.save(completed, filename, mime: mime);
          if (FirebaseAuth.instance.currentUser?.uid == uid) {
            final context = navigatorKey.currentContext;
            if (context != null && context.mounted) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                const SnackBar(content: Text('Downloaded to phone: Download/MayaJaal')),
              );
            }
          }
        } catch (_) {
          if (FirebaseAuth.instance.currentUser?.uid == uid) {
            final context = navigatorKey.currentContext;
            if (context != null && context.mounted) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                const SnackBar(content: Text(
                  'Saved inside MayaJaal. Use Save to phone in Completed to retry public storage.',
                )),
              );
            }
          }
        }
      }
      // Private, per-account poster metadata survives restarts and cloud sync.
      final prefs = await SharedPreferences.getInstance();
      final savedPoster = await poster;
      await prefs.setString('downloadPoster:$uid:$id', savedPoster);
      dismiss(job);
      await MayaDownloadHistory.record(uid, id, {
        'name': filename,
        'thumbnail': savedPoster,
        'size': received,
        'completedAt': DateTime.now().millisecondsSinceEpoch,
      }).catchError((Object _) {});
    } catch (_) {
      job.update(null, failed: true);
      try {
        await sink?.close();
        if (partial != null && await partial.exists()) await partial.delete();
      } catch (_) {}
    } finally {
      client.close(force: true);
    }
  }

  static void dismiss(MayaDownload job) {
    jobs.value = jobs.value.where((item) => item != job).toList();
  }

  static Future<List<File>> files(String uid) async {
    final folder = await directory(uid);
    final items =
        await folder
            .list()
            .where((entry) => entry is File && !entry.path.endsWith('.part'))
            .cast<File>()
            .toList();
    return items..sort((a, b) => b.path.compareTo(a.path));
  }
}

class MayaDownloadsScreen extends StatefulWidget {
  const MayaDownloadsScreen({super.key});

  @override
  State<MayaDownloadsScreen> createState() => _MayaDownloadsScreenState();
}

class _MayaDownloadsScreenState extends State<MayaDownloadsScreen> {
  int _refresh = 0;
  Future<List<File>>? _files;
  Timer? _historyRetry;

  @override
  void initState() {
    super.initState();
    _retryHistory();
    _historyRetry = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _retryHistory(),
    );
  }

  void _retryHistory() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) unawaited(MayaDownloadHistory.sync(uid));
  }

  @override
  void dispose() {
    _historyRetry?.cancel();
    super.dispose();
  }

  Future<void> _saveToPhone(File file, String name) async {
    try {
      await MayaPublicDownloads.save(file, name);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to phone: Download/MayaJaal')),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save to phone. Check storage space and permissions, then retry.')),
      );
    }
  }

  Future<void> _delete(File file, String name, String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete MayaJaal copy?'),
            content: Text('$name\n\nA copy saved to your phone Downloads will remain there.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirm != true || !mounted) return;
    try {
      await file.delete();
      final id = file.uri.pathSegments.last.split('_').first;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('downloadPoster:$uid:$id');
      await MayaDownloadHistory.record(uid, id, null);
      if (mounted)
        setState(() {
          _refresh++;
          _files = null;
        });
    } on FileSystemException {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete this download.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    _files ??= MayaDownloads.files(uid);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppThemes.kBg,
        appBar: AppBar(
          title: MayaSectionTitle(tr('downloads'), Icons.download_rounded),
          bottom: const TabBar(
            tabs: [Tab(text: 'Downloading'), Tab(text: 'Completed')],
          ),
        ),
        body: ValueListenableBuilder<List<MayaDownload>>(
          valueListenable: MayaDownloads.jobs,
          builder: (context, jobs, _) {
            final current = jobs.where((job) => job.uid == uid).toList();
            // Refresh once per job-list mutation, not per incoming byte chunk.
            _files = MayaDownloads.files(uid);
            return TabBarView(
              children: [
                if (current.isEmpty)
                  const Center(child: Text('No active downloads.'))
                else
                  ListView(
                    children:
                        current
                            .map(
                              (job) => ListenableBuilder(
                                key: ValueKey(job.id),
                                listenable: job,
                                builder:
                                    (context, _) => ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 10,
                                          ),
                                      leading: SizedBox(
                                        width: 96,
                                        height: 60,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: _MayaPoster(
                                            thumb: job.thumbnail,
                                            title: job.title,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        job.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Roboto',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      subtitle:
                                          job.failed
                                              ? const Text(
                                                'Download failed. Try again from the player.',
                                              )
                                              : Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const SizedBox(height: 8),
                                                  LinearProgressIndicator(
                                                    value: job.progress,
                                                    color: _mayaMint,
                                                  ),
                                                  const SizedBox(height: 5),
                                                  Text(
                                                    job.progress == null
                                                        ? 'Downloading…'
                                                        : '${(job.progress! * 100).toStringAsFixed(0)}% · Downloading',
                                                    style: const TextStyle(
                                                      fontFamily: 'Roboto',
                                                      fontSize: 12,
                                                      color: _mayaMint,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      trailing:
                                          job.failed
                                              ? IconButton(
                                                tooltip: 'Dismiss',
                                                icon: const Icon(Icons.close),
                                                onPressed:
                                                    () => MayaDownloads.dismiss(
                                                      job,
                                                    ),
                                              )
                                              : null,
                                    ),
                              ),
                            )
                            .toList(),
                  ),
                FutureBuilder<List<File>>(
                  key: ValueKey(_refresh),
                  future: _files,
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return const Center(
                        child: Text('Could not load downloads.'),
                      );
                    final files = snapshot.data;
                    if (files == null)
                      return const Center(child: CircularProgressIndicator());
                    if (files.isEmpty)
                      return const Center(
                        child: Text('No completed downloads.'),
                      );
                    return ListView(
                      children:
                          files.map((file) {
                            final filename = file.uri.pathSegments.last;
                            final name = filename.substring(
                              filename.indexOf('_') + 1,
                            );
                            return ListTile(
                              key: ValueKey(file.path),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              leading: SizedBox(
                                width: 96,
                                height: 60,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: _MayaDownloadPoster(
                                    file: file,
                                    name: name,
                                    uid: uid,
                                  ),
                                ),
                              ),
                              title: Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: const Text(
                                'Completed · Tap to open',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 12,
                                  color: _mayaMint,
                                ),
                              ),
                              onTap:
                                  () =>
                                      _openDownloadedFile(context, file, name),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (Platform.isAndroid)
                                    IconButton(
                                      tooltip: 'Save to phone Downloads',
                                      icon: const Icon(Icons.save_alt_rounded),
                                      onPressed: () => _saveToPhone(file, name),
                                    ),
                                  IconButton(
                                    tooltip: 'Delete MayaJaal copy',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _delete(file, name, uid),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MayaDownloadPoster extends StatefulWidget {
  const _MayaDownloadPoster({
    required this.file,
    required this.name,
    required this.uid,
  });
  final File file;
  final String name, uid;
  @override
  State<_MayaDownloadPoster> createState() => _MayaDownloadPosterState();
}

class _MayaDownloadPosterState extends State<_MayaDownloadPoster> {
  String _poster = '';
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _MayaDownloadPoster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path ||
        oldWidget.uid != widget.uid) {
      _poster = '';
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final path = widget.file.path;
    final uid = widget.uid;
    final id = widget.file.uri.pathSegments.last.split('_').first;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('downloadPoster:$uid:$id') ?? '';
    if (mounted && path == widget.file.path && uid == widget.uid)
      setState(() => _poster = value);
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.file.path.toLowerCase();
    final video = const ['.mp4', '.webm', '.mkv', '.mov'].any(ext.endsWith);
    if (video)
      return VideoLoopThumbnail(
        key: ValueKey(widget.file.path),
        videoUrl: widget.file.path,
        title: widget.name,
        fallbackThumb: _poster,
        onFrameCaptured: (frame) async {
          if (!mounted || _poster.isNotEmpty) return;
          final id = widget.file.uri.pathSegments.last.split('_').first;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('downloadPoster:${widget.uid}:$id', frame);
          if (mounted) setState(() => _poster = frame);
        },
      );
    if (const ['.jpg', '.png', '.webp', '.gif'].any(ext.endsWith)) {
      return Image.file(
        widget.file,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder:
            (_, __, ___) => _MayaPoster(thumb: _poster, title: widget.name),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _MayaPoster(thumb: _poster, title: widget.name),
        const Center(child: Icon(Icons.headphones_rounded, color: _mayaMint)),
      ],
    );
  }
}

class MayaOfflineVideo extends StatefulWidget {
  const MayaOfflineVideo({super.key, required this.file, required this.name});
  final File file;
  final String name;

  @override
  State<MayaOfflineVideo> createState() => _MayaOfflineVideoState();
}

class _MayaOfflineVideoState extends State<MayaOfflineVideo> {
  late final VideoPlayerController controller;
  late final Future<void> ready;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.file(widget.file);
    ready = controller.initialize().then((_) async {
      await controller.play();
      await WatchHistory.recordPlayback({
        'id': 'offline_${crypto.sha256.convert(utf8.encode(widget.file.path))}',
        'url': widget.file.uri.toString(),
        'streamUrl': widget.file.path,
        'title': widget.name,
        'uploader': 'On this device',
        'time': DateTime.now().toIso8601String(),
      });
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: FutureBuilder<void>(
        future: ready,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(child: Text('This video could not be opened.'));
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
                VideoProgressIndicator(controller, allowScrubbing: true),
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller,
                  builder:
                      (context, value, _) => IconButton(
                        tooltip: value.isPlaying ? 'Pause' : 'Play',
                        icon: Icon(
                          value.isPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                        onPressed:
                            () =>
                                value.isPlaying
                                    ? controller.pause()
                                    : controller.play(),
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

const _shareChannel = MethodChannel('mayajaal/share');

Uri? _mediaLink(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty)
    return null;
  return uri;
}

bool _isSocialLink(String value) {
  final host = _mediaLink(value)?.host;
  return host != null &&
      const [
        'youtube.com',
        'youtu.be',
        'instagram.com',
        'facebook.com',
        'fb.watch',
      ].any((domain) => host == domain || host.endsWith('.$domain'));
}

class MayaMediaOption {
  final String label;
  final Uri? download;
  final Uri? prepare;
  final String kind;
  final String detail;
  const MayaMediaOption(
    this.label, {
    this.download,
    this.prepare,
    this.kind = 'video',
    this.detail = '',
  });
}

class MayaResolvedMedia {
  final String title;
  final String thumbnail;
  final String uploader;
  final String kind;
  final String duration;
  final Uri? stream;
  final List<MayaPlaybackVariant> variants;
  final List<MayaMediaOption> downloads;
  const MayaResolvedMedia({
    required this.title,
    this.thumbnail = '',
    this.uploader = '',
    this.kind = 'video',
    this.duration = '',
    this.stream,
    this.variants = const [],
    this.downloads = const [],
  });

  static const endpoint = String.fromEnvironment(
    'MAYAJAAL_SOCIAL_RESOLVER',
    defaultValue: '$kBackendBaseUrl/social/resolve',
  );
  static final _pending = <String, Future<MayaResolvedMedia>>{};
  static final _until = <String, DateTime>{};
  static Future<MayaResolvedMedia> load(Uri source, {bool force = false}) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final key = '$uid:${MayaCommunityApi.videoKey('', source.toString())}';
    final now = DateTime.now();
    if (!force &&
        _pending.containsKey(key) &&
        (_until[key]?.isAfter(now) ?? false))
      return _pending[key]!;
    if (_pending.length >= 40) {
      final oldest = _pending.keys.first;
      _pending.remove(oldest);
      _until.remove(oldest);
    }
    late final Future<MayaResolvedMedia> future;
    future = _loadNetwork(source)
        .then((media) {
          unawaited(
            MayaPosterCache.remember(source.toString(), media.thumbnail),
          );
          return media;
        })
        .catchError((Object error, StackTrace stack) {
          if (identical(_pending[key], future)) {
            _pending.remove(key);
            _until.remove(key);
          }
          Error.throwWithStackTrace(error, stack);
        });
    _pending[key] = future;
    _until[key] = now.add(const Duration(seconds: 90));
    return future;
  }

  static Future<MayaResolvedMedia> _loadNetwork(Uri source) async {
    final api = _mediaLink(endpoint);
    if (api == null)
      throw const HttpException(
        'Social resolver is not configured for this build.',
      );
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const HttpException('Sign in to open this media.');
    var token = await user.getIdToken();
    Future<http.Response> request() => http
        .post(
          api,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'url': source.toString()}),
        )
        .timeout(const Duration(seconds: 90));
    var response = await request();
    if (response.statusCode == 401) {
      token = await user.getIdToken(true);
      response = await request();
    }
    if (response.statusCode != 200) {
      String message = 'Media service HTTP ${response.statusCode}';
      try {
        final error = jsonDecode(response.body);
        if (error is Map && error['detail'] is String)
          message += ': ${error['detail']}';
      } catch (_) {}
      throw HttpException(message);
    }
    final raw = jsonDecode(response.body);
    if (raw is! Map) throw const FormatException('Invalid media response');
    final stream = _mediaLink('${raw['stream_url'] ?? raw['streamUrl'] ?? ''}');
    final variants = <MayaPlaybackVariant>[];
    final downloads = <MayaMediaOption>[];
    for (final row
        in raw['formats'] is List ? raw['formats'] as List : const []) {
      if (row is! Map) continue;
      final url = _mediaLink('${row['stream_url'] ?? ''}');
      final label = '${row['label'] ?? 'Original'}';
      if (url != null)
        variants.add(
          MayaPlaybackVariant(label, url, codec: '${row['codec'] ?? ''}'),
        );
      final download = _mediaLink('${row['download_url'] ?? ''}');
      final prepare = _mediaLink('${row['prepare_url'] ?? ''}');
      if (download != null || prepare != null)
        downloads.add(
          MayaMediaOption(
            label,
            download: download,
            prepare: prepare,
            kind: '${row['kind'] ?? 'video'}',
            detail: '${row['detail'] ?? row['codec'] ?? ''}',
          ),
        );
    }
    if (variants.isEmpty && stream != null)
      variants.add(MayaPlaybackVariant('Original', stream));
    if (downloads.isEmpty && stream != null && !stream.path.endsWith('.m3u8')) {
      downloads.add(MayaMediaOption('Original', download: stream));
    }
    return MayaResolvedMedia(
      title: '${raw['title'] ?? source.host}',
      thumbnail: '${raw['thumbnail'] ?? ''}',
      uploader: '${raw['uploader'] ?? source.host}',
      kind: '${raw['kind'] ?? 'video'}',
      duration: '${raw['duration_label'] ?? ''}',
      stream: stream,
      variants: variants,
      downloads: downloads,
    );
  }
}

class MayaSocialMediaScreen extends StatefulWidget {
  const MayaSocialMediaScreen({
    super.key,
    required this.source,
    this.showDownloads = false,
  });
  final Uri source;
  final bool showDownloads;
  @override
  State<MayaSocialMediaScreen> createState() => _MayaSocialMediaScreenState();
}

class _MayaSocialMediaScreenState extends State<MayaSocialMediaScreen> {
  late Future<MayaResolvedMedia> _media = _load();
  bool _opening = false;
  bool _preparing = false;
  int _downloadGeneration = 0;
  bool _downloadSheetShown = false;
  String _downloadMessage = '';

  String get _platform {
    final host = widget.source.host;
    if (host.contains('instagram')) return 'Instagram';
    if (host.contains('youtu')) return 'YouTube';
    if (host.contains('facebook') || host == 'fb.watch') return 'Facebook';
    return 'File';
  }

  Future<MayaResolvedMedia> _load() async {
    if (_isSocialLink(widget.source.toString()))
      return MayaResolvedMedia.load(widget.source);
    final ext = _fileExtension(widget.source);
    final image = const ['.jpg', '.png', '.webp', '.gif'].contains(ext);
    final video = const ['.mp4', '.webm', '.mkv', '.mov'].contains(ext);
    return MayaResolvedMedia(
      title:
          widget.source.pathSegments.isEmpty
              ? 'Original file'
              : widget.source.pathSegments.last,
      thumbnail: image ? widget.source.toString() : '',
      kind: image ? 'image' : (video ? 'video' : 'file'),
      stream: video ? widget.source : null,
      variants: video ? [MayaPlaybackVariant('Original', widget.source)] : [],
      downloads: [
        MayaMediaOption(
          'Original file',
          download: widget.source,
          kind: image ? 'image' : (video ? 'video' : 'file'),
        ),
      ],
    );
  }

  String _error(Object? error) =>
      error is HttpException
          ? error.message
          : error is TimeoutException
          ? 'The source took too long. Please retry.'
          : 'Could not load this media. Please retry.';

  Future<void> _play(MayaResolvedMedia media) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      if (_isSocialLink(widget.source.toString())) {
        media = await MayaResolvedMedia.load(widget.source);
        if (!mounted) return;
        setState(() => _media = Future<MayaResolvedMedia>.value(media));
      }
      if (media.kind == 'image') {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => Scaffold(
                  appBar: AppBar(title: Text(media.title)),
                  body: Center(
                    child: InteractiveViewer(
                      child: Image.network(
                        media.thumbnail,
                        errorBuilder:
                            (_, __, ___) => const Text('Image unavailable'),
                      ),
                    ),
                  ),
                ),
          ),
        );
      } else if (media.stream != null) {
        // Social playback goes directly to the player. No monetized countdown route.
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => NativeVideoPlayerScreen(
                  videoUrl: media.stream.toString(),
                  title: media.title,
                  uploader: media.uploader,
                  sourcePageUrl: widget.source.toString(),
                  thumbnailUrl: media.thumbnail,
                  videoId: MayaCommunityApi.videoKey(
                    '',
                    widget.source.toString(),
                  ).replaceFirst('external_', ''),
                  variants: media.variants,
                ),
          ),
        );
        if (mounted) unawaited(MayaAds.afterVideo(context));
      } else {
        await launchUrl(widget.source, mode: LaunchMode.externalApplication);
      }
    } catch (error) {
      if (mounted) _channelNotice(context, error);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _chooseDownload(MayaResolvedMedia media) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppThemes.kCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (sheet) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheet).size.height * .75,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(18),
                children: [
                  const Text(
                    'Download quality',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Original source formats. High resolutions and audio conversion may need preparation.',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.white60,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (media.downloads.isEmpty)
                    const Text(
                      'This source did not provide a downloadable file.',
                    ),
                  for (final option in media.downloads)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        option.kind == 'audio'
                            ? Icons.music_note
                            : option.kind == 'image'
                            ? Icons.image_outlined
                            : Icons.high_quality,
                        color: AppThemes.kGreen,
                      ),
                      title: Text(
                        option.label,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle:
                          option.detail.isEmpty
                              ? null
                              : Text(
                                option.detail,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 12,
                                ),
                              ),
                      trailing: const Icon(Icons.download_outlined),
                      onTap:
                          _preparing
                              ? null
                              : () {
                                Navigator.pop(sheet);
                                unawaited(_download(media, option));
                              },
                    ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _download(
    MayaResolvedMedia media,
    MayaMediaOption option,
  ) async {
    final generation = ++_downloadGeneration;
    setState(() {
      _preparing = true;
      _downloadMessage = 'Preparing ${option.label}…';
    });
    try {
      Uri? url = option.download;
      if (option.prepare != null) {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        final response = await http
            .post(option.prepare!, headers: {'Authorization': 'Bearer $token'})
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200)
          throw HttpException('Preparation HTTP ${response.statusCode}');
        var job = jsonDecode(response.body) as Map;
        final deadline = DateTime.now().add(const Duration(minutes: 30));
        while (job['status'] != 'ready') {
          if (!mounted || generation != _downloadGeneration) return;
          if (job['status'] == 'failed')
            throw HttpException('${job['error'] ?? 'File preparation failed'}');
          if (DateTime.now().isAfter(deadline))
            throw const HttpException(
              'Preparation timed out. Try a smaller quality.',
            );
          final status = _mediaLink('${job['status_url'] ?? ''}');
          if (status == null)
            throw const FormatException('Invalid preparation response');
          await Future<void>.delayed(const Duration(seconds: 2));
          final poll = await http
              .get(status)
              .timeout(const Duration(seconds: 15));
          if (poll.statusCode != 200)
            throw HttpException('Preparation HTTP ${poll.statusCode}');
          job = jsonDecode(poll.body) as Map;
          if (mounted)
            setState(
              () =>
                  _downloadMessage =
                      'Preparing ${option.label} · ${job['status'] ?? 'working'}',
            );
        }
        url = _mediaLink('${job['download_url'] ?? ''}');
      }
      if (url == null || !mounted || generation != _downloadGeneration) return;
      unawaited(
        MayaDownloads.start(
          FirebaseAuth.instance.currentUser?.uid ?? 'guest',
          url,
          '${media.title} ${option.label}',
          thumbnail: media.thumbnail,
        ),
      );
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const MayaDownloadsScreen()));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_error(error))));
    } finally {
      if (mounted && generation == _downloadGeneration)
        setState(() => _preparing = false);
    }
  }

  @override
  void dispose() {
    _downloadGeneration++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
        primary: _mayaMint,
        onPrimary: const Color(0xFF10271B),
      ),
      textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Roboto'),
    ),
    child: Scaffold(
      backgroundColor: AppThemes.kBg,
      appBar: AppBar(
        title: MayaSectionTitle(
          '$_platform Preview',
          Icons.play_circle_outline_rounded,
        ),
      ),
      body: FutureBuilder<MayaResolvedMedia>(
        future: _media,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError)
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 48,
                        color: AppThemes.kGreen,
                      ),
                      const SizedBox(height: 16),
                      Text(_error(snapshot.error), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => setState(() => _media = _load()),
                        child: const Text('Retry'),
                      ),
                      TextButton.icon(
                        onPressed:
                            () => launchUrl(
                              widget.source,
                              mode: LaunchMode.externalApplication,
                            ),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open original post'),
                      ),
                    ],
                  ),
                ),
              );
            final yt =
                widget.source.host.contains('youtu')
                    ? (widget.source.host == 'youtu.be'
                        ? (widget.source.pathSegments.isEmpty
                            ? null
                            : widget.source.pathSegments.first)
                        : widget.source.queryParameters['v'])
                    : null;
            final instant =
                yt != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(yt)
                    ? 'https://i.ytimg.com/vi/$yt/hqdefault.jpg'
                    : '';
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: buildMediaThumbnail(
                      instant,
                      'Loading preview',
                      '',
                      sourceUrl: widget.source.toString(),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const LinearProgressIndicator(),
                const SizedBox(height: 14),
                const Text(
                  'Getting available video qualities…',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'The original source may take a moment to respond.',
                  style: TextStyle(fontFamily: 'Roboto', color: Colors.white54),
                ),
              ],
            );
          }
          final media = snapshot.data!;
          if (widget.showDownloads && !_downloadSheetShown) {
            _downloadSheetShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _chooseDownload(media);
            });
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      buildMediaThumbnail(
                        media.thumbnail,
                        media.title,
                        '',
                        sourceUrl: widget.source.toString(),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        bottom: 12,
                        child: Text(
                          '$_platform${media.duration.isEmpty ? '' : ' · ${media.duration}'}',
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (media.kind == 'video')
                        Center(
                          child: IconButton.filled(
                            iconSize: 42,
                            onPressed: _opening ? null : () => _play(media),
                            icon: const Icon(Icons.play_arrow_rounded),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                media.title,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                media.uploader,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _opening ? null : () => _play(media),
                      icon: Icon(
                        media.kind == 'video'
                            ? Icons.play_arrow_rounded
                            : Icons.image_outlined,
                      ),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          _opening
                              ? 'Opening…'
                              : media.kind == 'video'
                              ? tr('play')
                              : 'View',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _preparing ? null : () => _chooseDownload(media),
                      icon: const Icon(Icons.download_rounded),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(tr('download')),
                      ),
                    ),
                  ),
                ],
              ),
              if (_preparing) ...[
                const SizedBox(height: 18),
                const LinearProgressIndicator(),
                const SizedBox(height: 10),
                Text(_downloadMessage),
                TextButton(
                  onPressed: () {
                    _downloadGeneration++;
                    setState(() => _preparing = false);
                  },
                  child: const Text('Stop waiting'),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                '${media.variants.length} playback quality options · ${media.downloads.length} download options',
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
              TextButton.icon(
                onPressed:
                    () => launchUrl(
                      widget.source,
                      mode: LaunchMode.externalApplication,
                    ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open original post'),
              ),
            ],
          );
        },
      ),
    ),
  );
}

const _fileTypes = {
  'audio/mpeg': '.mp3',
  'audio/mp4': '.m4a',
  'audio/webm': '.webm',
  'video/mp4': '.mp4',
  'video/webm': '.webm',
  'video/x-matroska': '.mkv',
  'video/quicktime': '.mov',
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/gif': '.gif',
  'application/pdf': '.pdf',
  'text/plain': '.txt',
  'text/csv': '.csv',
  'application/zip': '.zip',
  'application/msword': '.doc',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      '.docx',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': '.xlsx',
};

String? _fileExtension(Uri url) {
  final path = url.path.toLowerCase();
  if (path.endsWith('.jpeg')) return '.jpg';
  for (final extension in _fileTypes.values) {
    if (path.endsWith(extension)) return extension;
  }
  return null;
}

Future<void> _openDownloadedFile(
  BuildContext context,
  File file,
  String name,
) async {
  final type = _fileExtension(file.uri);
  if (const ['.mp4', '.webm', '.mkv', '.mov'].contains(type)) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MayaOfflineVideo(file: file, name: name),
      ),
    );
  } else if (const ['.jpg', '.png', '.webp', '.gif'].contains(type)) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => Scaffold(
              appBar: AppBar(title: Text(name)),
              body: Center(child: InteractiveViewer(child: Image.file(file))),
            ),
      ),
    );
  } else {
    final result = await OpenFilex.open(file.path);
    if (context.mounted && result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No compatible app could open this file.'),
        ),
      );
    }
  }
}

class MayaDeleteAccountDialog extends StatefulWidget {
  const MayaDeleteAccountDialog({super.key});

  @override
  State<MayaDeleteAccountDialog> createState() =>
      _MayaDeleteAccountDialogState();
}

class _MayaDeleteAccountDialogState extends State<MayaDeleteAccountDialog> {
  bool _confirmed = false;
  bool _deleting = false;
  String? _error;

  Future<void> _delete() async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await MayaJaalAccount.deleteAccount();
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (error) {
      _showError(
        error.code == 'requires-recent-login'
            ? 'Sign in again, then retry account deletion.'
            : 'Could not delete your account. Please try again.',
      );
    } catch (_) {
      _showError('Could not delete your account. Please try again.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _deleting = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_deleting,
      child: AlertDialog(
        backgroundColor: AppThemes.kCardBg,
        title: const Text('Delete your account?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This permanently deletes your MayaJaal account and its associated data. You cannot undo this.',
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('I understand this is permanent.'),
                value: _confirmed,
                onChanged:
                    _deleting
                        ? null
                        : (value) => setState(() => _confirmed = value == true),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: AppThemes.kRed)),
              if (_deleting) const LinearProgressIndicator(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed:
                _deleting ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppThemes.kRed,
              foregroundColor: Colors.black,
            ),
            onPressed: _confirmed && !_deleting ? _delete : null,
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
  }
}

class _MayaChannelUploadDialog extends StatefulWidget {
  const _MayaChannelUploadDialog({
    required this.endpoint,
    required this.user,
    required this.channelId,
    required this.path,
    required this.filename,
    required this.avatar,
  });
  final Uri endpoint;
  final User user;
  final String channelId;
  final String path;
  final String filename;
  final bool avatar;

  @override
  State<_MayaChannelUploadDialog> createState() =>
      _MayaChannelUploadDialogState();
}

class _MayaChannelUploadDialogState extends State<_MayaChannelUploadDialog> {
  late final Future<String> _result;

  @override
  void initState() {
    super.initState();
    _result = _send();
  }

  Future<String> _send() async {
    final client = http.Client();
    try {
      final token = await widget.user.getIdToken();
      if (token == null) throw StateError('Sign-in expired');
      final request =
          http.MultipartRequest('POST', widget.endpoint)
            ..followRedirects = false
            ..headers['Authorization'] = 'Bearer $token'
            ..fields['channelId'] = widget.channelId
            ..fields['purpose'] = widget.avatar ? 'avatar' : 'post'
            ..files.add(
              await http.MultipartFile.fromPath(
                'file',
                widget.path,
                filename: widget.filename,
              ),
            );
      final response = await client
          .send(request)
          .timeout(const Duration(minutes: 3));
      final body = await response.stream.bytesToString().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode == 413)
        return 'This file is too large to upload.';
      if (response.statusCode == 422)
        return 'This file did not pass the content review.';
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return 'Could not upload this file. Please try again.';
      }
      final data = jsonDecode(body);
      if (data is! Map) return 'Could not confirm the upload.';
      switch (data['status']) {
        case 'published':
          return widget.avatar ? 'Channel photo updated.' : 'Post published.';
        case 'pending':
          return 'Upload received. It will appear after content review.';
        case 'rejected':
          return 'This file did not pass the content review.';
        default:
          return 'Could not confirm the upload.';
      }
    } catch (_) {
      return 'Could not confirm the upload. Check your channel before retrying.';
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _result,
    builder: (context, snapshot) {
      final finished = snapshot.connectionState == ConnectionState.done;
      return PopScope(
        canPop: finished,
        child: AlertDialog(
          title: Text(finished ? 'Channel upload' : 'Uploading…'),
          content:
              finished
                  ? Text(snapshot.data ?? 'Could not upload this file.')
                  : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(),
                      SizedBox(height: 12),
                      Text(
                        'The file is submitted for content review before it appears publicly.',
                      ),
                    ],
                  ),
          actions: [
            if (finished)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
          ],
        ),
      );
    },
  );
}

class MayaCommunityApi {
  static Uri uri(String path, [Map<String, String>? query]) {
    final resolver = Uri.tryParse(MayaResolvedMedia.endpoint);
    final root =
        resolver != null && resolver.hasAuthority && resolver.path.contains('/')
            ? Uri(
              scheme: resolver.scheme,
              host: resolver.host,
              port: resolver.hasPort ? resolver.port : null,
              path: resolver.path.substring(0, resolver.path.lastIndexOf('/')),
            ).toString()
            : '$kBackendBaseUrl/social';
    return Uri.parse('$root/community$path').replace(queryParameters: query);
  }

  static String videoKey(String id, String source) {
    if (!_isSocialLink(source) &&
        RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id) &&
        ((Uri.tryParse(source)?.host == 'mayajaal.online') ||
            (Uri.tryParse(source)?.host.endsWith('.mayajaal.online') ?? false)))
      return 'maya_$id';
    final uri = Uri.tryParse(source);
    String canonical = source;
    if (uri != null) {
      if (uri.host.contains('instagram.com')) {
        canonical =
            'https://www.instagram.com${uri.path.replaceAll(RegExp(r'/+$'), '')}/';
      } else if (uri.host == 'youtu.be' || uri.host.endsWith('youtube.com')) {
        final ytId =
            uri.host == 'youtu.be'
                ? (uri.pathSegments.isEmpty ? null : uri.pathSegments.first)
                : uri.queryParameters['v'];
        canonical =
            ytId == null
                ? uri.replace(query: '', fragment: '').toString()
                : 'https://www.youtube.com/watch?v=$ytId';
      } else {
        canonical = uri.replace(fragment: '').toString();
      }
    }
    return 'external_${crypto.sha256.convert(utf8.encode(canonical))}';
  }

  static Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const HttpException('Sign in to use comments.');
    Future<http.Response> send(bool force) async {
      final token = await user.getIdToken(force);
      final req = http.Request(method, uri(path, query));
      req.headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });
      if (body != null) req.body = jsonEncode(body);
      final client = http.Client();
      try {
        return await http.Response.fromStream(
          await client.send(req).timeout(const Duration(seconds: 20)),
        ).timeout(const Duration(seconds: 20));
      } finally {
        client.close();
      }
    }

    var response = await send(false);
    if (response.statusCode == 401) response = await send(true);
    if (response.statusCode != 200) {
      String message =
          response.statusCode == 404
              ? 'Comments service is not installed yet.'
              : 'Could not update comments. Please retry.';
      try {
        final data = jsonDecode(response.body);
        if (data is Map &&
            data['detail'] is String &&
            !(response.statusCode == 404 && data['detail'] == 'Not Found'))
          message = data['detail'];
      } catch (_) {}
      throw HttpException(message);
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }
}

Future<void> showMayaComments(BuildContext context, String videoKey) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppThemes.kCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MayaCommentsSheet(videoKey: videoKey),
    );

class MayaCommentsSheet extends StatefulWidget {
  const MayaCommentsSheet({super.key, required this.videoKey});
  final String videoKey;
  @override
  State<MayaCommentsSheet> createState() => _MayaCommentsSheetState();
}

class _MayaCommentsSheetState extends State<MayaCommentsSheet> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _busyReactions = <String>{};
  List<Map<String, dynamic>> _comments = [];
  Map<String, dynamic>? _reply;
  Timer? _poll;
  String _error = '';
  bool _loading = true,
      _sending = false,
      _canModerate = false,
      _moreLoading = false,
      _pagesExpanded = false,
      _fetching = false;
  int? _before;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted &&
          (ModalRoute.of(context)?.isCurrent ?? true) &&
          !_moreLoading &&
          !_pagesExpanded &&
          !_fetching)
        unawaited(_load());
    });
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_before == null || _moreLoading)) return;
    _pagesExpanded = more;
    _fetching = true;
    final generation = ++_generation;
    if (more && mounted) setState(() => _moreLoading = true);
    try {
      final data = await MayaCommunityApi.request(
        '/${widget.videoKey}',
        query: more ? {'before': '$_before'} : null,
      );
      if (!mounted || generation != _generation) return;
      final rows =
          (data['comments'] as List? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      setState(() {
        if (more) {
          final seen = _comments.map((e) => e['id']).toSet();
          _comments = [..._comments, ...rows.where((e) => seen.add(e['id']))];
        } else {
          _comments = rows;
        }
        _before = (data['next_before'] as num?)?.toInt();
        _canModerate = data['can_moderate'] == true;
        _error = '';
        _loading = false;
        _moreLoading = false;
      });
    } catch (e) {
      if (mounted && generation == _generation)
        setState(() {
          _error =
              e is HttpException
                  ? e.message
                  : 'Could not load comments. Please retry.';
          _loading = false;
          _moreLoading = false;
        });
    } finally {
      if (generation == _generation) _fetching = false;
    }
  }

  Future<void> _send() async {
    if (_sending || _text.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await MayaCommunityApi.request(
        '/${widget.videoKey}/comments',
        method: 'POST',
        body: {'text': _text.text.trim(), 'parent_id': _reply?['id']},
      );
      if (!mounted) return;
      _text.clear();
      setState(() => _reply = null);
      await _load();
    } catch (e) {
      _notice(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _notice(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error is HttpException ? error.message : 'Please retry.'),
      ),
    );
  }

  Future<void> _react(Map<String, dynamic> item, int value) async {
    final id = '${item['id']}';
    if (!_busyReactions.add(id)) return;
    try {
      await MayaCommunityApi.request(
        '/${widget.videoKey}/comments/$id/reaction',
        method: 'POST',
        body: {'value': item['reaction'] == value ? 0 : value},
      );
      await _load();
    } catch (e) {
      _notice(e);
    } finally {
      _busyReactions.remove(id);
    }
  }

  Future<void> _pin(Map<String, dynamic> item) async {
    if (!_canModerate) return;
    Haptic.medium();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder:
          (c) => SafeArea(
            child: ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: Text(
                item['pinned'] == true ? 'Unpin comment' : 'Pin comment',
              ),
              subtitle: const Text('Pinned comments appear at the top'),
              onTap: () => Navigator.pop(c, true),
            ),
          ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await MayaCommunityApi.request(
        '/${widget.videoKey}/pin',
        method: 'POST',
        body: {'comment_id': item['pinned'] == true ? null : item['id']},
      );
      await _load();
    } catch (e) {
      _notice(e);
    }
  }

  Widget _tile(Map<String, dynamic> item, {bool reply = false}) =>
      MayaCommentTile(
        key: ValueKey(item['id']),
        item: item,
        reply: reply,
        canModerate: _canModerate,
        onPin: () => _pin(item),
        onReact: (value) => _react(item, value),
        onReply: () {
          setState(() => _reply = item);
          _focus.requestFocus();
        },
      );
  @override
  void dispose() {
    _generation++;
    _poll?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: .78,
      minChildSize: .4,
      maxChildSize: .95,
      builder:
          (context, scroll) => Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              ListTile(
                title: Text(
                  tr('comments'),
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle:
                    _canModerate
                        ? const Text(
                          'Hold a comment for 2 seconds to pin or unpin',
                          style: TextStyle(fontFamily: 'Roboto', fontSize: 11),
                        )
                        : null,
                trailing: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child:
                    _loading
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            controller: scroll,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            children: [
                              if (_error.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      Text(_error),
                                      TextButton(
                                        onPressed: _load,
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_comments.isEmpty && _error.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'No comments yet. Start the conversation.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              for (final item in _comments) ...[
                                _tile(item),
                                for (final reply
                                    in (item['replies'] as List? ?? [])
                                        .whereType<Map>())
                                  Padding(
                                    padding: const EdgeInsets.only(left: 30),
                                    child: _tile(
                                      Map<String, dynamic>.from(reply),
                                      reply: true,
                                    ),
                                  ),
                              ],
                              if (_before != null)
                                TextButton(
                                  onPressed:
                                      _moreLoading
                                          ? null
                                          : () => _load(more: true),
                                  child: Text(
                                    _moreLoading
                                        ? 'Loading…'
                                        : 'Load older comments',
                                  ),
                                ),
                            ],
                          ),
                        ),
              ),
              if (_reply != null)
                ListTile(
                  dense: true,
                  title: Text('Replying to ${_reply!['name']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _reply = null),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        focusNode: _focus,
                        maxLength: 1500,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: tr('add_comment'),
                          counterText: '',
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Send comment',
                      color: _mayaMint,
                      onPressed: _sending ? null : _send,
                      icon:
                          _sending
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
    ),
  );
}

class MayaCommentTile extends StatefulWidget {
  const MayaCommentTile({
    super.key,
    required this.item,
    required this.canModerate,
    required this.onPin,
    required this.onReact,
    required this.onReply,
    this.reply = false,
  });
  final Map<String, dynamic> item;
  final bool canModerate, reply;
  final VoidCallback onPin, onReply;
  final ValueChanged<int> onReact;
  @override
  State<MayaCommentTile> createState() => _MayaCommentTileState();
}

class _MayaCommentTileState extends State<MayaCommentTile> {
  Timer? _hold;
  Offset? _down;
  void _cancel() {
    _hold?.cancel();
    _down = null;
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Listener(
      onPointerDown:
          widget.canModerate
              ? (event) {
                _cancel();
                _down = event.position;
                _hold = Timer(const Duration(seconds: 2), () {
                  if (mounted) widget.onPin();
                });
              }
              : null,
      onPointerMove: (event) {
        if (_down != null && (event.position - _down!).distance > 10) _cancel();
      },
      onPointerUp: (_) => _cancel(),
      onPointerCancel: (_) => _cancel(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: widget.reply ? 13 : 17,
              backgroundColor: _mayaMint.withOpacity(.15),
              child: Text(
                ('${item['name'] ?? ''}'.trim().isEmpty
                    ? 'U'
                    : '${item['name']}'.characters.first),
                style: const TextStyle(fontFamily: 'Roboto', color: _mayaMint),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item['pinned'] == true)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.push_pin, size: 12, color: _mayaMint),
                          SizedBox(width: 4),
                          Text(
                            'Pinned by creator',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 11,
                              color: _mayaMint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    '${item['name'] ?? 'MayaJaal user'}',
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item['text'] ?? ''}',
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () => widget.onReact(1),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              item['reaction'] == 1
                                  ? _mayaMint
                                  : Colors.white60,
                        ),
                        icon: const Icon(Icons.thumb_up_outlined, size: 16),
                        label: Text('${item['likes'] ?? 0}'),
                      ),
                      TextButton.icon(
                        onPressed: () => widget.onReact(-1),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              item['reaction'] == -1
                                  ? _mayaMint
                                  : Colors.white60,
                        ),
                        icon: const Icon(Icons.thumb_down_outlined, size: 16),
                        label: Text('${item['dislikes'] ?? 0}'),
                      ),
                      TextButton(
                        onPressed: widget.onReply,
                        child: Text(tr('reply')),
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
  }
}

class MayaCommentSettings extends StatefulWidget {
  const MayaCommentSettings({super.key});
  @override
  State<MayaCommentSettings> createState() => _MayaCommentSettingsState();
}

class _MayaCommentSettingsState extends State<MayaCommentSettings> {
  final _words = TextEditingController();
  bool _profanity = true, _loading = true, _saving = false;
  String _error = '';
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final data = await MayaCommunityApi.request('/settings');
      if (!mounted) return;
      setState(() {
        _words.text = (data['words'] as List? ?? []).join('\n');
        _profanity = data['profanity'] != false;
        _loading = false;
        _error = '';
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = e is HttpException ? e.message : 'Could not load settings.';
        });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final words =
          _words.text
              .split(RegExp(r'[,\n]'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
      await MayaCommunityApi.request(
        '/settings',
        method: 'PUT',
        body: {'words': words, 'profanity': _profanity},
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Comment settings saved')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        setState(
          () =>
              _error =
                  e is HttpException ? e.message : 'Could not save settings.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _words.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('comment_settings'))),
    body:
        _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Control comments on videos you own',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your blocked words apply to all your MayaJaal videos and replies. Matching comments are hidden, and new matches cannot be posted.',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _profanity,
                  onChanged: (v) => setState(() => _profanity = v),
                  title: const Text('Block common abusive words'),
                  subtitle: const Text('Basic Hindi and English word filter'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _words,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Blocked words or phrases',
                    helperText:
                        'One per line or separated by commas · up to 100',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error,
                      style: const TextStyle(color: AppThemes.kRed),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed:
                      _saving || _error.contains('not installed')
                          ? null
                          : _save,
                  child: Text(_saving ? 'Saving…' : tr('save_changes')),
                ),
                if (_error.isNotEmpty)
                  TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
  );
}

class MayaFavoritesTile extends StatefulWidget {
  const MayaFavoritesTile({super.key});
  @override
  State<MayaFavoritesTile> createState() => _MayaFavoritesTileState();
}

class _MayaFavoritesTileState extends State<MayaFavoritesTile> {
  List<Map<String, dynamic>> _saved = [];
  int _index = 0;
  Timer? _rotate;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  @override
  void initState() {
    super.initState();
    WatchHistory.savedChanges.addListener(_changed);
    unawaited(_load(cloud: true));
    _rotate = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted &&
          _saved.length > 1 &&
          TickerMode.of(context) &&
          (ModalRoute.of(context)?.isCurrent ?? true)) {
        setState(() => _index = (_index + 1) % _saved.length);
      }
    });
  }

  void _changed() {
    unawaited(_load());
  }

  Future<void> _load({bool cloud = false}) async {
    final uid = _uid;
    final prefs = await SharedPreferences.getInstance();
    var saved = WatchHistory.localRecords(prefs, 'saved_videos_v1_$uid');
    if (mounted && uid == _uid)
      setState(() {
        _saved = saved;
        _index = _saved.isEmpty ? 0 : _index % _saved.length;
      });
    if (cloud && uid != 'guest') {
      try {
        final snapshot = await FirebaseDatabase.instance
            .ref('users/$uid/savedVideos')
            .get()
            .timeout(const Duration(seconds: 8));
        final items =
            snapshot.children
                .map((c) => c.value)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
        final map = <String, Map<String, dynamic>>{};
        for (final item in [...saved, ...items]) {
          map[WatchHistory.recordKey(item)] = item;
        }
        saved =
            map.values.toList()..sort(
              (a, b) => ((b['savedAt'] as num?)?.toInt() ??
                      WatchHistory.recordedAt(b))
                  .compareTo(
                    (a['savedAt'] as num?)?.toInt() ??
                        WatchHistory.recordedAt(a),
                  ),
            );
        if (mounted && uid == _uid) {
          await prefs.setString('saved_videos_v1_$uid', jsonEncode(saved));
          if (mounted)
            setState(() {
              _saved = saved;
              _index = _saved.isEmpty ? 0 : _index % _saved.length;
            });
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    WatchHistory.savedChanges.removeListener(_changed);
    _rotate?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _saved.isEmpty ? null : _saved[_index % _saved.length];
    return GestureDetector(
      onTap: () {
        SoundService.playClick();
        Haptic.light();
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SavedVideosScreen()))
            .then((_) => _load());
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
            SizedBox(
              width: 48,
              height: 24,
              child:
                  item == null
                      ? const Icon(
                        Icons.star_rounded,
                        color: AppThemes.kGreen,
                        size: 24,
                      )
                      : ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: KeyedSubtree(
                          key: ValueKey(WatchHistory.recordKey(item)),
                          child: buildMediaThumbnail(
                            _storedVideoThumbnail(item),
                            '${item['title'] ?? 'Saved video'}',
                            '${item['streamUrl'] ?? ''}',
                            sourceUrl: '${item['url'] ?? ''}',
                            loopPreview: true,
                          ),
                        ),
                      ),
            ),
            const SizedBox(height: 5),
            Text(
              tr('favorites'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _saved.isEmpty ? 'Saved' : '${_saved.length} saved',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(.5),
                fontSize: 8.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final Map<String, Map<String, String>> mayaCoreLocales = {
  "English": {
    "settings": "Settings",
    "dark_theme": "Theme",
    "language": "Language",
    "downloads": "Downloads",
    "watch_history": "Recent videos",
    "favorites": "Favorites",
    "play": "Play",
    "save": "Save",
    "download": "Download",
    "comments": "Comments",
    "reply": "Reply",
    "add_comment": "Add a comment…",
    "comment_settings": "Comment controls",
    "save_changes": "Save changes",
    "views": "views",
  },
  "Hindi": {
    "settings": "सेटिंग्स",
    "dark_theme": "थीम",
    "language": "भाषा",
    "downloads": "डाउनलोड",
    "watch_history": "हाल के वीडियो",
    "favorites": "पसंदीदा",
    "play": "चलाएँ",
    "save": "सहेजें",
    "download": "डाउनलोड",
    "comments": "टिप्पणियाँ",
    "reply": "जवाब दें",
    "add_comment": "टिप्पणी लिखें…",
    "comment_settings": "टिप्पणी नियंत्रण",
    "save_changes": "बदलाव सहेजें",
    "views": "व्यूज़",
  },
  "Bengali": {
    "settings": "সেটিংস",
    "dark_theme": "থিম",
    "language": "ভাষা",
    "downloads": "ডাউনলোড",
    "watch_history": "সাম্প্রতিক ভিডিও",
    "favorites": "পছন্দের",
    "play": "চালান",
    "save": "সংরক্ষণ",
    "download": "ডাউনলোড",
    "comments": "মন্তব্য",
    "reply": "উত্তর",
    "add_comment": "মন্তব্য লিখুন…",
    "comment_settings": "মন্তব্য নিয়ন্ত্রণ",
    "save_changes": "পরিবর্তন সংরক্ষণ",
    "views": "বার দেখা",
  },
  "Tamil": {
    "settings": "அமைப்புகள்",
    "dark_theme": "தீம்",
    "language": "மொழி",
    "downloads": "பதிவிறக்கங்கள்",
    "watch_history": "சமீபத்திய காணொளிகள்",
    "favorites": "பிடித்தவை",
    "play": "இயக்கு",
    "save": "சேமி",
    "download": "பதிவிறக்கு",
    "comments": "கருத்துகள்",
    "reply": "பதில்",
    "add_comment": "கருத்தைச் சேர்க்கவும்…",
    "comment_settings": "கருத்துக் கட்டுப்பாடுகள்",
    "save_changes": "மாற்றங்களைச் சேமி",
    "views": "பார்வைகள்",
  },
  "Telugu": {
    "settings": "సెట్టింగ్‌లు",
    "dark_theme": "థీమ్",
    "language": "భాష",
    "downloads": "డౌన్‌లోడ్‌లు",
    "watch_history": "ఇటీవలి వీడియోలు",
    "favorites": "ఇష్టమైనవి",
    "play": "ప్లే",
    "save": "సేవ్",
    "download": "డౌన్‌లోడ్",
    "comments": "వ్యాఖ్యలు",
    "reply": "ప్రత్యుత్తరం",
    "add_comment": "వ్యాఖ్య రాయండి…",
    "comment_settings": "వ్యాఖ్య నియంత్రణలు",
    "save_changes": "మార్పులు సేవ్ చేయి",
    "views": "వీక్షణలు",
  },
  "Marathi": {
    "settings": "सेटिंग्ज",
    "dark_theme": "थीम",
    "language": "भाषा",
    "downloads": "डाउनलोड",
    "watch_history": "अलीकडील व्हिडिओ",
    "favorites": "आवडते",
    "play": "प्ले करा",
    "save": "जतन करा",
    "download": "डाउनलोड",
    "comments": "टिप्पण्या",
    "reply": "उत्तर द्या",
    "add_comment": "टिप्पणी लिहा…",
    "comment_settings": "टिप्पणी नियंत्रण",
    "save_changes": "बदल जतन करा",
    "views": "दृश्ये",
  },
  "Gujarati": {
    "settings": "સેટિંગ્સ",
    "dark_theme": "થીમ",
    "language": "ભાષા",
    "downloads": "ડાઉનલોડ્સ",
    "watch_history": "તાજેતરના વિડિઓ",
    "favorites": "મનપસંદ",
    "play": "ચલાવો",
    "save": "સાચવો",
    "download": "ડાઉનલોડ",
    "comments": "ટિપ્પણીઓ",
    "reply": "જવાબ",
    "add_comment": "ટિપ્પણી લખો…",
    "comment_settings": "ટિપ્પણી નિયંત્રણ",
    "save_changes": "ફેરફારો સાચવો",
    "views": "વ્યૂઝ",
  },
  "Kannada": {
    "settings": "ಸೆಟ್ಟಿಂಗ್‌ಗಳು",
    "dark_theme": "ಥೀಮ್",
    "language": "ಭಾಷೆ",
    "downloads": "ಡೌನ್‌ಲೋಡ್‌ಗಳು",
    "watch_history": "ಇತ್ತೀಚಿನ ವೀಡಿಯೊಗಳು",
    "favorites": "ಮೆಚ್ಚಿನವುಗಳು",
    "play": "ಪ್ಲೇ ಮಾಡಿ",
    "save": "ಉಳಿಸಿ",
    "download": "ಡೌನ್‌ಲೋಡ್",
    "comments": "ಕಾಮೆಂಟ್‌ಗಳು",
    "reply": "ಪ್ರತ್ಯುತ್ತರ",
    "add_comment": "ಕಾಮೆಂಟ್ ಬರೆಯಿರಿ…",
    "comment_settings": "ಕಾಮೆಂಟ್ ನಿಯಂತ್ರಣಗಳು",
    "save_changes": "ಬದಲಾವಣೆಗಳನ್ನು ಉಳಿಸಿ",
    "views": "ವೀಕ್ಷಣೆಗಳು",
  },
  "Malayalam": {
    "settings": "ക്രമീകരണങ്ങൾ",
    "dark_theme": "തീം",
    "language": "ഭാഷ",
    "downloads": "ഡൗൺലോഡുകൾ",
    "watch_history": "സമീപകാല വീഡിയോകൾ",
    "favorites": "പ്രിയപ്പെട്ടവ",
    "play": "പ്ലേ ചെയ്യുക",
    "save": "സംരക്ഷിക്കുക",
    "download": "ഡൗൺലോഡ്",
    "comments": "അഭിപ്രായങ്ങൾ",
    "reply": "മറുപടി",
    "add_comment": "അഭിപ്രായം എഴുതുക…",
    "comment_settings": "അഭിപ്രായ നിയന്ത്രണങ്ങൾ",
    "save_changes": "മാറ്റങ്ങൾ സംരക്ഷിക്കുക",
    "views": "കാഴ്ചകൾ",
  },
  "Punjabi": {
    "settings": "ਸੈਟਿੰਗਾਂ",
    "dark_theme": "ਥੀਮ",
    "language": "ਭਾਸ਼ਾ",
    "downloads": "ਡਾਊਨਲੋਡ",
    "watch_history": "ਹਾਲੀਆ ਵੀਡੀਓ",
    "favorites": "ਮਨਪਸੰਦ",
    "play": "ਚਲਾਓ",
    "save": "ਸੰਭਾਲੋ",
    "download": "ਡਾਊਨਲੋਡ",
    "comments": "ਟਿੱਪਣੀਆਂ",
    "reply": "ਜਵਾਬ",
    "add_comment": "ਟਿੱਪਣੀ ਲਿਖੋ…",
    "comment_settings": "ਟਿੱਪਣੀ ਨਿਯੰਤਰਣ",
    "save_changes": "ਬਦਲਾਅ ਸੰਭਾਲੋ",
    "views": "ਵਿਊਜ਼",
  },
  "Urdu": {
    "settings": "ترتیبات",
    "dark_theme": "تھیم",
    "language": "زبان",
    "downloads": "ڈاؤن لوڈز",
    "watch_history": "حالیہ ویڈیوز",
    "favorites": "پسندیدہ",
    "play": "چلائیں",
    "save": "محفوظ کریں",
    "download": "ڈاؤن لوڈ",
    "comments": "تبصرے",
    "reply": "جواب دیں",
    "add_comment": "تبصرہ لکھیں…",
    "comment_settings": "تبصرے کے اختیارات",
    "save_changes": "تبدیلیاں محفوظ کریں",
    "views": "مناظر",
  },
  "Nepali": {
    "settings": "सेटिङहरू",
    "dark_theme": "थिम",
    "language": "भाषा",
    "downloads": "डाउनलोडहरू",
    "watch_history": "हालका भिडियोहरू",
    "favorites": "मनपर्ने",
    "play": "चलाउनुहोस्",
    "save": "सुरक्षित गर्नुहोस्",
    "download": "डाउनलोड",
    "comments": "टिप्पणीहरू",
    "reply": "जवाफ",
    "add_comment": "टिप्पणी लेख्नुहोस्…",
    "comment_settings": "टिप्पणी नियन्त्रण",
    "save_changes": "परिवर्तन सुरक्षित गर्नुहोस्",
    "views": "हेराइहरू",
  },
  "Arabic": {
    "settings": "الإعدادات",
    "dark_theme": "المظهر",
    "language": "اللغة",
    "downloads": "التنزيلات",
    "watch_history": "الفيديوهات الأخيرة",
    "favorites": "المفضلة",
    "play": "تشغيل",
    "save": "حفظ",
    "download": "تنزيل",
    "comments": "التعليقات",
    "reply": "رد",
    "add_comment": "أضف تعليقًا…",
    "comment_settings": "إعدادات التعليقات",
    "save_changes": "حفظ التغييرات",
    "views": "مشاهدة",
  },
  "Persian": {
    "settings": "تنظیمات",
    "dark_theme": "پوسته",
    "language": "زبان",
    "downloads": "دانلودها",
    "watch_history": "ویدیوهای اخیر",
    "favorites": "علاقه‌مندی‌ها",
    "play": "پخش",
    "save": "ذخیره",
    "download": "دانلود",
    "comments": "دیدگاه‌ها",
    "reply": "پاسخ",
    "add_comment": "دیدگاه بنویسید…",
    "comment_settings": "کنترل دیدگاه‌ها",
    "save_changes": "ذخیره تغییرات",
    "views": "بازدید",
  },
  "Spanish": {
    "settings": "Ajustes",
    "dark_theme": "Tema",
    "language": "Idioma",
    "downloads": "Descargas",
    "watch_history": "Vídeos recientes",
    "favorites": "Favoritos",
    "play": "Reproducir",
    "save": "Guardar",
    "download": "Descargar",
    "comments": "Comentarios",
    "reply": "Responder",
    "add_comment": "Añade un comentario…",
    "comment_settings": "Controles de comentarios",
    "save_changes": "Guardar cambios",
    "views": "vistas",
  },
  "French": {
    "settings": "Paramètres",
    "dark_theme": "Thème",
    "language": "Langue",
    "downloads": "Téléchargements",
    "watch_history": "Vidéos récentes",
    "favorites": "Favoris",
    "play": "Lire",
    "save": "Enregistrer",
    "download": "Télécharger",
    "comments": "Commentaires",
    "reply": "Répondre",
    "add_comment": "Ajouter un commentaire…",
    "comment_settings": "Contrôle des commentaires",
    "save_changes": "Enregistrer",
    "views": "vues",
  },
  "Portuguese": {
    "settings": "Configurações",
    "dark_theme": "Tema",
    "language": "Idioma",
    "downloads": "Downloads",
    "watch_history": "Vídeos recentes",
    "favorites": "Favoritos",
    "play": "Reproduzir",
    "save": "Salvar",
    "download": "Baixar",
    "comments": "Comentários",
    "reply": "Responder",
    "add_comment": "Adicione um comentário…",
    "comment_settings": "Controles de comentários",
    "save_changes": "Salvar alterações",
    "views": "visualizações",
  },
  "German": {
    "settings": "Einstellungen",
    "dark_theme": "Design",
    "language": "Sprache",
    "downloads": "Downloads",
    "watch_history": "Letzte Videos",
    "favorites": "Favoriten",
    "play": "Abspielen",
    "save": "Speichern",
    "download": "Herunterladen",
    "comments": "Kommentare",
    "reply": "Antworten",
    "add_comment": "Kommentar schreiben…",
    "comment_settings": "Kommentareinstellungen",
    "save_changes": "Änderungen speichern",
    "views": "Aufrufe",
  },
  "Italian": {
    "settings": "Impostazioni",
    "dark_theme": "Tema",
    "language": "Lingua",
    "downloads": "Download",
    "watch_history": "Video recenti",
    "favorites": "Preferiti",
    "play": "Riproduci",
    "save": "Salva",
    "download": "Scarica",
    "comments": "Commenti",
    "reply": "Rispondi",
    "add_comment": "Aggiungi un commento…",
    "comment_settings": "Controlli dei commenti",
    "save_changes": "Salva modifiche",
    "views": "visualizzazioni",
  },
  "Russian": {
    "settings": "Настройки",
    "dark_theme": "Тема",
    "language": "Язык",
    "downloads": "Загрузки",
    "watch_history": "Недавние видео",
    "favorites": "Избранное",
    "play": "Смотреть",
    "save": "Сохранить",
    "download": "Скачать",
    "comments": "Комментарии",
    "reply": "Ответить",
    "add_comment": "Добавьте комментарий…",
    "comment_settings": "Управление комментариями",
    "save_changes": "Сохранить изменения",
    "views": "просмотров",
  },
  "Ukrainian": {
    "settings": "Налаштування",
    "dark_theme": "Тема",
    "language": "Мова",
    "downloads": "Завантаження",
    "watch_history": "Нещодавні відео",
    "favorites": "Обране",
    "play": "Відтворити",
    "save": "Зберегти",
    "download": "Завантажити",
    "comments": "Коментарі",
    "reply": "Відповісти",
    "add_comment": "Додайте коментар…",
    "comment_settings": "Керування коментарями",
    "save_changes": "Зберегти зміни",
    "views": "переглядів",
  },
  "Turkish": {
    "settings": "Ayarlar",
    "dark_theme": "Tema",
    "language": "Dil",
    "downloads": "İndirilenler",
    "watch_history": "Son videolar",
    "favorites": "Favoriler",
    "play": "Oynat",
    "save": "Kaydet",
    "download": "İndir",
    "comments": "Yorumlar",
    "reply": "Yanıtla",
    "add_comment": "Yorum ekleyin…",
    "comment_settings": "Yorum kontrolleri",
    "save_changes": "Değişiklikleri kaydet",
    "views": "görüntüleme",
  },
  "Indonesian": {
    "settings": "Setelan",
    "dark_theme": "Tema",
    "language": "Bahasa",
    "downloads": "Unduhan",
    "watch_history": "Video terbaru",
    "favorites": "Favorit",
    "play": "Putar",
    "save": "Simpan",
    "download": "Unduh",
    "comments": "Komentar",
    "reply": "Balas",
    "add_comment": "Tambahkan komentar…",
    "comment_settings": "Kontrol komentar",
    "save_changes": "Simpan perubahan",
    "views": "penayangan",
  },
  "Malay": {
    "settings": "Tetapan",
    "dark_theme": "Tema",
    "language": "Bahasa",
    "downloads": "Muat turun",
    "watch_history": "Video terkini",
    "favorites": "Kegemaran",
    "play": "Main",
    "save": "Simpan",
    "download": "Muat turun",
    "comments": "Komen",
    "reply": "Balas",
    "add_comment": "Tambah komen…",
    "comment_settings": "Kawalan komen",
    "save_changes": "Simpan perubahan",
    "views": "tontonan",
  },
  "Vietnamese": {
    "settings": "Cài đặt",
    "dark_theme": "Giao diện",
    "language": "Ngôn ngữ",
    "downloads": "Tệp tải xuống",
    "watch_history": "Video gần đây",
    "favorites": "Yêu thích",
    "play": "Phát",
    "save": "Lưu",
    "download": "Tải xuống",
    "comments": "Bình luận",
    "reply": "Trả lời",
    "add_comment": "Thêm bình luận…",
    "comment_settings": "Kiểm soát bình luận",
    "save_changes": "Lưu thay đổi",
    "views": "lượt xem",
  },
  "Thai": {
    "settings": "การตั้งค่า",
    "dark_theme": "ธีม",
    "language": "ภาษา",
    "downloads": "ดาวน์โหลด",
    "watch_history": "วิดีโอล่าสุด",
    "favorites": "รายการโปรด",
    "play": "เล่น",
    "save": "บันทึก",
    "download": "ดาวน์โหลด",
    "comments": "ความคิดเห็น",
    "reply": "ตอบกลับ",
    "add_comment": "เพิ่มความคิดเห็น…",
    "comment_settings": "การควบคุมความคิดเห็น",
    "save_changes": "บันทึกการเปลี่ยนแปลง",
    "views": "ครั้ง",
  },
  "Chinese": {
    "settings": "设置",
    "dark_theme": "主题",
    "language": "语言",
    "downloads": "下载内容",
    "watch_history": "最近的视频",
    "favorites": "收藏",
    "play": "播放",
    "save": "保存",
    "download": "下载",
    "comments": "评论",
    "reply": "回复",
    "add_comment": "添加评论…",
    "comment_settings": "评论管理",
    "save_changes": "保存更改",
    "views": "次观看",
  },
  "Japanese": {
    "settings": "設定",
    "dark_theme": "テーマ",
    "language": "言語",
    "downloads": "ダウンロード",
    "watch_history": "最近の動画",
    "favorites": "お気に入り",
    "play": "再生",
    "save": "保存",
    "download": "ダウンロード",
    "comments": "コメント",
    "reply": "返信",
    "add_comment": "コメントを追加…",
    "comment_settings": "コメント管理",
    "save_changes": "変更を保存",
    "views": "回視聴",
  },
  "Korean": {
    "settings": "설정",
    "dark_theme": "테마",
    "language": "언어",
    "downloads": "다운로드",
    "watch_history": "최근 동영상",
    "favorites": "즐겨찾기",
    "play": "재생",
    "save": "저장",
    "download": "다운로드",
    "comments": "댓글",
    "reply": "답글",
    "add_comment": "댓글 추가…",
    "comment_settings": "댓글 관리",
    "save_changes": "변경사항 저장",
    "views": "조회",
  },
  "Swahili": {
    "settings": "Mipangilio",
    "dark_theme": "Mandhari",
    "language": "Lugha",
    "downloads": "Vipakuliwa",
    "watch_history": "Video za karibuni",
    "favorites": "Vipendwa",
    "play": "Cheza",
    "save": "Hifadhi",
    "download": "Pakua",
    "comments": "Maoni",
    "reply": "Jibu",
    "add_comment": "Ongeza maoni…",
    "comment_settings": "Udhibiti wa maoni",
    "save_changes": "Hifadhi mabadiliko",
    "views": "mitazamo",
  },
};
final Map<String, String> mayaLanguageNames = {
  "English": "English",
  "Hindi": "हिन्दी",
  "Bengali": "বাংলা",
  "Tamil": "தமிழ்",
  "Telugu": "తెలుగు",
  "Marathi": "मराठी",
  "Gujarati": "ગુજરાતી",
  "Kannada": "ಕನ್ನಡ",
  "Malayalam": "മലയാളം",
  "Punjabi": "ਪੰਜਾਬੀ",
  "Urdu": "اردو",
  "Nepali": "नेपाली",
  "Arabic": "العربية",
  "Persian": "فارسی",
  "Spanish": "Español",
  "French": "Français",
  "Portuguese": "Português",
  "German": "Deutsch",
  "Italian": "Italiano",
  "Russian": "Русский",
  "Ukrainian": "Українська",
  "Turkish": "Türkçe",
  "Indonesian": "Bahasa Indonesia",
  "Malay": "Bahasa Melayu",
  "Vietnamese": "Tiếng Việt",
  "Thai": "ไทย",
  "Chinese": "中文",
  "Japanese": "日本語",
  "Korean": "한국어",
  "Swahili": "Kiswahili",
};
const mayaThemeColors = <String, Color>{
  'Cyber Emerald': Color(0xFF69E6A6),
  'Quantum Blue': Color(0xFF72C8F1),
  'Neon Violet': Color(0xFFC2AAFF),
  'Obsidian Stealth': Color(0xFFCED4DC),
  'Ocean Teal': Color(0xFF61D5CA),
  'Champagne Gold': Color(0xFFE7C885),
  'Rose Quartz': Color(0xFFEBA4BF),
  'Arctic Sky': Color(0xFFA7D8FF),
  'Sunset Coral': Color(0xFFFFB29D),
  'Midnight Indigo': Color(0xFFA5B4FC),
};

class MayaChannelPostEntry extends StatefulWidget {
  const MayaChannelPostEntry({super.key, required this.source});
  final Uri source;
  @override
  State<MayaChannelPostEntry> createState() => _MayaChannelPostEntryState();
}

class _MayaChannelPostEntryState extends State<MayaChannelPostEntry> {
  late Future<List<Map<String, dynamic>>> _data = _load();
  Future<List<Map<String, dynamic>>> _load() async {
    final id = Uri.encodeComponent(_mayaChannelId(widget.source)!);
    final post = Uri.encodeComponent(widget.source.queryParameters['post']!);
    return Future.wait([
      MayaChannelsApi.request('/$id'),
      MayaChannelsApi.request('/$id/posts/$post'),
    ]);
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final channel = snapshot.data![0], post = snapshot.data![1];
            return NativeVideoPlayerScreen(
              videoUrl: '${post['media'] ?? ''}',
              title:
                  '${post['text'] ?? ''}'.isEmpty
                      ? '${post['filename'] ?? 'Channel video'}'
                      : '${post['text']}',
              uploader: '${channel['name']}',
              sourcePageUrl: widget.source.toString(),
              videoId: '${post['id']}',
              thumbnailUrl: '${post['thumbnail'] ?? ''}',
              channelId: '${channel['id']}',
              channelPostId: '${post['id']}',
            );
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Channel video')),
            body: Center(
              child:
                  snapshot.hasError
                      ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              _channelError(snapshot.error!),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _data = _load()),
                            child: const Text('Retry'),
                          ),
                        ],
                      )
                      : const CircularProgressIndicator(),
            ),
          );
        },
      );
}
