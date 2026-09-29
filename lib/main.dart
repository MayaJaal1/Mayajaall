import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:convert' as json;
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

// ═══════════════════════════════════════════
// CONFIG
// ═══════════════════════════════════════════
const String supabaseUrl = 'https://inxlnctaixbkfblwlmhr.supabase.co';
const String supabaseAnonKey = 'sb_publishable_6b9xe3mDBduO-soZTk3t2A_W1sQpD5K';
const String webClientId = '985001671962-rok8qnng0rumjsd8mgr8uhr92o5vhs4n.apps.googleusercontent.com';

// Backend URL (Railway)
const String kBackendUrl = 'https://mayajaal-backend-production.up.railway.app';

// APK Download URL (GitHub Releases)
const String kApkDownloadUrl =
    'https://github.com/ajayr0201/Mayajaall/releases/latest/download/app-release.apk';

// GitHub API for update check
const String kGithubApiUrl =
    'https://api.github.com/repos/ajayr0201/Mayajaall/releases/latest';

// Matrix Theme Colors
const Color kGreen = Color(0xFF00FF41);
const Color kBg = Color(0xFF000000);
const Color kCardBg = Color(0xFF0A0A0A);
const Color kDimGreen = Color(0xFF4FBF8B);

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_theme') ?? true;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  runApp(const MyApp());
}

// ═══════════════════════════════════════════
// MY APP
// ═══════════════════════════════════════════
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
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  ThemeData _buildTheme(bool isDark) {
    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: isDark ? kBg : Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kGreen,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      useMaterial3: true,
      fontFamily: 'monospace',
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? kBg : Colors.white,
        foregroundColor: kGreen,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'MayaJaal',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: _buildTheme(false),
          darkTheme: _buildTheme(true),
          home: _showSplash
              ? const SplashScreen()
              : (_incomingUrl == null
                  ? const AuthGate()
                  : VideoPlayerScreen(url: _incomingUrl!)),
        );
      },
    );
  }
}// ═══════════════════════════════════════════
// MATRIX RAIN WIDGET
// ═══════════════════════════════════════════
class MatrixRain extends StatefulWidget {
  const MatrixRain({super.key});
  @override
  State<MatrixRain> createState() => _MatrixRainState();
}

class _MatrixRainState extends State<MatrixRain> {
  late Timer _timer;
  final List<double> _yPositions = [];
  final List<double> _speeds = [];
  final List<String> _letters = [];
  final math.Random _r = math.Random();
  static const _chars =
      'アイウエオカキクケコサシスセソタチツテトナニヌネノ0123456789ABCDEFXYZ';

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 30; i++) {
      _yPositions.add(-_r.nextInt(500).toDouble());
      _speeds.add(3 + _r.nextDouble() * 5);
      _letters.add(_chars[_r.nextInt(_chars.length)]);
    }
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
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
                  color: kGreen.withOpacity(0.7),
                  fontSize: 14,
                  fontFamily: 'monospace',
                  shadows: const [Shadow(color: kGreen, blurRadius: 8)],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
// SPLASH SCREEN
// ═══════════════════════════════════════════
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
                    child: const Icon(Icons.movie_filter,
                        size: 80, color: kGreen),
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
                        Shadow(
                            color: kGreen.withOpacity(_a.value),
                            blurRadius: 20),
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

// ═══════════════════════════════════════════
// AUTH GATE
// ═══════════════════════════════════════════
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

// ═══════════════════════════════════════════
// LOGIN SCREEN
// ═══════════════════════════════════════════
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
      final GoogleSignIn googleSignIn =
          GoogleSignIn(serverClientId: webClientId);
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
                      BoxShadow(
                          color: kGreen.withOpacity(0.2), blurRadius: 30),
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
                        child: const Icon(Icons.movie_filter,
                            size: 50, color: kGreen),
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
                        '> secure access node',
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
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 12),
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
}// ═══════════════════════════════════════════
// HOME SCREEN
// ═══════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _linkController = TextEditingController();
  List<String> _history = [];
  bool _permissionsChecked = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    Future.delayed(const Duration(seconds: 1), () => _requestPermissions());
    // In-app update check (3 sec baad)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) UpdateChecker.checkForUpdate(context);
    });
  }

  Future<void> _requestPermissions() async {
    if (_permissionsChecked) return;
    _permissionsChecked = true;
    if (!await Permission.notification.isGranted) {
      await Permission.notification.request();
    }
    if (!await Permission.camera.isGranted) {
      await Permission.camera.request();
    }
    if (!await Permission.storage.isGranted) {
      await Permission.storage.request();
    }
    // Install packages permission (in-app update ke liye)
    if (!await Permission.requestInstallPackages.isGranted) {
      await Permission.requestInstallPackages.request();
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _history = prefs.getStringList('watch_history') ?? []);
  }

  Future<void> _saveToHistory(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('watch_history') ?? [];
    if (!history.contains(url)) {
      history.insert(0, url);
      if (history.length > 50) history.removeLast();
      await prefs.setStringList('watch_history', history);
    }
  }

  Future<void> _deleteHistoryItem(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('watch_history') ?? [];
    history.removeAt(index);
    await prefs.setStringList('watch_history', history);
    setState(() => _history = history);
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('watch_history');
    setState(() => _history = []);
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kGreen,
                letterSpacing: 3,
              ),
            ),
            Divider(color: kGreen.withOpacity(0.3)),
            ListTile(
              leading: const Icon(Icons.settings, color: kGreen),
              title: const Text('Settings',
                  style: TextStyle(color: kGreen)),
              onTap: () {
                Navigator.pop(c);
                Navigator.push(
                  c,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.system_update, color: kGreen),
              title: const Text('Check for Update',
                  style: TextStyle(color: kGreen)),
              onTap: () {
                Navigator.pop(c);
                UpdateChecker.checkForUpdate(context, force: true);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_sweep, color: Colors.orange),
              title: const Text('Clear History',
                  style: TextStyle(color: Colors.orange)),
              onTap: () {
                Navigator.pop(c);
                _clearHistory();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title:
                  const Text('Logout', style: TextStyle(color: Colors.red)),
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
        title: const Text('Logout?', style: TextStyle(color: kGreen)),
        content: const Text(
          'Kya aap logout karna chahte ho?',
          style: TextStyle(color: kDimGreen),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel',
                style: TextStyle(color: kDimGreen)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              _logout();
            },
            child:
                const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _searchAndPlay() {
    String input = _linkController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste a Mayajaal link first!'),
          backgroundColor: kCardBg,
        ),
      );
      return;
    }
    if (input.startsWith('mayajaall://')) {
      input = input.replaceFirst(
          'mayajaall://', '$kBackendUrl/');
    }
    _saveToHistory(input);
    _linkController.clear();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: input)),
    ).then((_) => _loadHistory());
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('MAYA JAAL'),
        backgroundColor: kBg,
        foregroundColor: kGreen,
        elevation: 0,
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
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
                        user?.email ?? 'User',
                        style: const TextStyle(
                          color: kGreen,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
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
                  border: Border.all(
                      color: kGreen.withOpacity(0.5), width: 1.5),
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
                        style: const TextStyle(
                          color: kGreen,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Paste Mayajaal link here...',
                          hintStyle: TextStyle(
                            color: kGreen.withOpacity(0.4),
                            fontSize: 12,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill,
                          color: kGreen, size: 35),
                      onPressed: _searchAndPlay,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              const Text(
                '> WATCH HISTORY',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: kGreen,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _history.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history,
                                size: 60,
                                color: kGreen.withOpacity(0.4)),
                            const SizedBox(height: 10),
                            Text(
                              'no history yet',
                              style: TextStyle(
                                color: kGreen.withOpacity(0.6),
                                fontFamily: 'monospace',
                              ),
                            ),
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
                              border: Border.all(
                                  color: kGreen.withOpacity(0.3)),
                            ),
                            child: ListTile(
                              leading: const Icon(
                                  Icons.play_circle_outline,
                                  color: kGreen),
                              title: Text(
                                item.length > 50
                                    ? '${item.substring(0, 50)}...'
                                    : item,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: kGreen,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close,
                                    size: 16, color: Colors.redAccent),
                                onPressed: () => _deleteHistoryItem(i),
                              ),
                              onTap: () {
                                Navigator.push(
                                  c,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          VideoPlayerScreen(url: item)),
                                ).then((_) => _loadHistory());
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

// ═══════════════════════════════════════════
// SETTINGS SCREEN
// ═══════════════════════════════════════════
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkTheme = true;
  String _language = 'English';
  String _downloadLocation = 'Internal Storage / Mayajaall';

  final List<String> _languages = [
    'English', 'Hindi', 'Bengali', 'Tamil', 'Telugu',
    'Marathi', 'Gujarati', 'Kannada', 'Malayalam', 'Punjabi'
  ];
  final List<String> _downloadLocations = [
    'Internal Storage / Mayajaall',
    'Internal Storage / Download',
    'Internal Storage / Movies',
    'SD Card / Mayajaall',
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
      _downloadLocation = prefs.getString('download_location') ??
          'Internal Storage / Mayajaall';
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
      appBar: AppBar(
        title: const Text('SETTINGS'),
        backgroundColor: kBg,
        foregroundColor: kGreen,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.dark_mode, color: kGreen),
            title: const Text('Dark Theme',
                style:
                    TextStyle(color: kGreen, fontFamily: 'monospace')),
            subtitle: Text(_darkTheme ? 'ON' : 'OFF',
                style: TextStyle(
                    color: kGreen.withOpacity(0.6), fontSize: 12)),
            trailing: Switch(
                value: _darkTheme,
                activeColor: kGreen,
                onChanged: _saveDarkTheme),
          ),
          Divider(color: kGreen.withOpacity(0.2)),
          ListTile(
            leading: const Icon(Icons.language, color: kGreen),
            title: const Text('Language',
                style:
                    TextStyle(color: kGreen, fontFamily: 'monospace')),
            subtitle: Text(_language,
                style: TextStyle(
                    color: kGreen.withOpacity(0.6), fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 14, color: kGreen),
            onTap: () => _showLanguageDialog(),
          ),
          Divider(color: kGreen.withOpacity(0.2)),
          ListTile(
            leading: const Icon(Icons.download, color: kGreen),
            title: const Text('Download Location',
                style:
                    TextStyle(color: kGreen, fontFamily: 'monospace')),
            subtitle: Text(_downloadLocation,
                style: TextStyle(
                    color: kGreen.withOpacity(0.6), fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 14, color: kGreen),
            onTap: () => _showDownloadLocationDialog(),
          ),
          Divider(color: kGreen.withOpacity(0.2)),
          ListTile(
            leading: const Icon(Icons.system_update, color: kGreen),
            title: const Text('Check for Update',
                style:
                    TextStyle(color: kGreen, fontFamily: 'monospace')),
            subtitle: const Text('Latest version check karein',
                style: TextStyle(color: kDimGreen, fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 14, color: kGreen),
            onTap: () => UpdateChecker.checkForUpdate(context, force: true),
          ),
          Divider(color: kGreen.withOpacity(0.2)),
          const SizedBox(height: 30),
          Center(
            child: Text(
              '> MayaJaal v1.0.0',
              style: TextStyle(
                color: kGreen.withOpacity(0.5),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: kGreen.withOpacity(0.5)),
        ),
        title: const Text('Select Language',
            style: TextStyle(color: kGreen)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _languages.length,
            itemBuilder: (c2, i) => RadioListTile<String>(
              title: Text(_languages[i],
                  style: const TextStyle(color: kGreen)),
              value: _languages[i],
              groupValue: _language,
              activeColor: kGreen,
              onChanged: (value) {
                if (value != null) {
                  _saveLanguage(value);
                  Navigator.pop(c);
                }
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel',
                style: TextStyle(color: kDimGreen)),
          ),
        ],
      ),
    );
  }

  void _showDownloadLocationDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kCardBg,
 // ═══════════════════════════════════════════
// VIDEO PLAYER SCREEN (Native Player)
// ═══════════════════════════════════════════
class VideoPlayerScreen extends StatefulWidget {
  final String url;
  const VideoPlayerScreen({super.key, required this.url});
  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _resolvedUrl = '';

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  /// URL resolve karo - /tb/ ya /v/ link se direct video URL nikalna
  Future<String> _resolveVideoUrl(String url) async {
    // Agar already direct video URL hai
    if (url.contains('.mp4') ||
        url.contains('.m3u8') ||
        url.contains('.mkv') ||
        url.contains('.webm')) {
      return url;
    }

    // Agar /tb/ link hai → API se video URL lo
    if (url.contains('/tb/')) {
      final shortId = url.split('/tb/').last.split('?').first;
      final apiUrl = '$kBackendUrl/api/tb/$shortId';
      try {
        final response = await http.get(Uri.parse(apiUrl));
        if (response.statusCode == 200) {
          final data = json.jsonDecode(response.body);
          final videoUrl = data['video_url'] as String?;
          if (videoUrl != null && videoUrl.isNotEmpty) {
            return videoUrl;
          }
        }
      } catch (e) {
        debugPrint('API error: $e');
      }
      throw Exception('TB API failed');
    }

    // Agar /v/ link hai → redirect follow karo
    if (url.contains('/v/')) {
      try {
        final dio = Dio();
        dio.options.followRedirects = false;
        dio.options.validateStatus = (status) => true;
        final response = await dio.get(url);
        final location = response.headers.value('location');
        if (location != null && location.startsWith('http')) {
          return location;
        }
      } catch (e) {
        debugPrint('Redirect error: $e');
      }
      throw Exception('V link redirect failed');
    }

    // Warna as-is return karo
    return url;
  }

  Future<void> _initPlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // URL resolve karo
      final videoUrl = await _resolveVideoUrl(widget.url);
      _resolvedUrl = videoUrl;

      debugPrint('Resolved URL: $videoUrl');

      // Native video player initialize karo
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
        },
      );

      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        aspectRatio: _videoController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.red, size: 60),
                const SizedBox(height: 15),
                Text(
                  'Video error',
                  style: TextStyle(
                      color: kGreen, fontSize: 16, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    errorMessage,
                    style: TextStyle(
                        color: kGreen.withOpacity(0.6), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      );

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('MAYA JAAL PLAYER'),
        backgroundColor: Colors.black,
        foregroundColor: kGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kGreen),
            tooltip: 'Reload',
            onPressed: () {
              _videoController?.dispose();
              _chewieController?.dispose();
              _initPlayer();
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser, color: kGreen),
            tooltip: 'Open in Browser',
            onPressed: _openInBrowser,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: kGreen),
                  SizedBox(height: 15),
                  Text(
                    '> loading stream...',
                    style: TextStyle(
                      color: kGreen,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            )
          : _hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 70, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text(
                          'Video load nahi ho paya',
                          style: TextStyle(
                            color: kGreen,
                            fontSize: 18,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: kGreen.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _initPlayer,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGreen,
                            foregroundColor: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Go Back',
                              style: TextStyle(color: kGreen)),
                        ),
                      ],
                    ),
                  ),
                )
              : _chewieController != null
                  ? Center(child: Chewie(controller: _chewieController!))
                  : Center(
                      child: Text(
                        'Player not initialized',
                        style: TextStyle(color: kGreen),
                      ),
                    ),
    );
  }
}

// ═══════════════════════════════════════════
// UPDATE CHECKER (In-App Update)
// ═══════════════════════════════════════════
class UpdateChecker {
  static Future<void> checkForUpdate(
    BuildContext context, {
    bool force = false,
  }) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(
        Uri.parse(kGithubApiUrl),
        headers: {'Accept': 'application/vnd.github+json'},
      );

      if (response.statusCode != 200) {
        if (force && context.mounted) {
          _showSnack(context, 'Update check failed (${response.statusCode})');
        }
        return;
      }

      final data = json.jsonDecode(response.body);
      final latestVersion = (data['tag_name'] as String? ?? '0.0.0')
          .replaceAll('v', '')
          .trim();

      if (_isNewer(latestVersion, currentVersion)) {
        if (context.mounted) {
          _showUpdateDialog(context, latestVersion);
        }
      } else {
        if (force && context.mounted) {
          _showSnack(context, 'Aap latest version pe ho ✓ (v$currentVersion)');
        }
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
      if (force && context.mounted) {
        _showSnack(context, 'Update check failed');
      }
    }
  }

  static bool _isNewer(String latest, String current) {
    try {
      final l = latest.split('.').map(int.parse).toList();
      final c = current.split('.').map(int.parse).toList();
      for (int i = 0; i < l.length && i < c.length; i++) {
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
    } catch (_) {}
    return false;
  }

  static void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: kGreen)),
        backgroundColor: kCardBg,
      ),
    );
  }

  static void _showUpdateDialog(BuildContext context, String newVersion) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: kGreen.withOpacity(0.5)),
        ),
        title: Row(
          children: const [
            Icon(Icons.system_update, color: kGreen),
            SizedBox(width: 10),
            Text('Update Available',
                style: TextStyle(color: kGreen, fontFamily: 'monospace')),
          ],
        ),
        content: Text(
          'Naya version aa gaya hai: v$newVersion\n\nAbhi update karein best experience ke liye.',
          style: TextStyle(color: kGreen.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child:
                Text('Later', style: TextStyle(color: kDimGreen)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(c);
              downloadAndInstallApk(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              foregroundColor: Colors.black,
            ),
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  static Future<void> downloadAndInstallApk(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: kCardBg,
          content: Row(
            children: [
              const CircularProgressIndicator(color: kGreen),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Downloading update...',
                  style: TextStyle(color: kGreen),
                ),
              ),
            ],
          ),
        ),
      );

      final dir = await getExternalStorageDirectory();
      final filePath = '${dir!.path}/mayajaal_update.apk';

      await Dio().download(
        kApkDownloadUrl,
        filePath,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (context.mounted) Navigator.pop(context);

      final file = File(filePath);
      if (await file.exists()) {
        await OpenFilex.open(filePath);
      } else {
        if (context.mounted) {
          _showSnack(context, 'Download failed');
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showSnack(context, 'Update failed: $e');
      }
    }
  }
}
