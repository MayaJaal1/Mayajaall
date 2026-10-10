import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:device_info_plus/device_info_plus.dart';

const String supabaseUrl = 'https://rbdfqmmjgfwikaoxdexu.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJiZGZxbW1qZ2Z3aWthb3hkZXh1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEwOTkxNzMsImV4cCI6MjEwNjY3NTE3M30.qB_DrMLR33BcUJtu5IlyBuw0gXlcw9dXk3SX_uIknP0';
const String webClientId = '985001671962-rok8qnng0rumjsd8mgr8uhr92o5vhs4n.apps.googleusercontent.com';

const String oneSignalAppId = '06b99c2b-b3b4-413b-b6cc-480a624f4e25';
const int kAppCurrentVersionCode = 3;
const String kBackendBaseUrl = 'https://www.mayajaal.online';

const Color kGreen = Color(0xFF00FF66);
const Color kNeonCyan = Color(0xFF00F0FF);
const Color kNeonPurple = Color(0xFF9D00FF);
const Color kBg = Color(0xFF000000);
const Color kCardBg = Color(0xFF031408);
const Color kDimGreen = Color(0xFF4FBF8B);

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<String> languageNotifier = ValueNotifier('English');
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
    'check_updates': 'Check for Updates',
    'clear_history': 'Clear History',
    'logout': 'Logout',
    'update_available': 'NEW UPDATE FOUND',
    'update_now': 'UPDATE NOW',
    'later': 'LATER',
    'init_stream': 'INITIALIZE NEURAL STREAM\nSTREAM (OPEN NOW)',
    'stream_ready': 'STREAM READY FOR DECRYPTION',
    'download': 'DOWNLOAD VIDEO',
    'share': 'SHARE VIDEO',
    'uploader': 'UPLOADER',
    'filename': 'FILE NAME',
  },
  'Hindi': {
    'app_title': 'माया जाल',
    'paste_hint': 'यहाँ लिंक पेस्ट करें...',
    'watch_history': '> देखने का इतिहास',
    'no_history': 'अभी कोई इतिहास नहीं है',
    'settings': 'सेटिंग्स',
    'dark_theme': 'डार्क थीम (मैट्रिक्स मोड)',
    'language': 'भाषा (Language)',
    'download_location': 'डाउनलोड स्थान',
    'check_updates': 'अपडेट चेक करें',
    'clear_history': 'इतिहास साफ़ करें',
    'logout': 'लॉग आउट',
    'update_available': 'नया अपडेट उपलब्ध है',
    'update_now': 'अभी अपडेट करें',
    'later': 'बाद में',
    'init_stream': 'INITIALIZE NEURAL STREAM\nSTREAM (OPEN NOW)',
    'stream_ready': 'STREAM READY FOR DECRYPTION',
    'download': 'वीडियो डाउनलोड करें',
    'share': 'वीडियो लिंक शेयर करें',
    'uploader': 'अपलोडर',
    'filename': 'फ़ाइल का नाम',
  },
};

String tr(String key) {
  final lang = languageNotifier.value;
  return localizedStrings[lang]?[key] ?? localizedStrings['English']?[key] ?? key;
}

// ============================================================
// MAYAJAAL ACCOUNT SERVICE (RTDB sync)
// ============================================================
class MayaJaalAccount {
  static const _prefApiKey = 'mj_api_key';
  static const _prefFirebaseUid = 'mj_firebase_uid';
  static const _prefEmail = 'mj_email';

  static String? cachedApiKey;
  static String? cachedFirebaseUid;
  static String? cachedEmail;

  static DatabaseReference get _rtdb => FirebaseDatabase.instance.ref();

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    cachedApiKey = prefs.getString(_prefApiKey);
    cachedFirebaseUid = prefs.getString(_prefFirebaseUid);
    cachedEmail = prefs.getString(_prefEmail);
  }

  static bool get isLinked => cachedApiKey != null && cachedFirebaseUid != null;

  static Future<Map<String, dynamic>?> _findUserByApiKey(String apiKey) async {
    try {
      final snap = await _rtdb
          .child('users')
          .orderByChild('apiKey')
          .equalTo(apiKey)
          .limitToFirst(1)
          .once();
      final val = snap.snapshot.value;
      if (val == null) return null;
      final map = Map<String, dynamic>.from(val as Map);
      if (map.isEmpty) return null;
      final uid = map.keys.first;
      final data = Map<String, dynamic>.from(map[uid] as Map);
      data['uid'] = uid;
      return data;
    } catch (e) {
      debugPrint('findUserByApiKey error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> linkWithApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.length < 12) {
      return {'success': false, 'error': 'Key must be 12+ chars'};
    }
    final user = await _findUserByApiKey(trimmed);
    if (user == null) {
      return {'success': false, 'error': 'Invalid API key'};
    }

    final uid = user['uid'] as String;
    final email = (user['email'] ?? '').toString();

    cachedApiKey = trimmed;
    cachedFirebaseUid = uid;
    cachedEmail = email;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefApiKey, trimmed);
    await prefs.setString(_prefFirebaseUid, uid);
    await prefs.setString(_prefEmail, email);

    try {
      await _rtdb.child('users/$uid/app').update({
        'lastLinkedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}

    return {'success': true, 'email': email, 'uid': uid};
  }

  static Future<void> unlink() async {
    cachedApiKey = null;
    cachedFirebaseUid = null;
    cachedEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefApiKey);
    await prefs.remove(_prefFirebaseUid);
    await prefs.remove(_prefEmail);
  }

  static Future<Map<String, dynamic>> getDashboard() async {
    if (cachedFirebaseUid == null) return {};
    try {
      final snap = await _rtdb
          .child('users/${cachedFirebaseUid!}/dashboard')
          .once();
      return Map<String, dynamic>.from((snap.snapshot.value ?? {}) as Map);
    } catch (e) {
      debugPrint('getDashboard error: $e');
      return {};
    }
  }

  static Future<List<Map<String, dynamic>>> getUserLinks({int limit = 20}) async {
    if (cachedFirebaseUid == null) return [];
    try {
      final snap = await _rtdb
          .child('links')
          .orderByChild('ownerUid')
          .equalTo(cachedFirebaseUid!)
          .once();
      final val = snap.snapshot.value;
      if (val == null) return [];
      final map = Map<String, dynamic>.from(val as Map);
      final arr = map.entries.map((e) {
        final data = Map<String, dynamic>.from(e.value as Map);
        data['id'] = e.key;
        return data;
      }).toList();
      arr.sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));
      return arr.take(limit).toList();
    } catch (e) {
      debugPrint('getUserLinks error: $e');
      return [];
    }
  }

  static double calcEarnings(int views) {
    views = math.max(0, views);
    if (views <= 0) return 0;
    if (views <= 1000) return _round2((views / 1000) * 1);
    double income = 1;
    int remaining = views - 1000;
    int tier = 1;
    while (remaining > 0) {
      final chunk = math.min(remaining, 2000);
      income += (chunk / 1000) * math.pow(1.5, tier);
      remaining -= chunk;
      tier++;
      if (tier > 30) break;
    }
    return _round2(income);
  }

  static Map<String, dynamic> getTierInfo(int views) {
    views = math.max(0, views);
    if (views < 1000) {
      return {'tier': 1, 'rate': 1.00, 'from': 0, 'to': 1000, 'next': 1000 - views};
    }
    int tier = 1;
    int start = 1000;
    while (views >= start + 2000) {
      tier++;
      start += 2000;
      if (tier > 30) break;
    }
    return {
      'tier': tier + 1,
      'rate': _round2(math.pow(1.5, tier).toDouble()),
      'from': start,
      'to': start + 2000,
      'next': start + 2000 - views,
    };
  }

  static double _round2(num n) => (n * 100).round() / 100;
}

// ============================================================
// DEVICE ID HELPER
// ============================================================
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

// ============================================================
// MAIN
// ============================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.black,
    statusBarIconBrightness: Brightness.light,
  ));

  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDI5hgBbaUeTpXcPIlAnq5yDjIenfY-ylM",
        authDomain: "www.mayajaal.online",
        databaseURL: "https://mayajaal-app-default-rtdb.asia-southeast1.firebasedatabase.app",
        projectId: "mayajaal-app",
        storageBucket: "mayajaal-app.firebasestorage.app",
        messagingSenderId: "96139047750",
        appId: "1:96139047750:web:850537e9c436dd7d012b47",
      ),
    );
    debugPrint("Firebase Initialized");
  } catch (e) {
    debugPrint("Firebase Initialization Error: $e");
  }

  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  } catch (e) {
    debugPrint("Supabase Initialization Error: $e");
  }

  try {
    await MayaJaalAccount.init();
  } catch (e) {
    debugPrint("MayaJaalAccount init error: $e");
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

// ============================================================
// MATRIX RAIN
// ============================================================
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
    return LayoutBuilder(
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
                  color: kGreen.withOpacity(widget.opacity),
                  fontSize: 13,
                  fontFamily: 'monospace',
                  shadows: const [Shadow(color: kGreen, blurRadius: 6)],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ============================================================
// SPLASH
// ============================================================
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
    _a = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOut),
    );
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
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.black,
                            child: const Icon(Icons.movie_filter, size: 70, color: kGreen),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'MAYA JAAL LOADING...',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: kGreen,
                    fontFamily: 'monospace',
                    letterSpacing: 4,
                    shadows: [
                      Shadow(color: kGreen.withOpacity(0.85), blurRadius: 16),
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

// ============================================================
// MY APP — Deep link handling
// ============================================================
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

    if (uri.path.startsWith('/v/') || uri.host == 'watch' || uri.scheme == 'mayajaal') {
      String videoId = '';
      final token = uri.queryParameters['t'] ?? uri.queryParameters['s'] ?? '';

      if (uri.path.startsWith('/v/')) {
        videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      } else if (uri.queryParameters['v'] != null) {
        videoId = uri.queryParameters['v']!;
      }
      if (videoId.isEmpty) return;

      final targetUrl = token.isNotEmpty
          ? 'https://www.mayajaal.online/v/$videoId?t=$token'
          : 'https://www.mayajaal.online/v/$videoId';

      navigator.push(MaterialPageRoute(
        builder: (_) => StreamPreviewScreen(targetUrl: targetUrl),
      ));
    } else if (uri.path.startsWith('/s/')) {
      final shortCode = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (shortCode.isNotEmpty) {
        launchUrl(
          Uri.parse('https://www.mayajaal.online/s/$shortCode'),
          mode: LaunchMode.externalApplication,
        );
      }
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  String _buildUrlFromLink(Uri uri) {
    String videoId = '';
    final token = uri.queryParameters['t'] ?? uri.queryParameters['s'] ?? '';
    if (uri.path.startsWith('/v/')) {
      videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    } else if (uri.queryParameters['v'] != null) {
      videoId = uri.queryParameters['v']!;
    }
    return token.isNotEmpty
        ? 'https://www.mayajaal.online/v/$videoId?t=$token'
        : 'https://www.mayajaal.online/v/$videoId';
  }

  @override
  Widget build(BuildContext context) {
    if (!_linkReady) {
      return MaterialApp(
        home: const SplashScreen(),
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
              home: _initialLink != null
                  ? StreamPreviewScreen(targetUrl: _buildUrlFromLink(_initialLink!))
                  : const AuthGate(),
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

// ============================================================
// AUTH GATE
// ============================================================
class AuthGate extends StatelessWidget {
  final String? pendingTargetUrl;
  const AuthGate({super.key, this.pendingTargetUrl});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          if (pendingTargetUrl != null && pendingTargetUrl!.isNotEmpty) {
            return StreamPreviewScreen(targetUrl: pendingTargetUrl!);
          }
          return const MainNavigationHolder();
        }
        return LoginScreen(pendingTargetUrl: pendingTargetUrl);
      },
    );
  }
}

// ============================================================
// LOGIN SCREEN
// ============================================================
class LoginScreen extends StatefulWidget {
  final String? pendingTargetUrl;
  const LoginScreen({super.key, this.pendingTargetUrl});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  bool _isLoginTab = true;
  bool _loading = false;
  bool _obscurePassword = true;
  String _error = '';
  String _successMsg = '';

  final TextEditingController _loginIdController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();

  final TextEditingController _signupMatrixIdController = TextEditingController();
  final TextEditingController _signupPhoneController = TextEditingController();
  final TextEditingController _signupPasswordController = TextEditingController();
  final TextEditingController _signupOtpController = TextEditingController();
  bool _otpSentForSignup = false;

  final TextEditingController _resetPhoneController = TextEditingController();
  final TextEditingController _resetOtpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  late AnimationController _magicController;
  late Animation<double> _glowAnimation;
  late Animation<double> _scaleAnimation;
  bool _showMagicUnlock = false;

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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _magicController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _loginIdController.dispose();
    _loginPasswordController.dispose();
    _signupMatrixIdController.dispose();
    _signupPhoneController.dispose();
    _signupPasswordController.dispose();
    _signupOtpController.dispose();
    _resetPhoneController.dispose();
    _resetOtpController.dispose();
    _newPasswordController.dispose();
    _magicController.dispose();
    super.dispose();
  }

  Future<void> _triggerMagicUnlock() async {
    setState(() {
      _showMagicUnlock = true;
      _error = '';
    });
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.heavyImpact();
    } catch (_) {}
    await _magicController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
  }

  String _formatPhone(String raw) {
    String clean = raw.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10) return '+91$clean';
    if (!clean.startsWith('+')) return '+$clean';
    return clean;
  }

  Future<void> _sendSignupOtp() async {
    final matrixId = _signupMatrixIdController.text.trim().toLowerCase().replaceAll('@', '');
    final phone = _formatPhone(_signupPhoneController.text.trim());
    final pass = _signupPasswordController.text.trim();

    if (matrixId.isEmpty || phone.length < 10 || pass.length < 6) {
      setState(() => _error = 'Sabhi details bharein! Password kam se kam 6 akshar ka ho.');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
      _successMsg = '';
    });

    try {
      await Supabase.instance.client.auth.signInWithOtp(phone: phone);
      setState(() {
        _otpSentForSignup = true;
        _successMsg = 'OTP aapke phone number par bhej diya gaya hai!';
      });
    } catch (e) {
      setState(() => _error = 'OTP send error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifySignupOtpAndRegister() async {
    final matrixId = _signupMatrixIdController.text.trim().toLowerCase().replaceAll('@', '');
    final phone = _formatPhone(_signupPhoneController.text.trim());
    final pass = _signupPasswordController.text.trim();
    final otp = _signupOtpController.text.trim();

    if (otp.length < 4) {
      setState(() => _error = 'Kripya sahi OTP dalein');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final res = await Supabase.instance.client.auth.verifyOTP(
        phone: phone,
        token: otp,
        type: OtpType.sms,
      );

      if (res.user != null) {
        await Supabase.instance.client.from('profiles').upsert({
          'id': res.user!.id,
          'username': matrixId,
          'display_name': '@$matrixId',
        });
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: pass),
        );

        await Supabase.instance.client.auth.signOut();
        setState(() {
          _isLoginTab = true;
          _otpSentForSignup = false;
          _loginIdController.text = matrixId;
          _loginPasswordController.text = pass;
          _successMsg = 'Matrix ID ban chuki hai! Ab seedha Login karein.';
        });
      }
    } catch (e) {
      setState(() => _error = 'Signup failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleMatrixLogin() async {
    final rawInput = _loginIdController.text.trim().toLowerCase().replaceAll('@', '');
    final password = _loginPasswordController.text.trim();

    if (rawInput.isEmpty || password.isEmpty) {
      setState(() => _error = 'Matrix ID / Phone aur Password dalein');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
      _successMsg = '';
    });

    try {
      String finalEmailOrPhone = rawInput;

      if (!rawInput.contains('@') && !RegExp(r'^[0-9+]+$').hasMatch(rawInput)) {
        finalEmailOrPhone = '$rawInput@mayajaal.online';
      }

      if (RegExp(r'^[0-9+]{10,}$').hasMatch(rawInput)) {
        await Supabase.instance.client.auth.signInWithPassword(
          phone: _formatPhone(rawInput),
          password: password,
        );
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: finalEmailOrPhone,
          password: password,
        );
      }

      await _triggerMagicUnlock();
    } catch (e) {
      setState(() => _error = 'Login Failed: Invalid Matrix ID or Password');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(serverClientId: webClientId);
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) throw 'No ID Token found.';
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
      );
      await _triggerMagicUnlock();
    } catch (e) {
      setState(() => _error = 'Google Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openForgotPasswordDialog() {
    bool otpSent = false;
    bool dialogLoading = false;
    String dialogMsg = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF011406),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Color(0xFF00FF66), width: 1.5),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text(
                  'RESET MATRIX PASSWORD',
                  style: TextStyle(color: Color(0xFF00FF66), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
                const SizedBox(height: 14),
                if (!otpSent) ...[
                  TextField(
                    controller: _resetPhoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter Registered Phone Number (+91)',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                      prefixIcon: const Icon(Icons.phone_android, color: Color(0xFF00FF66)),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FF66))),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: dialogLoading ? null : () async {
                      setDialogState(() => dialogLoading = true);
                      try {
                        await Supabase.instance.client.auth.signInWithOtp(phone: _formatPhone(_resetPhoneController.text.trim()));
                        setDialogState(() {
                          otpSent = true;
                          dialogMsg = 'OTP Sent to ${_resetPhoneController.text.trim()}';
                        });
                      } catch (e) {
                        setDialogState(() => dialogMsg = 'Error: $e');
                      } finally {
                        setDialogState(() => dialogLoading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF66), foregroundColor: Colors.black),
                    child: dialogLoading ? const CircularProgressIndicator(color: Colors.black) : const Text('SEND RESET OTP'),
                  ),
                ] else ...[
                  TextField(
                    controller: _resetOtpController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter 6-Digit OTP',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                      prefixIcon: const Icon(Icons.lock_clock, color: Color(0xFF00FF66)),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FF66))),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _newPasswordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter New Password',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                      prefixIcon: const Icon(Icons.vpn_key, color: Color(0xFF00FF66)),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FF66))),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: dialogLoading ? null : () async {
                      setDialogState(() => dialogLoading = true);
                      try {
                        await Supabase.instance.client.auth.verifyOTP(
                          phone: _formatPhone(_resetPhoneController.text.trim()),
                          token: _resetOtpController.text.trim(),
                          type: OtpType.sms,
                        );
                        await Supabase.instance.client.auth.updateUser(
                          UserAttributes(password: _newPasswordController.text.trim()),
                        );
                        Navigator.pop(ctx);
                        setState(() => _successMsg = 'Password successfully changed! Please login.');
                      } catch (e) {
                        setDialogState(() => dialogMsg = 'Reset failed: $e');
                      } finally {
                        setDialogState(() => dialogLoading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF66), foregroundColor: Colors.black),
                    child: dialogLoading ? const CircularProgressIndicator(color: Colors.black) : const Text('UPDATE PASSWORD'),
                  ),
                ],
                if (dialogMsg.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(dialogMsg, style: const TextStyle(color: Colors.yellowAccent, fontSize: 11)),
                ]
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const MatrixRain(opacity: 0.55),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: AnimatedBuilder(
                  animation: _magicController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF021206).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _showMagicUnlock
                                ? const Color(0xFF00FF66)
                                : const Color(0xFF00FF66).withOpacity(0.4),
                            width: _showMagicUnlock ? 2.2 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00FF66).withOpacity(_showMagicUnlock ? 0.45 : 0.15),
                              blurRadius: _glowAnimation.value + 15,
                              spreadRadius: _showMagicUnlock ? 4 : 0,
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFF00FF66), width: 1.8),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF00FF66).withOpacity(0.55), blurRadius: 18, spreadRadius: 2),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/icon/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.change_history, size: 42, color: Color(0xFF00FF66)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'MAYA JAAL',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF00FF66),
                          fontFamily: 'monospace',
                          letterSpacing: 6,
                          shadows: [Shadow(color: Color(0xFF00FF66), blurRadius: 16)],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '> Enter the real world behind\n   the digital veil _',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: const Color(0xFF00FF66).withOpacity(0.85),
                          fontFamily: 'monospace',
                          letterSpacing: 1.5,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFF00FF66).withOpacity(0.6)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() { _isLoginTab = true; _error = ''; }),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _isLoginTab ? const Color(0xFF01240B) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(24),
                                    border: _isLoginTab ? Border.all(color: const Color(0xFF00FF66), width: 1.6) : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'LOGIN',
                                    style: TextStyle(
                                      color: _isLoginTab ? const Color(0xFF00FF66) : Colors.white60,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() { _isLoginTab = false; _error = ''; }),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: !_isLoginTab ? const Color(0xFF01240B) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(24),
                                    border: !_isLoginTab ? Border.all(color: const Color(0xFF00FF66), width: 1.6) : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'SIGN UP',
                                    style: TextStyle(
                                      color: !_isLoginTab ? const Color(0xFF00FF66) : Colors.white60,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF00FF66).withOpacity(0.35)),
                        ),
                        child: _isLoginTab
                            ? Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF031A0B),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF00FF66).withOpacity(0.5)),
                                    ),
                                    child: TextField(
                                      controller: _loginIdController,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                                      decoration: InputDecoration(
                                        icon: const Icon(Icons.person_outline, color: Color(0xFF00FF66), size: 20),
                                        hintText: 'Matrix ID / Phone / Email',
                                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF031A0B),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF00FF66).withOpacity(0.5)),
                                    ),
                                    child: TextField(
                                      controller: _loginPasswordController,
                                      obscureText: _obscurePassword,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                                      decoration: InputDecoration(
                                        icon: const Icon(Icons.lock_outline, color: Color(0xFF00FF66), size: 20),
                                        suffixIcon: IconButton(
                                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF00FF66), size: 19),
                                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                        ),
                                        hintText: 'Password',
                                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: _loading ? null : _handleMatrixLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF00FF66),
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        elevation: 8,
                                      ),
                                      child: _loading
                                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.2))
                                          : const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.login, size: 19, color: Colors.black),
                                                SizedBox(width: 8),
                                                Text('LOGIN WITH MATRIX ID', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12.5)),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF031A0B),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF00FF66).withOpacity(0.5)),
                                    ),
                                    child: TextField(
                                      controller: _signupMatrixIdController,
                                      enabled: !_otpSentForSignup,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                                      decoration: InputDecoration(
                                        prefixText: '@',
                                        prefixStyle: const TextStyle(color: Color(0xFF00FF66), fontWeight: FontWeight.bold),
                                        icon: const Icon(Icons.alternate_email, color: Color(0xFF00FF66), size: 20),
                                        hintText: 'Choose Matrix ID (like insta)',
                                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF031A0B),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF00FF66).withOpacity(0.5)),
                                    ),
                                    child: TextField(
                                      controller: _signupPhoneController,
                                      enabled: !_otpSentForSignup,
                                      keyboardType: TextInputType.phone,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                                      decoration: InputDecoration(
                                        icon: const Icon(Icons.phone_android, color: Color(0xFF00FF66), size: 20),
                                        hintText: 'Mobile Number (+91)',
                                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF031A0B),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF00FF66).withOpacity(0.5)),
                                    ),
                                    child: TextField(
                                      controller: _signupPasswordController,
                                      obscureText: _obscurePassword,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                                      decoration: InputDecoration(
                                        icon: const Icon(Icons.lock_outline, color: Color(0xFF00FF66), size: 20),
                                        hintText: 'Create Strong Password',
                                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  if (_otpSentForSignup) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF03220E),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.yellowAccent),
                                      ),
                                      child: TextField(
                                        controller: _signupOtpController,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace', letterSpacing: 4),
                                        decoration: InputDecoration(
                                          icon: const Icon(Icons.message_outlined, color: Colors.yellowAccent, size: 20),
                                          hintText: 'Enter SMS OTP',
                                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, letterSpacing: 0),
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: _loading ? null : (_otpSentForSignup ? _verifySignupOtpAndRegister : _sendSignupOtp),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF00FF66),
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: _loading
                                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.2))
                                          : Text(
                                              _otpSentForSignup ? 'VERIFY OTP & COMPLETE' : 'GET OTP ON NUMBER',
                                              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 12.5),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: Divider(color: const Color(0xFF00FF66).withOpacity(0.3))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('OR', style: TextStyle(color: const Color(0xFF00FF66).withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(child: Divider(color: const Color(0xFF00FF66).withOpacity(0.3))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _signInWithGoogle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://developers.google.com/identity/images/g-logo.png',
                                height: 20,
                                errorBuilder: (c, e, s) => const Icon(Icons.g_mobiledata, color: Colors.red, size: 24),
                              ),
                              const SizedBox(width: 10),
                              const Text('Sign in with Google', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: _openForgotPasswordDialog,
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(color: const Color(0xFF00FF66).withOpacity(0.9), fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isLoginTab ? "Don't have an account? " : "Already have an account? ",
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                          ),
                          GestureDetector(
                            onTap: () => setState(() {
                              _isLoginTab = !_isLoginTab;
                              _error = '';
                              _successMsg = '';
                            }),
                            child: Text(
                              _isLoginTab ? 'Sign Up →' : 'Login →',
                              style: const TextStyle(color: Color(0xFF00FF66), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      if (_successMsg.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            border: Border.all(color: const Color(0xFF00FF66)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_successMsg, style: const TextStyle(color: Color(0xFF00FF66), fontSize: 11.5), textAlign: TextAlign.center),
                        ),
                      ],
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            border: Border.all(color: Colors.redAccent),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 11), textAlign: TextAlign.center),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MAIN NAVIGATION HOLDER — 3 tabs + Drawer
// ============================================================
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
          border: Border(top: BorderSide(color: kGreen.withOpacity(0.35), width: 1.2)),
          boxShadow: [
            BoxShadow(color: kGreen.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, -3)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: kGreen,
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home, color: kGreen),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.ondemand_video_outlined),
              activeIcon: Icon(Icons.ondemand_video, color: kGreen),
              label: 'Channel',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history, color: kGreen),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HOME SCREEN
// ============================================================
class HomeScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;
  const HomeScreen({super.key, this.onMenuTap});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _linkController = TextEditingController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111714),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: Supabase.instance.client
              .from('notifications')
              .select('*')
              .order('created_at', ascending: false),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: kGreen),
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center),
                ),
              );
            }
            final list = snapshot.data ?? [];
            if (list.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Text('Koi naya notification nahi hai', style: TextStyle(color: Colors.white70, fontSize: 15)),
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: const [
                      Icon(Icons.notifications_active, color: kGreen),
                      SizedBox(width: 8),
                      Text('Notifications', style: TextStyle(color: kGreen, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (c, i) {
                      final item = list[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text(item['title']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: Text(item['message']?.toString() ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
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

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _searchAndPlay() {
    String input = _linkController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste a stream URL first!'), backgroundColor: Color(0xFF031408)),
      );
      return;
    }
    _linkController.clear();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StreamPreviewScreen(targetUrl: input)),
    );
  }

  Widget _buildCategoryCard(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF031408),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGreen.withOpacity(0.4), width: 1.2),
        boxShadow: [BoxShadow(color: kGreen.withOpacity(0.08), blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: kGreen, size: 28),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 9.5), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, color: kGreen, size: 26),
                      onPressed: widget.onMenuTap,
                      tooltip: 'More Options',
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('maya', style: TextStyle(color: kGreen, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1, shadows: [Shadow(color: kGreen, blurRadius: 12)])),
                              Text('Jaal', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 22, fontWeight: FontWeight.w400, letterSpacing: 1)),
                            ],
                          ),
                          Text('VIDEOS  |  LINKS  |  BEYOND', style: TextStyle(color: kGreen.withOpacity(0.7), fontSize: 8, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: kGreen, size: 24),
                      onPressed: () => showSearch(context: context, delegate: UserSearchDelegate()),
                    ),
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_none, color: kGreen, size: 24),
                          onPressed: () => _showNotificationsSheet(context),
                        ),
                        Positioned(
                          right: 11,
                          top: 11,
                          child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 18,
                      child: Text('MOVIES\nWEB SERIES\nLIVE TV\n& MORE', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, height: 1.5)),
                    ),
                    Positioned(
                      right: 18,
                      child: Text('Your\nStreaming\nUniverse', style: TextStyle(color: const Color(0xFF66FF99).withOpacity(0.85), fontSize: 16, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic, height: 1.2)),
                    ),
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) => Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: kGreen.withOpacity(0.25), blurRadius: 40, spreadRadius: 10)],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(width: 130, height: 130, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kGreen.withOpacity(0.6), width: 1.5))),
                              Container(
                                width: 95,
                                height: 95,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: kGreen, width: 2),
                                  boxShadow: [BoxShadow(color: kGreen.withOpacity(0.5), blurRadius: 20)],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.asset(
                                    'assets/icon/logo.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(color: Colors.black, child: const Icon(Icons.movie_filter, size: 50, color: kGreen)),
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
                    boxShadow: [BoxShadow(color: kGreen.withOpacity(0.2), blurRadius: 25)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 14, top: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
                              Text('MATRIX NEURAL STREAM NODE', style: TextStyle(color: kGreen, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF031A0B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kGreen.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.link_rounded, color: kGreen, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: _linkController,
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        hintText: 'Paste Stream URL',
                                        hintStyle: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text('Enter your link and start streaming securely', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: _searchAndPlay,
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: kGreen,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: kGreen.withOpacity(0.6), blurRadius: 16)],
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 32),
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
                    Expanded(child: _buildCategoryCard(Icons.movie_creation_outlined, 'Movies', 'Latest & Classic')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildCategoryCard(Icons.live_tv_rounded, 'Web Series', 'Binge Watch')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildCategoryCard(Icons.tv_rounded, 'Live TV', 'Sports • News • More')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildCategoryCard(Icons.star_rounded, 'Favorites', 'Save & Watch Later')),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF031A0B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kGreen.withOpacity(0.55)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: kGreen, size: 20),
                      SizedBox(width: 10),
                      Expanded(child: Text('Secure Quantum Stream Pipeline Active', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                      Icon(Icons.arrow_forward_ios, color: kGreen, size: 14),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text('>   CONNECT   •   STREAM   •   ENJOY   <', style: TextStyle(color: Color(0xBF00FF66), fontSize: 10.5, letterSpacing: 2, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MORE DRAWER
// ============================================================
class MoreDrawer extends StatelessWidget {
  const MoreDrawer({super.key});

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    await GoogleSignIn().signOut();
    await MayaJaalAccount.unlink();
  }

  Future<void> _launchURL(String url) async {
    try {
      final target = Uri.parse(url);
      if (!await launchUrl(target, mode: LaunchMode.externalApplication)) {
        await launchUrl(target, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Launch error: $e');
      try { await launchUrl(Uri.parse(url)); } catch (_) {}
    }
  }

  void _shareApp() {
    Share.share('🚀 Experience Matrix-speed streaming on MayaJaal App!\nDownload: https://www.mayajaal.online/download.html');
  }

  void _showPolicyDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kGreen, width: 1.5)),
        title: Text(title, style: const TextStyle(color: kGreen, fontSize: 15, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Text(content, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4))),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('CLOSE', style: TextStyle(color: kGreen)))],
      ),
    );
  }

  void _showConnectApiDialog(BuildContext context) {
    final controller = TextEditingController();
    bool loading = false;
    String msg = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          backgroundColor: kCardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kGreen, width: 1.5)),
          title: Row(
            children: const [
              Icon(Icons.link, color: kGreen, size: 22),
              SizedBox(width: 8),
              Text('CONNECT MAYAJAAL', style: TextStyle(color: kGreen, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Paste your API key from mayajaal.online dashboard to unlock earnings, views & links.', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Paste API Key',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                  prefixIcon: const Icon(Icons.vpn_key, color: kGreen),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen)),
                ),
              ),
              if (msg.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(msg, style: TextStyle(color: msg.contains('✅') ? kGreen : Colors.redAccent, fontSize: 11)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: loading ? null : () async {
                setD(() { loading = true; msg = ''; });
                final res = await MayaJaalAccount.linkWithApiKey(controller.text.trim());
                if (res['success'] == true) {
                  setD(() => msg = '✅ Linked! ${res['email']}');
                  await Future.delayed(const Duration(milliseconds: 800));
                  if (c.mounted) Navigator.pop(c);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: kCardBg, content: Text('✅ Connected: ${res['email']}', style: const TextStyle(color: kGreen))),
                    );
                  }
                } else {
                  setD(() { loading = false; msg = '❌ ${res['error'] ?? 'Invalid key'}'; });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.black),
              child: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : const Text('CONNECT'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Drawer(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF011206),
                border: Border(bottom: BorderSide(color: kGreen.withOpacity(0.4), width: 1.2)),
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
                      boxShadow: [BoxShadow(color: kGreen.withOpacity(0.5), blurRadius: 12)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/icon/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(Icons.change_history, color: kGreen, size: 22),
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
                            Text('maya', style: TextStyle(color: kGreen, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5, shadows: [Shadow(color: kGreen, blurRadius: 10)])),
                            Text('Jaal', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w400, letterSpacing: 0.5)),
                          ],
                        ),
                        Text('MORE OPTIONS', style: TextStyle(color: kGreen.withOpacity(0.7), fontSize: 8.5, letterSpacing: 2, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: kGreen, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  Container(
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
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kGreen, width: 1.5)),
                          child: const Icon(Icons.person, color: kGreen, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                MayaJaalAccount.cachedEmail?.isNotEmpty == true ? MayaJaalAccount.cachedEmail! : (user?.email ?? 'Guest User'),
                                style: const TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.account_circle_outlined, color: kGreen.withOpacity(0.7), size: 10),
                                  const SizedBox(width: 3),
                                  Text('Matrix ID', style: TextStyle(color: kGreen.withOpacity(0.7), fontSize: 9)),
                                  const SizedBox(width: 8),
                                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle)),
                                  const SizedBox(width: 3),
                                  Text(MayaJaalAccount.isLinked ? 'Connected' : 'Not linked', style: TextStyle(color: kGreen.withOpacity(0.9), fontSize: 9)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (MayaJaalAccount.isLinked)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: kGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: kGreen)),
                            child: const Icon(Icons.verified, color: kGreen, size: 12),
                          ),
                      ],
                    ),
                  ),
                  _drawerItem(context, icon: Icons.link, color: kNeonCyan, title: MayaJaalAccount.isLinked ? 'Reconnect MayaJaal' : 'Connect MayaJaal', subtitle: 'Paste API key from website', onTap: () {
                    Navigator.pop(context);
                    _showConnectApiDialog(context);
                  }),
                  _drawerItem(context, icon: Icons.share, color: kNeonCyan, title: 'Share MayaJaal App', subtitle: 'Invite your friends and grow together', onTap: () {
                    Navigator.pop(context);
                    _shareApp();
                  }),
                  _drawerItem(context, icon: Icons.settings, color: kGreen, title: 'App Settings', subtitle: 'Customize your app experience', onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  }),
                  _drawerItem(context, icon: Icons.support_agent, color: Colors.amberAccent, title: 'Help & Support', subtitle: 'mayajaalsupport@gmail.com', onTap: () {
                    Navigator.pop(context);
                    _launchURL('mailto:mayajaalsupport@gmail.com?subject=MayaJaal%20Support%20Request');
                  }),
                  _drawerItem(context, icon: Icons.privacy_tip_outlined, color: kDimGreen, title: 'Privacy Policy', subtitle: 'Your data, our priority', onTap: () {
                    Navigator.pop(context);
                    _showPolicyDialog(context, 'PRIVACY POLICY', 'MayaJaal respects user privacy. No private credentials are sold or stored inappropriately. Stream decryption occurs locally on your hardware. Logins are handled securely via Supabase Google OAuth integration.');
                  }),
                  _drawerItem(context, icon: Icons.description_outlined, color: kDimGreen, title: 'Terms & Conditions', subtitle: 'Read before you continue', onTap: () {
                    Navigator.pop(context);
                    _showPolicyDialog(context, 'TERMS AND CONDITIONS', 'By utilizing MayaJaal, you agree to access encrypted streaming endpoints responsibly. Users are personally responsible for streams parsed through node references.');
                  }),
                  _drawerItem(context, icon: Icons.account_balance_wallet, color: kGreen, title: 'Earnings Dashboard', subtitle: 'View your earnings and links', onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EarningsScreen()));
                  }),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 18, bottom: 8),
                    child: Row(
                      children: [
                        Container(width: 14, height: 1.5, color: kGreen),
                        const SizedBox(width: 6),
                        const Text('JOIN US', style: TextStyle(color: kGreen, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        const SizedBox(width: 6),
                        Expanded(child: Container(height: 1, color: kGreen.withOpacity(0.3))),
                      ],
                    ),
                  ),
                  _drawerItem(context, icon: Icons.camera_alt, color: const Color(0xFFE1306C), title: 'Instagram Official', subtitle: '@maya_jaal_official', onTap: () {
                    Navigator.pop(context);
                    _launchURL('https://www.instagram.com/maya_jaal_official');
                  }),
                  _drawerItem(context, icon: Icons.play_circle_fill, color: Colors.redAccent, title: 'YouTube Channel', subtitle: '@MayaJaalOfficial00', onTap: () {
                    Navigator.pop(context);
                    _launchURL('https://www.youtube.com/@MayaJaalOfficial00');
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.logout, color: Colors.redAccent),
                        title: const Text('Logout Session', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                        onTap: () {
                          Navigator.pop(context);
                          _logout();
                        },
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

  Widget _drawerItem(
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
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10.5)),
        trailing: Icon(Icons.arrow_forward_ios, color: color, size: 14),
        onTap: onTap,
      ),
    );
  }
}

// ========================= PART 1 END =========================
// ============================================================
// CHANNEL SCREEN
// ============================================================
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
              title: Text('Quantum Streaming Node', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('Direct hardware pipeline active', style: TextStyle(color: kDimGreen, fontSize: 12)),
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
              title: Text('High Speed CDN Node', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('Buffer acceleration: ENABLED', style: TextStyle(color: kNeonCyan, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HISTORY SCREEN
// ============================================================
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
        setState(() => _history = decoded.cast<Map<String, dynamic>>());
      } catch (_) {}
    }
  }

  Future<void> _deleteItem(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _history.removeAt(index));
    await prefs.setString('watch_history_v2', jsonEncode(_history));
  }

  Future<void> _clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('watch_history_v2');
    setState(() => _history = []);
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
                    leading: const Icon(Icons.play_circle_outline, color: kGreen),
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
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                      onPressed: () => _deleteItem(i),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => StreamPreviewScreen(targetUrl: item['url'])),
                      ).then((_) => _loadHistory());
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================
// SETTINGS SCREEN
// ============================================================
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_theme', value);
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
    setState(() => _darkTheme = value);
  }

  Future<void> _saveLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', value);
    languageNotifier.value = value;
    setState(() => _language = value);
  }

  Future<void> _saveDownloadLocation(String value) async {
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
            subtitle: Text(_darkTheme ? 'Matrix Cyber Neon' : 'Standard Light', style: TextStyle(color: kGreen.withOpacity(0.6), fontSize: 12)),
            trailing: Switch(value: _darkTheme, activeColor: kGreen, onChanged: _saveDarkTheme),
          ),
          Divider(color: kGreen.withOpacity(0.2)),
          ListTile(
            leading: const Icon(Icons.language, color: kGreen),
            title: Text(tr('language'), style: const TextStyle(color: kGreen)),
            subtitle: Text(_language, style: TextStyle(color: kGreen.withOpacity(0.6), fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: kGreen),
            onTap: () => _showLanguageDialog(),
          ),
          Divider(color: kGreen.withOpacity(0.2)),
          ListTile(
            leading: const Icon(Icons.download, color: kGreen),
            title: Text(tr('download_location'), style: const TextStyle(color: kGreen)),
            subtitle: Text(_downloadLocation, style: TextStyle(color: kGreen.withOpacity(0.6), fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: kGreen),
            onTap: () => _showDownloadLocationDialog(),
          ),
          Divider(color: kGreen.withOpacity(0.2)),
          const SizedBox(height: 30),
          Center(
            child: Text('> MayaJaal v1.1.1 // Core Matrix Node', style: TextStyle(color: kGreen.withOpacity(0.5), fontSize: 12)),
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

// ============================================================
// STREAM PREVIEW SCREEN — 10 second countdown
// ============================================================
class StreamPreviewScreen extends StatefulWidget {
  final String targetUrl;
  const StreamPreviewScreen({super.key, required this.targetUrl});
  @override
  State<StreamPreviewScreen> createState() => _StreamPreviewScreenState();
}

class _StreamPreviewScreenState extends State<StreamPreviewScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  String _streamUrl = '';
  String _videoTitle = 'MayaJaal Video';
  String _uploaderName = '@mayajaal';
  String _rawId = '';

  int _countdown = 10;
  Timer? _countdownTimer;
  bool get _canProceed => _countdown <= 0;

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
    _fetchStreamMetadata();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdown = 10;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _countdownTimer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchStreamMetadata() async {
    try {
      final uri = Uri.parse(widget.targetUrl);
      _rawId = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'stream';
      final token = uri.queryParameters['t'] ?? uri.queryParameters['s'] ?? '';

      if (widget.targetUrl.endsWith('.mp4') || widget.targetUrl.endsWith('.m3u8')) {
        setState(() {
          _streamUrl = widget.targetUrl;
          _videoTitle = _rawId;
          _loading = false;
        });
        _startCountdown();
        return;
      }

      final apiUrl = token.isNotEmpty
          ? '$kBackendBaseUrl/api/stream-info/$_rawId?t=$token'
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
          _startCountdown();
          return;
        }
      }

      final res2 = await http.get(Uri.parse('$kBackendBaseUrl/api/v/$_rawId?t=$token')).timeout(const Duration(seconds: 8));
      if (res2.statusCode == 200) {
        final data = jsonDecode(res2.body);
        setState(() {
          _streamUrl = widget.targetUrl;
          _videoTitle = data['name'] ?? _rawId;
          _loading = false;
        });
        _startCountdown();
        return;
      }

      setState(() {
        _streamUrl = widget.targetUrl;
        _loading = false;
      });
      _startCountdown();
    } catch (e) {
      setState(() {
        _streamUrl = widget.targetUrl;
        _loading = false;
      });
      _startCountdown();
    }
  }

  void _shareStreamDirect() {
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
    _saveWatchRecord();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NativeVideoPlayerScreen(
          videoUrl: _streamUrl,
          title: _videoTitle,
          uploader: _uploaderName,
          sourcePageUrl: widget.targetUrl,
          videoId: _rawId,
        ),
      ),
    );
  }

  Widget _buildCountdownCircle() {
    final progress = 1.0 - (_countdown / 10.0);
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 140,
            height: 140,
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
                _canProceed ? Icons.play_arrow_rounded : Icons.timer,
                color: _canProceed ? kGreen : Colors.orangeAccent,
                size: 44,
              ),
              const SizedBox(height: 4),
              Text(
                _canProceed ? 'READY' : '$_countdown',
                style: TextStyle(
                  color: _canProceed ? kGreen : Colors.orangeAccent,
                  fontSize: _canProceed ? 20 : 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(color: (_canProceed ? kGreen : Colors.orangeAccent).withOpacity(0.7), blurRadius: 15),
                  ],
                ),
              ),
              if (!_canProceed)
                Text(
                  'SEC',
                  style: TextStyle(color: Colors.orangeAccent.withOpacity(0.8), fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: kGreen, size: 22),
                        onPressed: () => Navigator.pop(context),
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
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF011206),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _canProceed ? kGreen : Colors.orangeAccent.withOpacity(0.6), width: 1.8),
                      boxShadow: [
                        BoxShadow(color: (_canProceed ? kGreen : Colors.orangeAccent).withOpacity(0.25), blurRadius: 30),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildCountdownCircle(),
                        const SizedBox(height: 20),
                        Text(
                          _canProceed ? '🚀 VIDEO READY TO PLAY' : '⏱ PLEASE WAIT',
                          style: TextStyle(
                            color: _canProceed ? kGreen : Colors.orangeAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _canProceed
                              ? 'Tap the button below to start streaming'
                              : 'Video unlocks in $_countdown seconds',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13, height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: 1.0 - (_countdown / 10.0),
                            minHeight: 8,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation<Color>(_canProceed ? kGreen : Colors.orangeAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(color: kGreen.withOpacity(0.15))),
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
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) => Transform.scale(
                      scale: _canProceed ? _pulseAnimation.value : 1.0,
                      child: SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _canProceed ? _launchNativePlayer : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _canProceed ? kGreen : Colors.grey[850],
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: _canProceed ? 15 : 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: _canProceed ? Colors.black : Colors.white38, size: 28),
                              const SizedBox(width: 8),
                              Text(
                                _canProceed ? 'OPEN PLAYER NOW' : 'PLEASE WAIT...',
                                style: TextStyle(
                                  color: _canProceed ? Colors.black : Colors.white38,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _shareStreamDirect,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kGreen, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
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
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline, color: kGreen, size: 14),
                      const SizedBox(width: 6),
                      Text('SECURE STREAM PIPELINE ACTIVE', style: TextStyle(color: kGreen.withOpacity(0.75), fontSize: 9.5, letterSpacing: 1.2)),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// NATIVE VIDEO PLAYER — reports view after 10 sec
// ============================================================
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
  final SupabaseService _supabaseService = SupabaseService();

  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  bool _isFullscreen = false;
  String _flashFeedback = '';
  Timer? _feedbackTimer;

  bool _showControls = true;
  Timer? _controlsTimer;

  bool _isCcEnabled = false;
  double _playbackSpeed = 1.0;
  final List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  String _selectedQuality = 'Auto (1080p)';
  final List<String> _qualities = ['Auto (1080p)', '1080p FHD', '720p HD', '480p SD', '360p Low'];

  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  int _viewsCount = 0;
  int _likesCount = 0;
  int _unlikesCount = 0;
  int _sharesCount = 0;
  bool _isLiked = false;
  bool _isUnliked = false;
  bool _isSaved = false;

  bool _viewReported = false;
  Timer? _viewReportTimer;

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

      final res = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'playedSeconds': 10,
              'deviceId': deviceId,
              'token': token,
            }),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('View report: ${res.statusCode} ${res.body}');
    } catch (e) {
      debugPrint('View report error: $e');
    }
  }

  void _startViewTrackingTimer() {
    _viewReportTimer?.cancel();
    _viewReportTimer = Timer(const Duration(seconds: 10), () async {
      if (!mounted) return;
      if (_controller.value.isInitialized && _controller.value.isPlaying) {
        await _reportViewToBackend();
        _fetchBackendStats();
      }
    });
  }

  Future<void> _fetchBackendStats() async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref('links/${widget.videoId}')
          .once()
          .timeout(const Duration(seconds: 4));
      final data = snap.snapshot.value;
      if (data != null && data is Map) {
        if (mounted) {
          setState(() {
            _viewsCount = (data['views'] ?? _viewsCount) as int;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _fetchRealStatsAndRegisterView();
    _initFastVideo();
  }

  Future<void> _fetchRealStatsAndRegisterView() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLiked = prefs.getBool('liked_${widget.videoId}') ?? false;
      _isUnliked = prefs.getBool('unliked_${widget.videoId}') ?? false;
      _isSaved = prefs.getBool('saved_${widget.videoId}') ?? false;
      await _fetchBackendStats();
    } catch (_) {}
  }

  Future<void> _sendStatUpdate(String action) async {
    try {
      await http.post(
        Uri.parse('$kBackendBaseUrl/api/stats/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'video_id': widget.videoId, 'action': action}),
      );
    } catch (_) {}
  }

  Future<void> _initFastVideo() async {
    final Map<String, String> headers = {
      'User-Agent': 'MayaJaalApp/1.0',
      'Referer': 'https://www.mayajaal.online/',
    };

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      httpHeaders: headers,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await _controller.initialize();
      _controller.play();
      _controller.setPlaybackSpeed(_playbackSpeed);

      _controller.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() => _isInitialized = true);
      _resetControlTimer();
      _startViewTrackingTimer();
    } catch (e) {
      debugPrint("Player Init Error: $e");
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _feedbackTimer?.cancel();
    _viewReportTimer?.cancel();
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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

  void _seekRelative(int seconds) {
    final current = _controller.value.position;
    final target = current + Duration(seconds: seconds);
    final total = _controller.value.duration;

    if (target < Duration.zero) {
      _controller.seekTo(Duration.zero);
    } else if (target > total) {
      _controller.seekTo(total);
    } else {
      _controller.seekTo(target);
    }
    _showFeedback(seconds > 0 ? '+10s' : '-10s');
    _resetControlTimer();
  }

  void _toggleSmartFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    final isWide = _controller.value.aspectRatio >= 1.2;

    if (_isFullscreen) {
      if (isWide) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours > 0 ? '${d.inHours}:' : '';
    return '$h$m:$s';
  }

  Future<void> _shareVideoLink() async {
    setState(() => _sharesCount++);
    _sendStatUpdate('share');
    try {
      await Supabase.instance.client.from('notifications').insert({
        'title': '🚀 Video Shared!',
        'message': 'Someone shared: ${widget.title}',
      });
    } catch (_) {}
    Share.share('🎬 Watch this video on MayaJaal:\n${widget.sourcePageUrl}');
  }

  Future<void> _startInAppDownload() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(widget.videoUrl));
      final response = await request.close();

      final totalBytes = response.contentLength;
      int receivedBytes = 0;

      Directory baseDir = Directory('/storage/emulated/0/Download');
      if (!baseDir.existsSync()) {
        baseDir = Directory('/storage/emulated/0/Movies');
      }
      if (!baseDir.existsSync()) {
        baseDir = Directory.systemTemp;
      }

      final safeName = widget.title.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final savePath = '${baseDir.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final file = File(savePath);
      final sink = file.openWrite();

      await response.listen((List<int> chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && mounted) {
          setState(() {
            _downloadProgress = receivedBytes / totalBytes;
          });
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

  Future<void> _toggleLike() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likesCount = math.max(0, _likesCount - 1);
        prefs.setBool('liked_${widget.videoId}', false);
      } else {
        _isLiked = true;
        _likesCount++;
        prefs.setBool('liked_${widget.videoId}', true);
        if (_isUnliked) {
          _isUnliked = false;
          _unlikesCount = math.max(0, _unlikesCount - 1);
          prefs.setBool('unliked_${widget.videoId}', false);
        }
      }
    });

    _sendStatUpdate(_isLiked ? 'like' : 'unlike_dec');
  }

  Future<void> _toggleUnlike() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_isUnliked) {
        _isUnliked = false;
        _unlikesCount = math.max(0, _unlikesCount - 1);
        prefs.setBool('unliked_${widget.videoId}', false);
      } else {
        _isUnliked = true;
        _unlikesCount++;
        _sendStatUpdate('unlike');
        prefs.setBool('unliked_${widget.videoId}', true);
        if (_isLiked) {
          _isLiked = false;
          _likesCount = math.max(0, _likesCount - 1);
          prefs.setBool('liked_${widget.videoId}', false);
        }
      }
    });
  }

  Future<void> _toggleSave() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSaved = !_isSaved;
      prefs.setBool('saved_${widget.videoId}', _isSaved);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isSaved ? 'Video Saved to Favorites' : 'Removed from Favorites'), duration: const Duration(seconds: 1)),
    );
  }

  void _showQualityDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF031408),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: kGreen, width: 1.5)),
        title: Row(
          children: const [
            Icon(Icons.hd, color: kGreen, size: 24),
            SizedBox(width: 8),
            Text('SELECT QUALITY', style: TextStyle(color: kGreen, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
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
                  setState(() => _selectedQuality = val);
                  Navigator.pop(c);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: const Color(0xFF031408), content: Text('Switched stream quality to $val', style: const TextStyle(color: kGreen)), duration: const Duration(seconds: 1)),
                  );
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showSpeedDialog() {
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

  Widget _buildSmartScaledVideo() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            if (!_isFullscreen)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: kGreen, size: 22),
                      onPressed: () => Navigator.pop(context),
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
                              const Text(
                                'MAYA JAAL',
                                style: TextStyle(color: kGreen, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 2, shadows: [Shadow(color: kGreen, blurRadius: 10)]),
                              ),
                            ],
                          ),
                          Text(
                            '— STREAM BEYOND LIMITS —',
                            style: TextStyle(color: kGreen.withOpacity(0.8), fontSize: 8.5, letterSpacing: 2, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: kGreen, size: 22),
                      onPressed: _shareVideoLink,
                    ),
                  ],
                ),
              ),
            Expanded(
              flex: _isFullscreen ? 1 : 0,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: _isFullscreen ? 0 : 12, vertical: 4),
                child: Container(
                  width: double.infinity,
                  height: _isFullscreen ? double.infinity : 225,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(_isFullscreen ? 0 : 16),
                    border: Border.all(color: kGreen.withOpacity(0.55), width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_isFullscreen ? 0 : 15),
                    child: _hasError
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 45),
                                const SizedBox(height: 10),
                                const Text('Stream Connection Error', style: TextStyle(color: Colors.redAccent)),
                                TextButton(onPressed: _initFastVideo, child: const Text('RETRY', style: TextStyle(color: kGreen))),
                              ],
                            ),
                          )
                        : !_isInitialized
                            ? const Center(child: CircularProgressIndicator(color: kGreen))
                            : GestureDetector(
                                onTap: _onScreenTapped,
                                behavior: HitTestBehavior.opaque,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    _buildSmartScaledVideo(),
                                    Positioned(
                                      top: 10,
                                      left: 10,
                                      child: GestureDetector(
                                        onTap: _showQualityDialog,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: kGreen, width: 1),
                                          ),
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
                                    if (_showControls)
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _controller.value.isPlaying ? _controller.pause() : _controller.play();
                                          });
                                          _resetControlTimer();
                                        },
                                        child: Container(
                                          width: 58,
                                          height: 58,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.55),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                          child: Icon(
                                            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                            color: Colors.white,
                                            size: 34,
                                          ),
                                        ),
                                      ),
                                    if (_flashFeedback.isNotEmpty)
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(10)),
                                          child: Text(_flashFeedback, style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 20)),
                                        ),
                                      ),
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
                                              data: SliderTheme.of(context).copyWith(
                                                trackHeight: 2.5,
                                                activeTrackColor: kGreen,
                                                inactiveTrackColor: Colors.white30,
                                                thumbColor: kGreen,
                                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                                              ),
                                              child: Slider(
                                                value: _controller.value.position.inSeconds.toDouble().clamp(
                                                      0.0,
                                                      _controller.value.duration.inSeconds.toDouble() <= 0 ? 1.0 : _controller.value.duration.inSeconds.toDouble(),
                                                    ),
                                                min: 0.0,
                                                max: _controller.value.duration.inSeconds.toDouble() > 0 ? _controller.value.duration.inSeconds.toDouble() : 1.0,
                                                onChanged: (val) {
                                                  _controller.seekTo(Duration(seconds: val.toInt()));
                                                },
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
                              ),
                  ),
                ),
              ),
            ),
            if (!_isFullscreen)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF031408),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kGreen.withOpacity(0.55)),
                        ),
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
                                Text('|   👁 $_viewsCount views', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: _toggleLike,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: _isLiked ? kGreen : kGreen.withOpacity(0.4)),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(_isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined, color: kGreen, size: 14),
                                              const SizedBox(width: 4),
                                              Text('$_likesCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
                                    onTap: _toggleUnlike,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: _isUnliked ? Colors.redAccent : kGreen.withOpacity(0.4)),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(_isUnliked ? Icons.thumb_down : Icons.thumb_down_alt_outlined, color: Colors.redAccent, size: 14),
                                              const SizedBox(width: 4),
                                              Text('$_unlikesCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: _isSaved ? kGreen : kGreen.withOpacity(0.4)),
                                      ),
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
                                InkWell(
                                  onTap: _startInAppDownload,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(10)),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.download, color: Colors.black, size: 18),
                                        const SizedBox(width: 4),
                                        Text(
                                          _isDownloading ? '${(_downloadProgress * 100).toInt()}%' : 'Download',
                                          style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF031408),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kGreen.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(3)),
                              child: const Text('AD', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('YOUR AD HERE', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  Text('Grow Your Brand with Us', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
                                ],
                              ),
                            ),
                            const Icon(Icons.campaign_outlined, color: kGreen, size: 28),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Row(
                        children: [
                          Icon(Icons.play_circle_outline, color: kGreen, size: 18),
                          SizedBox(width: 6),
                          Text('Related Videos', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          Spacer(),
                          Text('More Videos >', style: TextStyle(color: kGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 130,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildRelatedCard('Jaisalmer Tour Part 1', '@travel123', '05:42'),
                            const SizedBox(width: 10),
                            _buildRelatedCard('Jaisalmer Desert Ride', '@travel123', '08:15'),
                            const SizedBox(width: 10),
                            _buildRelatedCard('Jaisalmer Fort View', '@travel123', '06:30'),
                          ],
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
    );
  }

  Widget _buildRelatedCard(String title, String user, String duration) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: const Color(0xFF031408),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGreen.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 80,
                decoration: const BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: const Center(child: Icon(Icons.image, color: Colors.white30, size: 30)),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                  child: Text(duration, style: const TextStyle(color: Colors.white, fontSize: 8)),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1),
                Text(user, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SUPABASE SERVICE
// ============================================================
class SupabaseService {
  final SupabaseClient client = Supabase.instance.client;

  Future<void> recordView(int videoId) async {
    try {
      await client.rpc('increment_views', params: {'row_id': videoId});
    } catch (_) {}
  }

  Future<void> likeVideo(int videoId) async {
    try {
      await client.rpc('increment_likes', params: {'row_id': videoId});
    } catch (_) {}
  }

  Future<void> unlikeVideo(int videoId) async {
    try {
      await client.rpc('decrement_likes', params: {'row_id': videoId});
    } catch (_) {}
  }

  Future<void> recordShare(int videoId) async {
    try {
      await client.rpc('increment_shares', params: {'row_id': videoId});
    } catch (_) {}
  }

  Future<int> getViewCount(int videoId) async {
    try {
      final res = await client.from('videos').select('views').eq('id', videoId).maybeSingle();
      return (res?['views'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getLikeCount(int videoId) async {
    try {
      final res = await client.from('videos').select('likes').eq('id', videoId).maybeSingle();
      return (res?['likes'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getShareCount(int videoId) async {
    try {
      final res = await client.from('videos').select('shares').eq('id', videoId).maybeSingle();
      return (res?['shares'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final res = await client
          .from('profiles')
          .select('id, username, display_name, avatar_url')
          .ilike('username', '%$query%')
          .limit(15);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  Future<bool> isSubscribed(String channelId) async {
    final user = client.auth.currentUser;
    if (user == null) return false;
    try {
      final res = await client
          .from('subscriptions')
          .select('id')
          .eq('subscriber_id', user.id)
          .eq('channel_id', channelId)
          .maybeSingle();
      return res != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleSubscription(String channelId) async {
    final user = client.auth.currentUser;
    if (user == null) return false;
    final alreadySubscribed = await isSubscribed(channelId);
    try {
      if (alreadySubscribed) {
        await client
            .from('subscriptions')
            .delete()
            .eq('subscriber_id', user.id)
            .eq('channel_id', channelId);
        return false;
      } else {
        await client.from('subscriptions').insert({
          'subscriber_id': user.id,
          'channel_id': channelId,
        });
        try {
          await client.from('notifications').insert({
            'title': '🔔 New Subscriber!',
            'message': 'Someone subscribed to your channel.',
          });
        } catch (_) {}
        return true;
      }
    } catch (_) {
      return alreadySubscribed;
    }
  }

  Future<List<Map<String, dynamic>>> getUserUploads(String targetUserId) async {
    try {
      final res = await client
          .from('videos')
          .select('*')
          .eq('uploader_id', targetUserId)
          .order('id', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }
}

// ============================================================
// USER SEARCH DELEGATE
// ============================================================
class UserSearchDelegate extends SearchDelegate {
  final SupabaseService service = SupabaseService();

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white54),
        border: InputBorder.none,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear, color: kGreen),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back, color: kGreen),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    return Container(
      color: Colors.black,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: service.searchUsers(query),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kGreen));
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(
              child: Text('No users found', style: TextStyle(color: Colors.white54)),
            );
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, i) {
              final u = users[i];
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: kGreen,
                  child: Icon(Icons.person, color: Colors.black),
                ),
                title: Text(u['display_name'] ?? u['username'] ?? '', style: const TextStyle(color: Colors.white)),
                subtitle: Text('@${u['username']}', style: const TextStyle(color: kGreen)),
                onTap: () {
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

// ============================================================
// USER PROFILE SCREEN
// ============================================================
class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> channelProfile;
  const UserProfileScreen({super.key, required this.channelProfile});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final SupabaseService _service = SupabaseService();
  bool _isSubscribed = false;
  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final channelId = widget.channelProfile['id']?.toString() ?? '';
    final subStatus = await _service.isSubscribed(channelId);
    final uploads = await _service.getUserUploads(channelId);

    if (mounted) {
      setState(() {
        _isSubscribed = subStatus;
        _videos = uploads;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwnProfile = currentUserId == widget.channelProfile['id']?.toString();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('@${widget.channelProfile['username'] ?? 'Profile'}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : Column(
              children: [
                const SizedBox(height: 20),
                const CircleAvatar(
                  radius: 38,
                  backgroundColor: kGreen,
                  child: Icon(Icons.person, size: 45, color: Colors.black),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.channelProfile['display_name'] ?? widget.channelProfile['username'] ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '@${widget.channelProfile['username']}',
                  style: const TextStyle(color: kGreen, fontSize: 13),
                ),
                const SizedBox(height: 14),
                if (!isOwnProfile)
                  ElevatedButton(
                    onPressed: () async {
                      final status = await _service.toggleSubscription(widget.channelProfile['id']?.toString() ?? '');
                      setState(() => _isSubscribed = status);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSubscribed ? Colors.grey[850] : kGreen,
                      foregroundColor: _isSubscribed ? Colors.white : Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(_isSubscribed ? 'SUBSCRIBED' : 'SUBSCRIBE'),
                  ),
                const Divider(color: Colors.white24, height: 30),
                Expanded(
                  child: _videos.isEmpty
                      ? const Center(child: Text('No uploads yet.', style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          itemCount: _videos.length,
                          itemBuilder: (context, i) {
                            final vid = _videos[i];
                            return ListTile(
                              leading: const Icon(Icons.play_circle_fill, color: kGreen),
                              title: Text(vid['title'] ?? 'Video', style: const TextStyle(color: Colors.white)),
                              subtitle: Text('${vid['views'] ?? 0} views', style: const TextStyle(color: Colors.white54)),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StreamPreviewScreen(targetUrl: vid['video_url'] ?? ''),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ============================================================
// EARNINGS SCREEN — RTDB Sync (same as website/bot)
// ============================================================
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  bool _loading = true;
  Map<String, dynamic> _dashboard = {};
  List<Map<String, dynamic>> _links = [];
  double _totalIncome = 0;
  int _currentTier = 1;
  double _currentRate = 1.0;
  int _nextBoost = 1000;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (!MayaJaalAccount.isLinked) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final dash = await MayaJaalAccount.getDashboard();
      final links = await MayaJaalAccount.getUserLinks(limit: 50);

      final views = (dash['totalViews'] ?? 0) as int;
      final income = MayaJaalAccount.calcEarnings(views);
      final tierInfo = MayaJaalAccount.getTierInfo(views);

      if (mounted) {
        setState(() {
          _dashboard = dash;
          _links = links;
          _totalIncome = income;
          _currentTier = (tierInfo['tier'] ?? 1) as int;
          _currentRate = (tierInfo['rate'] ?? 1.0) as double;
          _nextBoost = (tierInfo['next'] ?? 0) as int;
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
              setState(() => _loading = true);
              _loadData();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : !MayaJaalAccount.isLinked
              ? _buildNotLinked()
              : _buildDashboard(),
    );
  }

  Widget _buildNotLinked() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_off, color: Colors.orangeAccent, size: 60),
            const SizedBox(height: 16),
            const Text(
              'ACCOUNT NOT LINKED',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'To view your earnings, connect your MayaJaal account using the API key from the website.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MainNavigationHolder()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: kCardBg,
                    content: Text('Open menu → Connect MayaJaal', style: TextStyle(color: kGreen)),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              icon: const Icon(Icons.link, color: Colors.black),
              label: const Text('GO CONNECT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
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
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kGreen.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: kGreen, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CONNECTED ACCOUNT', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1.5)),
                        const SizedBox(height: 2),
                        Text(
                          MayaJaalAccount.cachedEmail ?? 'N/A',
                          style: const TextStyle(color: kGreen, fontSize: 13, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF031408),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kGreen, width: 1.5),
                boxShadow: [BoxShadow(color: kGreen.withOpacity(0.15), blurRadius: 20)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL BALANCE', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${_totalIncome.toStringAsFixed(2)}',
                        style: const TextStyle(color: kGreen, fontSize: 40, fontWeight: FontWeight.w900, shadows: [Shadow(color: kGreen, blurRadius: 20)]),
                      ),
                    ],
                  ),
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
              decoration: BoxDecoration(
                color: const Color(0xFF031408),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 20),
                      const SizedBox(width: 8),
                      Text('TIER $(_currentTier)', style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
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
                  const Text(
                    'Base: 1K views = \$1 · Every 2K views → rate × 1.5',
                    style: TextStyle(color: Colors.white54, fontSize: 10.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('YOUR LINKS', style: TextStyle(color: kGreen, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            _links.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGreen.withOpacity(0.3)),
                    ),
                    child: const Center(
                      child: Text('No links yet. Upload a video in the bot to get started.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                  )
                : Column(
                    children: _links.map((link) {
                      final views = (link['views'] ?? 0) as int;
                      final earnings = MayaJaalAccount.calcEarnings(views);
                      final name = (link['filename'] ?? link['originalUrl'] ?? 'link').toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kCardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGreen.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: kGreen.withOpacity(0.5)),
                              ),
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
              decoration: BoxDecoration(
                color: const Color(0xFF031408),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kGreen.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: kGreen, size: 16),
                      SizedBox(width: 6),
                      Text('WITHDRAWAL INFO', style: TextStyle(color: kGreen, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('Minimum: \$20 (≈₹1,600)', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
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
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kGreen.withOpacity(0.2)),
      ),
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
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
      ),
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
