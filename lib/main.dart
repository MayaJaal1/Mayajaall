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
    'init_stream': '⚡ INITIALIZE NEURAL STREAM (OPEN NOW)',
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
    Future.delayed(const Duration(milliseconds: 1400), () {
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

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _incomingUrl = finalUrl;
      setState(() => _showSplash = false);
      return;
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
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kBg,
      colorScheme: const ColorScheme.dark(
        primary: kGreen,
        surface: kCardBg,
      ),
      useMaterial3: true,
      fontFamily: 'monospace',
      appBarTheme: const AppBarTheme(
        backgroundColor: kBg,
        foregroundColor: kGreen,
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
              themeMode: ThemeMode.dark,
              theme: _buildTheme(true),
              darkTheme: _buildTheme(true),
              home: _showSplash
                  ? const SplashScreen()
                  : AuthGate(pendingTargetUrl: _incomingUrl),
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
                  '> decrypting core channels...',
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

class AuthGate extends StatelessWidget {
  final String? pendingTargetUrl;
  const AuthGate({super.key, this.pendingTargetUrl});

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

class LoginScreen extends StatefulWidget {
  final String? pendingTargetUrl;
  const LoginScreen({super.key, this.pendingTargetUrl});

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
      if (mounted) setState(() => _loading = false);
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
                        width: 75,
                        height: 75,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kGreen, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            'assets/icon/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.movie_filter, size: 45, color: kGreen),
                          ),
                        ),
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
                        '> sign in required to decrypt links',
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
// 🌟 4 TABS: HOME, CHANNEL, HISTORY, MORE
class MainNavigationHolder extends StatefulWidget {
  const MainNavigationHolder({super.key});
  @override
  State<MainNavigationHolder> createState() => _MainNavigationHolderState();
}

class _MainNavigationHolderState extends State<MainNavigationHolder> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    ChannelScreen(),
    HistoryScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: kCardBg,
          border: Border(top: BorderSide(color: kGreen.withOpacity(0.3), width: 1.2)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: kCardBg,
          selectedItemColor: kGreen,
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.ondemand_video_outlined),
              activeIcon: Icon(Icons.ondemand_video),
              label: 'Channel',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz_outlined),
              activeIcon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
        ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: Text(tr('app_title')),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: kCardBg,
                  border: Border.all(color: kGreen.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(10),
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
              const SizedBox(height: 25),
              Container(
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kGreen.withOpacity(0.6), width: 1.5),
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
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill, color: kGreen, size: 36),
                      onPressed: _searchAndPlay,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Center(
                child: Text(
                  '> MAYA JAAL // QUANTUM STREAM DECODER',
                  style: TextStyle(color: kGreen.withOpacity(0.4), fontSize: 11, letterSpacing: 1.5),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
// 🌟 CHANNEL SCREEN: OFFICIAL SOCIAL HANDLES (INSTAGRAM & YOUTUBE)
class ChannelScreen extends StatelessWidget {
  const ChannelScreen({super.key});

  Future<void> _launchURL(String url) async {
    final target = Uri.parse(url);
    if (await canLaunchUrl(target)) {
      await launchUrl(target, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('CHANNELS & NODES')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1306C).withOpacity(0.5)),
            ),
            child: ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFE1306C), size: 32),
              title: const Text('Join Instagram Channel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('@maya_jaal_official', style: TextStyle(color: Color(0xFFE1306C), fontSize: 12)),
              trailing: const Icon(Icons.open_in_new, color: Color(0xFFE1306C), size: 20),
              onTap: () => _launchURL('https://www.instagram.com/maya_jaal_official?stkn=MWVmZmxxMXlldWwwdg=='),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
            ),
            child: ListTile(
              leading: const Icon(Icons.play_circle_filled, color: Colors.redAccent, size: 32),
              title: const Text('Join YouTube Channel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('@MayaJaalOfficial00', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              trailing: const Icon(Icons.open_in_new, color: Colors.redAccent, size: 20),
              onTap: () => _launchURL('https://www.youtube.com/@MayaJaalOfficial00'),
            ),
          ),
        ],
      ),
    );
  }
}

// 🌟 HISTORY SCREEN: ISOLATED CLOUD/LOCAL WATCH HISTORY
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
      backgroundColor: kBg,
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

// 🌟 MORE SCREEN: SETTINGS & ACCOUNT ACTIONS
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    await GoogleSignIn().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('MORE OPTIONS')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.settings, color: kGreen),
            title: const Text('App Settings', style: TextStyle(color: Colors.white)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: kGreen),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          Divider(color: kGreen.withOpacity(0.2)),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Logout Session', style: TextStyle(color: Colors.redAccent)),
            onTap: _logout,
          ),
        ],
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

      if (widget.targetUrl.endsWith('.mp4') || widget.targetUrl.endsWith('.m3u8')) {
        setState(() {
          _streamUrl = widget.targetUrl;
          _videoTitle = _rawId;
          _loading = false;
        });
        _startCountdown();
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
          _startCountdown();
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
          _startCountdown();
          return;
        }
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
    Share.share('🚀 Watch this high-speed stream on MayaJaal:\n${widget.targetUrl}');
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
                              width: 75,
                              height: 75,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: kGreen, width: 2),
                                boxShadow: [BoxShadow(color: kGreen.withOpacity(0.4), blurRadius: 20)],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.asset(
                                  'assets/icon/logo.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.play_circle_fill_rounded, color: kGreen, size: 55),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              tr('stream_ready'),
                              style: const TextStyle(
                                color: kNeonCyan,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
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
                          const SizedBox(height: 24),

                          // 🌟 ONLY 1 FOCUSED COUNTDOWN HUD
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _canProceed ? kGreen : Colors.orangeAccent),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_canProceed ? Icons.check_circle : Icons.timer, size: 18, color: _canProceed ? kGreen : Colors.orangeAccent),
                                  const SizedBox(width: 8),
                                  Text(
                                    _canProceed ? 'ACCESS GRANTED // READY' : 'DECRYPTING NODE: 00:${_countdown.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: _canProceed ? kGreen : Colors.orangeAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) => Transform.scale(
                              scale: _canProceed ? _pulseAnimation.value : 1.0,
                              child: SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: _canProceed ? _launchNativePlayer : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _canProceed ? kGreen : Colors.grey[850],
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: _canProceed ? 10 : 0,
                                  ),
                                  child: Text(
                                    _canProceed ? tr('init_stream') : 'PLEASE WAIT TO DECRYPT...',
                                    style: TextStyle(
                                      color: _canProceed ? Colors.black : Colors.white38,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _shareStreamDirect,
                              icon: const Icon(Icons.share, color: kNeonCyan, size: 18),
                              label: Text(tr('share'), style: const TextStyle(color: kNeonCyan, fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: kNeonCyan),
                                padding: const EdgeInsets.symmetric(vertical: 14),
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
    );
  }
}
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

  bool _isCcEnabled = false;
  double _playbackSpeed = 1.0;
  final List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  
  String _selectedQuality = 'Auto (Fast)';
  final List<String> _qualities = ['Auto (Fast)', '1080p FHD', '720p HD', '480p SD', '360p Low'];

  bool _isLooping = false;
  bool _isStableVolume = true;

  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  int _viewsCount = 0;
  int _likesCount = 0;
  int _unlikesCount = 0;
  int _sharesCount = 0;
  bool _isLiked = false;
  bool _isUnliked = false;

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

      final res = await http.get(Uri.parse('$kBackendBaseUrl/api/stats/${widget.videoId}')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _viewsCount = (data['views'] ?? 0) + 1;
            _likesCount = data['likes'] ?? 0;
            _unlikesCount = data['unlikes'] ?? 0;
            _sharesCount = data['shares'] ?? 0;
          });
        }
      }
      await _sendStatUpdate('view');
    } catch (_) {}
  }

  Future<void> _sendStatUpdate(String action) async {
    try {
      await http.post(
        Uri.parse('$kBackendBaseUrl/api/stats/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'video_id': widget.videoId,
          'action': action,
        }),
      );
    } catch (_) {}
  }

  Future<void> _initFastVideo() async {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await _controller.initialize();
      _controller.play();
      _controller.setLooping(_isLooping);
      _controller.setPlaybackSpeed(_playbackSpeed);
      if (_isStableVolume) _controller.setVolume(0.85);

      _controller.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
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

  void _shareVideoLink() {
    setState(() => _sharesCount++);
    _sendStatUpdate('share');
    Share.share('🎬 Watch this video on MayaJaal:\n${widget.videoUrl}');
  }

  // 🌟 NO-PERMISSION-FAIL IN-APP DIRECT DOWNLOADER
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
          SnackBar(
            backgroundColor: kCardBg,
            content: Text('✅ Video saved to:\n$savePath', style: const TextStyle(color: kGreen, fontSize: 11)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download status: $e')),
        );
      }
    }
  }

  Future<void> _toggleLike() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likesCount = math.max(0, _likesCount - 1);
        _sendStatUpdate('unlike_dec');
        prefs.setBool('liked_${widget.videoId}', false);
      } else {
        _isLiked = true;
        _likesCount++;
        _sendStatUpdate('like');
        prefs.setBool('liked_${widget.videoId}', true);
        if (_isUnliked) {
          _isUnliked = false;
          _unlikesCount = math.max(0, _unlikesCount - 1);
          prefs.setBool('unliked_${widget.videoId}', false);
        }
      }
    });
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Switched to $val'), duration: const Duration(seconds: 1)),
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
      appBar: _isFullscreen
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
            // 🌟 TOP VIDEO VIEW
            Expanded(
              flex: _isFullscreen ? 1 : 0,
              child: Container(
                width: double.infinity,
                height: _isFullscreen ? double.infinity : 240,
                color: Colors.black,
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
                            onTap: () {
                              if (_controller.value.isPlaying) {
                                _controller.pause();
                                _showFeedback('PAUSE');
                              } else {
                                _controller.play();
                                _showFeedback('PLAY');
                              }
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                _buildSmartScaledVideo(),

                                if (_flashFeedback.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(25),
                                      border: Border.all(color: kGreen.withOpacity(0.7)),
                                    ),
                                    child: Text(
                                      _flashFeedback,
                                      style: const TextStyle(color: kGreen, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
                                    ),
                                  ),

                                Positioned(
                                  left: 20,
                                  child: IconButton(
                                    iconSize: 38,
                                    icon: const Icon(Icons.replay_10_rounded, color: Colors.white60),
                                    onPressed: () => _seekRelative(-10),
                                  ),
                                ),
                                Positioned(
                                  right: 20,
                                  child: IconButton(
                                    iconSize: 38,
                                    icon: const Icon(Icons.forward_10_rounded, color: Colors.white60),
                                    onPressed: () => _seekRelative(10),
                                  ),
                                ),

                                // 🌟 IN-PLAYER OVERLAY CONTROLS (ONLY 1 FULLSCREEN BUTTON)
                                Positioned(
                                  bottom: 4,
                                  left: 12,
                                  right: 12,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(
                                        icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: kGreen, size: 24),
                                        tooltip: 'Fullscreen Toggle',
                                        onPressed: _toggleSmartFullscreen,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.tune, color: kGreen, size: 22),
                                        tooltip: 'Resolution Quality',
                                        onPressed: _showQualityDialog,
                                      ),
                                      IconButton(
                                        icon: Icon(_isCcEnabled ? Icons.closed_caption : Icons.closed_caption_off, color: _isCcEnabled ? kGreen : Colors.white60, size: 24),
                                        tooltip: 'CC',
                                        onPressed: () {
                                          setState(() => _isCcEnabled = !_isCcEnabled);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(_isCcEnabled ? 'CC Enabled' : 'CC Disabled'), duration: const Duration(seconds: 1)),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.speed, color: kGreen, size: 22),
                                        tooltip: 'Speed',
                                        onPressed: _showSpeedDialog,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ),

            // 🌟 NEO & TRINITY MATRIX TIMELINE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              color: Colors.transparent,
              child: Row(
                children: [
                  Text(
                    _isInitialized ? _formatDuration(_controller.value.position) : '00:00',
                    style: const TextStyle(color: kGreen, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2.5,
                        activeTrackColor: kGreen,
                        inactiveTrackColor: kGreen.withOpacity(0.18),
                        thumbColor: kNeonCyan,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayColor: kGreen.withOpacity(0.15),
                      ),
                      child: Slider(
                        value: _isInitialized
                            ? _controller.value.position.inSeconds.toDouble().clamp(
                                0.0,
                                _controller.value.duration.inSeconds.toDouble() <= 0
                                    ? 1.0
                                    : _controller.value.duration.inSeconds.toDouble(),
                              )
                            : 0.0,
                        min: 0.0,
                        max: _isInitialized && _controller.value.duration.inSeconds.toDouble() > 0
                            ? _controller.value.duration.inSeconds.toDouble()
                            : 1.0,
                        onChanged: (val) {
                          _controller.seekTo(Duration(seconds: val.toInt()));
                        },
                      ),
                    ),
                  ),
                  Text(
                    _isInitialized ? _formatDuration(_controller.value.duration) : '00:00',
                    style: const TextStyle(color: kDimGreen, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),

            // 🌟 REAL STATS & COMMUNITY ENGAGEMENT BAR
            if (!_isFullscreen)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF050F08),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: ListView(
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person_pin, size: 15, color: kGreen),
                          const SizedBox(width: 6),
                          Text(
                            'Uploaded by: ${widget.uploader}',
                            style: TextStyle(color: kGreen.withOpacity(0.8), fontSize: 12),
                          ),
                          const Spacer(),
                          const Icon(Icons.remove_red_eye_outlined, size: 15, color: kNeonCyan),
                          const SizedBox(width: 4),
                          Text(
                            '$_viewsCount views',
                            style: const TextStyle(color: kNeonCyan, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // LIKE, UNLIKE, SHARE & DOWNLOAD BUTTON BAR
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: _toggleLike,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: kCardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _isLiked ? kGreen : kGreen.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  Icon(_isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined, color: _isLiked ? kGreen : Colors.white, size: 16),
                                  const SizedBox(width: 5),
                                  Text('$_likesCount', style: TextStyle(color: _isLiked ? kGreen : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),

                          InkWell(
                            onTap: _toggleUnlike,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: kCardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _isUnliked ? Colors.redAccent : kGreen.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  Icon(_isUnliked ? Icons.thumb_down : Icons.thumb_down_alt_outlined, color: _isUnliked ? Colors.redAccent : Colors.white, size: 16),
                                  const SizedBox(width: 5),
                                  Text('$_unlikesCount', style: TextStyle(color: _isUnliked ? Colors.redAccent : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),

                          InkWell(
                            onTap: _shareVideoLink,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: kCardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: kNeonCyan.withOpacity(0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.share, color: kNeonCyan, size: 16),
                                  const SizedBox(width: 5),
                                  Text('$_sharesCount', style: const TextStyle(color: kNeonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),

                          // IN-APP DIRECT DOWNLOAD
                          InkWell(
                            onTap: _startInAppDownload,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: kGreen,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.download, color: Colors.black, size: 17),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isDownloading ? '${(_downloadProgress * 100).toInt()}%' : 'Download',
                                    style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_isDownloading) ...[
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: _downloadProgress,
                          backgroundColor: kCardBg,
                          color: kGreen,
                        ),
                      ],
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
