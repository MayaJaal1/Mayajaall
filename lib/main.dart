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

const String supabaseUrl = 'https://inxlnctaixbkfblwlmhr.supabase.co';
const String supabaseAnonKey = 'sb_publishable_6b9xe3mDBduO-soZTk3t2A_W1sQpD5K';
const String webClientId = '985001671962-rok8qnng0rumjsd8mgr8uhr92o5vhs4n.apps.googleusercontent.com';

const int kAppCurrentVersionCode = 2;
const String kBackendBaseUrl = 'https://mayajaal.online';

const Color kGreen = Color(0xFF00FF41);
const Color kNeonCyan = Color(0xFF00F0FF);
const Color kNeonPurple = Color(0xFF9D00FF);
const Color kBg = Color(0xFF000000);
const Color kCardBg = Color(0xFF0A0A0A);
const Color kDimGreen = Color(0xFF4FBF8B);

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<String> languageNotifier = ValueNotifier('English');
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 🌐 MULTI-LANGUAGE DICTIONARY
final Map<String, Map<String, String>> localizedStrings = {
  'English': {
    'app_title': 'MAYA JAAL',
    'paste_hint': 'Paste Mayajaal link here...',
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
    'init_stream': '⚡ INITIALIZE NEURAL STREAM',
    'stream_ready': 'STREAM READY FOR DECRYPTION',
    'download': 'DOWNLOAD VIDEO',
    'share': 'SHARE VIDEO',
    'uploader': 'UPLOADER',
    'filename': 'FILE NAME',
  },
  'Hindi': {
    'app_title': 'माया जाल',
    'paste_hint': 'यहाँ मायाजाल लिंक पेस्ट करें...',
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
    'init_stream': '⚡ स्ट्रीम शुरू करें (OPEN NOW)',
    'stream_ready': 'वीडियो चलने के लिए तैयार है',
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_theme') ?? true;
  final lang = prefs.getString('language') ?? 'English';
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  languageNotifier.value = lang;
  runApp(const MyApp());
}
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  String? _incomingUrl;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  Future<void> _initDeepLinks() async {
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handleLink(initialUri);
    } catch (e) {
      debugPrint("Initial link error: $e");
    }
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) => _handleLink(uri),
      onError: (err) => debugPrint("Link stream error: $err"),
    );
  }

  void _handleLink(Uri uri) {
    String finalUrl = uri.toString();
    if (uri.scheme == 'mayajaall' && uri.queryParameters.containsKey('url')) {
      finalUrl = uri.queryParameters['url']!;
    }
    setState(() {
      _incomingUrl = finalUrl;
      _showSplash = false;
    });

    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => StreamPreviewScreen(targetUrl: finalUrl),
        ),
      );
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  ThemeData _buildTheme(bool isDark) {
    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: isDark ? kBg : const Color(0xFFF3F4F6),
      colorScheme: ColorScheme.fromSeed(
        seedColor: kGreen,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      useMaterial3: true,
      fontFamily: 'monospace',
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? kBg : Colors.white,
        foregroundColor: isDark ? kGreen : Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              themeMode: mode,
              theme: _buildTheme(false),
              darkTheme: _buildTheme(true),
              home: _showSplash
                  ? const SplashScreen()
                  : (_incomingUrl == null
                      ? const AuthGate()
                      : StreamPreviewScreen(targetUrl: _incomingUrl!)),
            );
          },
        );
      },
    );
  }
}

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
    _timer = Timer.periodic(const Duration(milliseconds: 60), (_) {
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
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _a = Tween<double>(begin: 0.6, end: 1.0).animate(
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
      backgroundColor: kBg,
      body: Stack(
        children: [
          const MatrixRain(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _a,
                  builder: (c, _) => Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kGreen.withOpacity(0.4 * _a.value),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.movie_filter, size: 80, color: kGreen),
                  ),
                ),
                const SizedBox(height: 30),
                AnimatedBuilder(
                  animation: _a,
                  builder: (c, _) => Text(
                    'MAYA JAAL',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: kGreen,
                      fontFamily: 'monospace',
                      letterSpacing: 8,
                      shadows: [
                        Shadow(color: kGreen.withOpacity(_a.value), blurRadius: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '> initializing secure channel...',
                  style: TextStyle(
                    fontSize: 12,
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

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: kBg,
            body: Center(child: CircularProgressIndicator(color: kGreen)),
          );
        }
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) return const HomeScreen();
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String _error = '';

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
        accessToken: googleAuth.accessToken,
      );
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          const MatrixRain(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: kCardBg.withOpacity(0.9),
                    border: Border.all(color: kGreen.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: kGreen.withOpacity(0.2), blurRadius: 30),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: kGreen, width: 2),
                        ),
                        child: const Icon(Icons.movie_filter, size: 50, color: kGreen),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'MAYA JAAL',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: kGreen,
                          fontFamily: 'monospace',
                          letterSpacing: 6,
                          shadows: [Shadow(color: kGreen, blurRadius: 15)],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '> secure neural node access',
                        style: TextStyle(
                          fontSize: 11,
                          color: kGreen.withOpacity(0.7),
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _signInWithGoogle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGreen,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login, size: 22),
                                    SizedBox(width: 10),
                                    Text(
                                      'SIGN IN WITH GOOGLE',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            border: Border.all(color: Colors.red),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _error,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
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
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _linkController = TextEditingController();
  List<Map<String, dynamic>> _history = [];
  bool _permissionsChecked = false;

  @override
  void initState() {
    super.initState();
    _syncWatchHistory();
    Future.delayed(const Duration(seconds: 1), () => _requestPermissions());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkServerForUpdate();
    });
  }

  Future<void> _syncWatchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final user = Supabase.instance.client.auth.currentUser;
    final localJson = prefs.getString('watch_history_v2');

    if (localJson != null) {
      try {
        final List decoded = jsonDecode(localJson);
        setState(() => _history = decoded.cast<Map<String, dynamic>>());
      } catch (_) {}
    }

    if (user != null) {
      try {
        final res = await http.get(Uri.parse('$kBackendBaseUrl/api/history/${user.id}'));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['success'] == true && data['history'] is List) {
            final cloudList = (data['history'] as List).cast<Map<String, dynamic>>();
            setState(() => _history = cloudList);
            await prefs.setString('watch_history_v2', jsonEncode(cloudList));
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _deleteHistoryItem(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _history.removeAt(index));
    await prefs.setString('watch_history_v2', jsonEncode(_history));
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('watch_history_v2');
    setState(() => _history = []);
  }

  Future<void> _checkServerForUpdate() async {
    try {
      final res = await http.get(Uri.parse('$kBackendBaseUrl/version.json'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final int latestCode = data['latestVersionCode'] ?? 1;
        final String updateUrl = data['updateUrl'] ?? '$kBackendBaseUrl/download.html';
        final String changelog = data['changelog'] ?? 'New version available with fixes!';

        if (latestCode > kAppCurrentVersionCode && mounted) {
          _showUpdateNotice(updateUrl, changelog);
        }
      }
    } catch (_) {}
  }

  void _showUpdateNotice(String url, String info) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (c) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: kGreen, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: kGreen),
            const SizedBox(width: 8),
            Text(
              tr('update_available'),
              style: const TextStyle(color: kGreen, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info, style: const TextStyle(color: Colors.white, fontSize: 13)),
            const SizedBox(height: 12),
            Text('> Direct node build ready.', style: TextStyle(color: kDimGreen.withOpacity(0.9), fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr('later'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.pop(c);
              final target = Uri.parse(url);
              if (await canLaunchUrl(target)) {
                await launchUrl(target, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(tr('update_now'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermissions() async {
    if (_permissionsChecked) return;
    _permissionsChecked = true;
    if (!await Permission.notification.isGranted) await Permission.notification.request();
    if (!await Permission.storage.isGranted) await Permission.storage.request();
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    await GoogleSignIn().signOut();
  }
    void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kGreen.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '> OPTIONS',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kGreen, letterSpacing: 3),
            ),
            Divider(color: kGreen.withOpacity(0.3)),
            ListTile(
              leading: const Icon(Icons.settings, color: kGreen),
              title: Text(tr('settings'), style: const TextStyle(color: kGreen)),
              onTap: () {
                Navigator.pop(c);
                Navigator.push(c, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep, color: Colors.orange),
              title: Text(tr('clear_history'), style: const TextStyle(color: Colors.orange)),
              onTap: () {
                Navigator.pop(c);
                _clearHistory();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(tr('logout'), style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(c);
                _showLogoutConfirm();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirm() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: kGreen.withOpacity(0.5)),
        ),
        title: Text(tr('logout'), style: const TextStyle(color: kGreen)),
        content: const Text('Kya aap logout karna chahte ho?', style: TextStyle(color: kDimGreen)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel', style: TextStyle(color: kDimGreen)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              _logout();
            },
            child: Text(tr('logout'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _searchAndPlay() {
    String input = _linkController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste a Mayajaal link!'), backgroundColor: kCardBg),
      );
      return;
    }
    _linkController.clear();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StreamPreviewScreen(targetUrl: input)),
    ).then((_) => _syncWatchHistory());
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: Text(tr('app_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: kGreen),
            onPressed: _showMoreMenu,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kBg, Color(0xFF001A0E), kBg],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: kCardBg,
                  border: Border.all(color: kGreen.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: kGreen, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        user?.email ?? 'Matrix Guest Node',
                        style: const TextStyle(color: kGreen, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kGreen.withOpacity(0.5), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.link, color: kGreen),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _linkController,
                        style: const TextStyle(color: kGreen, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: tr('paste_hint'),
                          hintStyle: TextStyle(color: kGreen.withOpacity(0.4), fontSize: 12),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill, color: kGreen, size: 35),
                      onPressed: _searchAndPlay,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Text(
                tr('watch_history'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kGreen, letterSpacing: 2),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _history.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 60, color: kGreen.withOpacity(0.4)),
                            const SizedBox(height: 10),
                            Text(tr('no_history'), style: TextStyle(color: kGreen.withOpacity(0.6))),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _history.length,
                        itemBuilder: (c, i) {
                          final item = _history[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
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
                                onPressed: () => _deleteHistoryItem(i),
                              ),
                              onTap: () {
                                Navigator.push(
                                  c,
                                  MaterialPageRoute(
                                    builder: (_) => StreamPreviewScreen(targetUrl: item['url']),
                                  ),
                                ).then((_) => _syncWatchHistory());
                              },
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
}

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
      backgroundColor: kBg,
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
            child: Text('> MayaJaal v1.1.0 // Core Matrix Node', style: TextStyle(color: kGreen.withOpacity(0.5), fontSize: 12)),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: kGreen.withOpacity(0.5)),
        ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: kGreen.withOpacity(0.5)),
        ),
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
class StreamPreviewScreen extends StatefulWidget {
  final String targetUrl;
  const StreamPreviewScreen({super.key, required this.targetUrl});
  @override
  State<StreamPreviewScreen> createState() => _StreamPreviewScreenState();
}

class _StreamPreviewScreenState extends State<StreamPreviewScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  String _streamUrl = '';
  String _videoTitle = 'Media Stream Node';
  String _uploaderName = 'Matrix Ghost User';
  String _rawId = '';

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

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchStreamMetadata() async {
    try {
      final uri = Uri.parse(widget.targetUrl);
      _rawId = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'stream';

      if (widget.targetUrl.endsWith('.mp4') || widget.targetUrl.endsWith('.m3u8')) {
        setState(() {
          _streamUrl = widget.targetUrl;
          _videoTitle = _rawId;
          _loading = false;
        });
        return;
      }

      final res = await http.get(Uri.parse('$kBackendBaseUrl/api/stream-info/$_rawId')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['url'] != null) {
          setState(() {
            _streamUrl = data['url'];
            _videoTitle = data['title'] ?? _rawId;
            _uploaderName = data['uploader'] ?? 'Matrix Ghost User';
            _loading = false;
          });
          return;
        }
      }

      final res2 = await http.get(Uri.parse('$kBackendBaseUrl/api/v/$_rawId'));
      if (res2.statusCode == 200) {
        final data = jsonDecode(res2.body);
        if (data['url'] != null) {
          setState(() {
            _streamUrl = data['url'];
            _videoTitle = _rawId;
            _loading = false;
          });
          return;
        }
      }

      setState(() {
        _streamUrl = widget.targetUrl;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _streamUrl = widget.targetUrl;
        _loading = false;
      });
    }
  }

  void _shareStreamDirect() {
    Share.share('🚀 Watch this high-speed stream on MayaJaal:\n${widget.targetUrl}');
  }

  Future<void> _downloadVideoDirect() async {
    final target = Uri.parse(_streamUrl.isNotEmpty ? _streamUrl : widget.targetUrl);
    if (await canLaunchUrl(target)) {
      await launchUrl(target, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _saveWatchRecord() async {
    final prefs = await SharedPreferences.getInstance();
    final user = Supabase.instance.client.auth.currentUser;
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

    if (user != null) {
      try {
        await http.post(
          Uri.parse('$kBackendBaseUrl/api/history/save'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'telegram_id': user.id,
            'video': item,
          }),
        );
      } catch (_) {}
    }
  }

  void _launchNativePlayer() {
    _saveWatchRecord();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NativeVideoPlayerScreen(
          videoUrl: _streamUrl,
          title: _videoTitle,
          uploader: _uploaderName,
          sourcePageUrl: widget.targetUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('NODE VERIFICATION'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kGreen),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          const MatrixRain(opacity: 0.35),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00150A), Color(0xFF000A18)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: kGreen.withOpacity(0.55), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: kGreen.withOpacity(0.2), blurRadius: 30),
                  ],
                ),
                child: _loading
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: kGreen),
                          const SizedBox(height: 18),
                          Text('> DECRYPTING STREAM NODE...', style: TextStyle(color: kGreen, fontSize: 13, letterSpacing: 2)),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: kGreen, width: 2),
                                boxShadow: [BoxShadow(color: kGreen.withOpacity(0.4), blurRadius: 20)],
                              ),
                              child: const Icon(Icons.play_circle_fill_rounded, color: kGreen, size: 55),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: Text(
                              tr('stream_ready'),
                              style: const TextStyle(color: kNeonCyan, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Divider(color: kGreen.withOpacity(0.3)),
                          const SizedBox(height: 10),
                          Text(tr('filename'), style: TextStyle(color: kDimGreen.withOpacity(0.8), fontSize: 10, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text(_videoTitle, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Text(tr('uploader'), style: TextStyle(color: kDimGreen.withOpacity(0.8), fontSize: 10, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.verified_user, size: 16, color: kGreen),
                              const SizedBox(width: 6),
                              Text(_uploaderName, style: const TextStyle(color: kGreen, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 28),
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) => Transform.scale(
                              scale: _pulseAnimation.value,
                              child: SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: _launchNativePlayer,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kGreen,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 10,
                                  ),
                                  child: Text(
                                    tr('init_stream'),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _downloadVideoDirect,
                                  icon: const Icon(Icons.download, color: kGreen, size: 18),
                                  label: Text(tr('download'), style: const TextStyle(color: kGreen, fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: kGreen),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _shareStreamDirect,
                                  icon: const Icon(Icons.share, color: kNeonCyan, size: 18),
                                  label: Text(tr('share'), style: const TextStyle(color: kNeonCyan, fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: kNeonCyan),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
enum VideoAspectMode {
  fit('Fit Screen (Default)', null),
  cinema169('16:9 Cinema', 16 / 9),
  reel916('9:16 Reel', 9 / 16),
  standard43('4:3 Standard', 4 / 3),
  zoom('Stretch Zoom', 'fill');

  final String title;
  final dynamic ratio;
  const VideoAspectMode(this.title, this.ratio);
}

class NativeVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String uploader;
  final String sourcePageUrl;

  const NativeVideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.uploader,
    required this.sourcePageUrl,
  });

  @override
  State<NativeVideoPlayerScreen> createState() => _NativeVideoPlayerScreenState();
}

class _NativeVideoPlayerScreenState extends State<NativeVideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  // 🌟 NEW CONTROL STATES
  VideoAspectMode _aspectMode = VideoAspectMode.fit;
  bool _isLandscape = false;
  String _selectedQuality = 'Auto';
  final List<String> _qualities = ['Auto', '1080p', '720p', '480p', '360p'];

  bool _isCcEnabled = false;
  double _playbackSpeed = 1.0;
  final List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  bool _isLooping = false;
  bool _isStableVolume = true;

  // 🌟 LIKE / UNLIKE STATS
  int _likesCount = 142;
  int _unlikesCount = 3;
  bool _isLiked = false;
  bool _isUnliked = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    try {
      await _controller.initialize();
      _controller.play();
      _controller.setLooping(_isLooping);
      _controller.setPlaybackSpeed(_playbackSpeed);
      if (_isStableVolume) _controller.setVolume(0.85);

      _controller.addListener(_videoListener);
      setState(() => _isInitialized = true);
      _startControlsTimer();
    } catch (e) {
      setState(() => _hasError = true);
    }
  }

  void _videoListener() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller.removeListener(_videoListener);
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _startControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startControlsTimer();
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
    _startControlsTimer();
  }

  void _toggleOrientation() {
    setState(() => _isLandscape = !_isLandscape);
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
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

  // 🌟 SHARE VIDEO DIRECT LINK
  void _shareVideoLink() {
    Share.share('🎬 Watch this video on MayaJaal:\n${widget.videoUrl}');
  }

  // 🌟 DOWNLOAD VIDEO DIRECT LINK
  Future<void> _downloadVideoDirect() async {
    final target = Uri.parse(widget.videoUrl);
    if (await canLaunchUrl(target)) {
      await launchUrl(target, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open video download URL')),
      );
    }
  }

  void _toggleLike() {
    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likesCount--;
      } else {
        _isLiked = true;
        _likesCount++;
        if (_isUnliked) {
          _isUnliked = false;
          _unlikesCount--;
        }
      }
    });
  }

  void _toggleUnlike() {
    setState(() {
      if (_isUnliked) {
        _isUnliked = false;
        _unlikesCount--;
      } else {
        _isUnliked = true;
        _unlikesCount++;
        if (_isLiked) {
          _isLiked = false;
          _likesCount--;
        }
      }
    });
  }
    void _showAspectDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: kGreen, width: 1.5),
        ),
        title: const Text('ALL SIZE / ASPECT RATIO', style: TextStyle(color: kGreen, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: VideoAspectMode.values.map((mode) {
            return RadioListTile<VideoAspectMode>(
              value: mode,
              groupValue: _aspectMode,
              activeColor: kGreen,
              title: Text(mode.title, style: const TextStyle(color: Colors.white, fontSize: 13)),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _aspectMode = val);
                  Navigator.pop(c);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showQualityDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: kGreen, width: 1.5),
        ),
        title: const Text('VIDEO RESOLUTION', style: TextStyle(color: kGreen, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _qualities.map((q) {
            return RadioListTile<String>(
              value: q,
              groupValue: _selectedQuality,
              activeColor: kGreen,
              title: Text(q, style: const TextStyle(color: Colors.white, fontSize: 13)),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedQuality = val);
                  Navigator.pop(c);
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
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: kGreen, width: 1.5),
        ),
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

  void _showPlayerSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (c) => StatefulBuilder(
        builder: (ctx, setMState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: kGreen.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text('PLAYER CONFIGURATION', style: TextStyle(color: kGreen, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 10),
                SwitchListTile(
                  activeColor: kGreen,
                  title: const Text('Loop Video', style: TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: const Text('Auto-restart playback continuously', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  value: _isLooping,
                  onChanged: (val) {
                    setMState(() => _isLooping = val);
                    setState(() {
                      _isLooping = val;
                      _controller.setLooping(val);
                    });
                  },
                ),
                SwitchListTile(
                  activeColor: kGreen,
                  title: const Text('Stable Volume', style: TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: const Text('Normalize high audio fluctuations', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  value: _isStableVolume,
                  onChanged: (val) {
                    setMState(() => _isStableVolume = val);
                    setState(() {
                      _isStableVolume = val;
                      _controller.setVolume(val ? 0.85 : 1.0);
                    });
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfiguredVideoBox() {
    Widget videoWidget = AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );

    if (_aspectMode == VideoAspectMode.zoom) {
      videoWidget = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      );
    } else if (_aspectMode.ratio is double) {
      videoWidget = AspectRatio(
        aspectRatio: _aspectMode.ratio as double,
        child: VideoPlayer(_controller),
      );
    }

    return Center(child: videoWidget);
  }
    @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isLandscape
          ? null
          : AppBar(
              title: Text(widget.title),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: kGreen),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share, color: kGreen),
                  onPressed: _shareVideoLink,
                ),
              ],
            ),
      body: SafeArea(
        child: Column(
          children: [
            // 🌟 TOP VIDEO PLAYER WITH HUD
            Expanded(
              flex: _isLandscape ? 1 : 0,
              child: Container(
                width: double.infinity,
                height: _isLandscape ? double.infinity : 250,
                color: Colors.black,
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
                        ? const Center(child: CircularProgressIndicator(color: kGreen))
                        : GestureDetector(
                            onTap: _toggleControls,
                            behavior: HitTestBehavior.opaque,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                _buildConfiguredVideoBox(),

                                // TOP OVERLAY CONTROLS (Aspect, Rotate, Quality, CC, Speed, Settings)
                                if (_showControls)
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                      color: Colors.black.withOpacity(0.7),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.aspect_ratio, color: kGreen, size: 20),
                                            tooltip: 'All Size',
                                            onPressed: _showAspectDialog,
                                          ),
                                          IconButton(
                                            icon: Icon(_isLandscape ? Icons.screen_lock_portrait : Icons.screen_rotation, color: kGreen, size: 20),
                                            tooltip: 'Rotate',
                                            onPressed: _toggleOrientation,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.tune, color: kGreen, size: 20),
                                            tooltip: 'Resolution Quality',
                                            onPressed: _showQualityDialog,
                                          ),
                                          IconButton(
                                            icon: Icon(_isCcEnabled ? Icons.closed_caption : Icons.closed_caption_off, color: _isCcEnabled ? kGreen : Colors.grey, size: 22),
                                            tooltip: 'CC',
                                            onPressed: () {
                                              setState(() => _isCcEnabled = !_isCcEnabled);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(_isCcEnabled ? 'CC Enabled' : 'CC Disabled'), duration: const Duration(seconds: 1)),
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.speed, color: kGreen, size: 20),
                                            tooltip: 'Speed',
                                            onPressed: _showSpeedDialog,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.settings, color: kGreen, size: 20),
                                            tooltip: 'Settings (Loop & Stable Volume)',
                                            onPressed: _showPlayerSettingsModal,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                // CENTER HUD: -10s, PLAY/PAUSE, +10s
                                if (_showControls)
                                  Container(
                                    color: Colors.black.withOpacity(0.55),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          iconSize: 42,
                                          icon: const Icon(Icons.replay_10_rounded, color: kGreen),
                                          onPressed: () => _seekRelative(-10),
                                        ),
                                        const SizedBox(width: 25),
                                        IconButton(
                                          iconSize: 55,
                                          icon: Icon(
                                            _controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                            color: kGreen,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _controller.value.isPlaying ? _controller.pause() : _controller.play();
                                            });
                                            _startControlsTimer();
                                          },
                                        ),
                                        const SizedBox(width: 25),
                                        IconButton(
                                          iconSize: 42,
                                          icon: const Icon(Icons.forward_10_rounded, color: kGreen),
                                          onPressed: () => _seekRelative(10),
                                        ),
                                      ],
                                    ),
                                  ),

                                // BOTTOM SEEKBAR & TIME
                                if (_showControls)
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      color: Colors.black.withOpacity(0.7),
                                      child: Row(
                                        children: [
                                          Text(
                                            _formatDuration(_controller.value.position),
                                            style: const TextStyle(color: kGreen, fontSize: 11),
                                          ),
                                          Expanded(
                                            child: Slider(
                                              value: _controller.value.position.inSeconds.toDouble().clamp(
                                                0.0,
                                                _controller.value.duration.inSeconds.toDouble() <= 0
                                                    ? 1.0
                                                    : _controller.value.duration.inSeconds.toDouble(),
                                              ),
                                              min: 0.0,
                                              max: _controller.value.duration.inSeconds.toDouble() <= 0
                                                  ? 1.0
                                                  : _controller.value.duration.inSeconds.toDouble(),
                                              activeColor: kGreen,
                                              inactiveColor: kGreen.withOpacity(0.2),
                                              onChanged: (val) {
                                                _controller.seekTo(Duration(seconds: val.toInt()));
                                              },
                                            ),
                                          ),
                                          Text(
                                            _formatDuration(_controller.value.duration),
                                            style: const TextStyle(color: kGreen, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
              ),
            ),

            // 🌟 BOTTOM DETAILS, VIDEO ACTIONS & INTERACTION BAR
            if (!_isLandscape)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: Color(0xFF050F08),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: ListView(
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.person_pin, size: 16, color: kGreen),
                          const SizedBox(width: 6),
                          Text(
                            'Uploaded by: ${widget.uploader}',
                            style: TextStyle(color: kGreen.withOpacity(0.8), fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 🌟 LIKE, UNLIKE, SHARE & DOWNLOAD BUTTON BAR
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // LIKE BUTTON
                          InkWell(
                            onTap: _toggleLike,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: kCardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _isLiked ? kGreen : kGreen.withOpacity(0.25)),
                              ),
                              child: Row(
                                children: [
                                  Icon(_isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined, color: _isLiked ? kGreen : Colors.white, size: 18),
                                  const SizedBox(width: 6),
                                  Text('$_likesCount', style: TextStyle(color: _isLiked ? kGreen : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),

                          // UNLIKE BUTTON
                          InkWell(
                            onTap: _toggleUnlike,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: kCardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _isUnliked ? Colors.redAccent : kGreen.withOpacity(0.25)),
                              ),
                              child: Row(
                                children: [
                                  Icon(_isUnliked ? Icons.thumb_down : Icons.thumb_down_alt_outlined, color: _isUnliked ? Colors.redAccent : Colors.white, size: 18),
                                  const SizedBox(width: 6),
                                  Text('$_unlikesCount', style: TextStyle(color: _isUnliked ? Colors.redAccent : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),

                          // SHARE VIDEO LINK BUTTON
                          InkWell(
                            onTap: _shareVideoLink,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: kCardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: kNeonCyan.withOpacity(0.5)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.share, color: kNeonCyan, size: 18),
                                  SizedBox(width: 6),
                                  Text('Share', style: TextStyle(color: kNeonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),

                          // DOWNLOAD VIDEO BUTTON
                          InkWell(
                            onTap: _downloadVideoDirect,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: kGreen,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.download, color: Colors.black, size: 18),
                                  SizedBox(width: 6),
                                  Text('Download', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 25),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kCardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kGreen.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.security, size: 16, color: kGreen),
                                SizedBox(width: 6),
                                Text('ADVANCED PLAYER HUD', style: TextStyle(color: kGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('• Aspect Ratio / Size Mode: ${_aspectMode.title}', style: TextStyle(color: kDimGreen.withOpacity(0.9), fontSize: 11)),
                            Text('• Stream Quality: $_selectedQuality', style: TextStyle(color: kDimGreen.withOpacity(0.9), fontSize: 11)),
                            Text('• Playback Speed: ${_playbackSpeed}x | Loop: ${_isLooping ? "ON" : "OFF"}', style: TextStyle(color: kDimGreen.withOpacity(0.9), fontSize: 11)),
                            Text('• Stable Volume Control: ${_isStableVolume ? "ACTIVE" : "OFF"}', style: TextStyle(color: kDimGreen.withOpacity(0.9), fontSize: 11)),
                          ],
                        ),
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
}
