import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

// ═══════════════════════════════════════════
// CONFIG
// ═══════════════════════════════════════════
const String supabaseUrl = 'https://inxlnctaixbkfblwlmhr.supabase.co';
const String supabaseAnonKey = 'sb_publishable_6b9xe3mDBduO-soZTk3t2A_W1sQpD5K';
const String webClientId = '985001671962-rok8qnng0rumjsd8mgr8uhr92o5vhs4n.apps.googleusercontent.com';

// ═══════════════════════════════════════════
// MATRIX COLORS
// ═══════════════════════════════════════════
class MatrixColors {
  static const Color green = Color(0xFF00FF41);
  static const Color darkGreen = Color(0xFF003B00);
  static const Color bg = Color(0xFF000000);
  static const Color cardBg = Color(0xFF0A0A0A);
  static const Color dimGreen = Color(0xFF4FBF8B);
}

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
    if (uri.scheme == 'mayajaall') {
      if (uri.queryParameters.containsKey('url')) {
        finalUrl = uri.queryParameters['url']!;
      }
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'MayaJaal',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: _buildMatrixTheme(false),
          darkTheme: _buildMatrixTheme(true),
          home: _showSplash
              ? const SplashScreen()
              : (_incomingUrl == null
                  ? const AuthGate()
                  : VideoPlayerScreen(url: _incomingUrl!)),
        );
      },
    );
  }

  ThemeData _buildMatrixTheme(bool isDark) {
    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: isDark ? MatrixColors.bg : Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: MatrixColors.green,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      useMaterial3: true,
      fontFamily: 'monospace',
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? MatrixColors.bg : Colors.white,
        foregroundColor: MatrixColors.green,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: MatrixColors.green,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          letterSpacing: 2,
        ),
      ),
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
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MatrixColors.bg,
      body: Stack(
        children: [
          const MatrixRain(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, _) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: MatrixColors.green
                                .withOpacity(0.4 * _glowAnimation.value),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.movie_filter,
                        size: 80,
                        color: MatrixColors.green,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
                AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, _) {
                    return Text(
                      'MAYA JAAL',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: MatrixColors.green,
                        fontFamily: 'monospace',
                        letterSpacing: 8,
                        shadows: [
                          Shadow(
                            color: MatrixColors.green
                                .withOpacity(_glowAnimation.value),
                            blurRadius: 20,
                          ),
                          Shadow(
                            color: MatrixColors.green
                                .withOpacity(0.6 * _glowAnimation.value),
                            blurRadius: 40,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  '> initializing secure channel...',
                  style: TextStyle(
                    fontSize: 12,
                    color: MatrixColors.green.withOpacity(0.7),
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
// MATRIX RAIN
// ═══════════════════════════════════════════
class MatrixRain extends StatefulWidget {
  const MatrixRain({super.key});
  @override
  State<MatrixRain> createState() => _MatrixRainState();
}

class _MatrixRainState extends State<MatrixRain> {
  late Timer _timer;
  final List<MatrixColumn> _columns = [];
  final math.Random _random = math.Random();

  static const String _chars =
      'アイウエオカキクケコサシスセソタチツテトナニヌネノ0123456789ABCDEFXYZ';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      setState(() {
        for (final col in _columns) {
          col.y += col.speed;
          if (col.y > 900) {
            col.y = -_random.nextInt(200).toDouble();
            col.chars = _generateChars();
          }
        }
      });
    });
  }

  List<String> _generateChars() {
    return List.generate(
      15,
      (_) => _chars[_random.nextInt(_chars.length)],
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_columns.isEmpty) {
          const colWidth = 14.0;
          final count = (constraints.maxWidth / colWidth).floor();
          for (int i = 0; i < count; i++) {
            _columns.add(MatrixColumn(
              x: i * colWidth,
              y: -_random.nextInt(500).toDouble(),
              speed: 3 + _random.nextDouble() * 5,
              chars: _generateChars(),
            ));
          }
        }
        return CustomPaint(
          painter: MatrixRainPainter(columns: _columns),
          size: Size(constraints.maxWidth, constraints.maxHeight),
        );
      },
    );
  }
}

class MatrixColumn {
  final double x;
  double y;
  final double speed;
  List<String> chars;

  MatrixColumn({
    required this.x,
    required this.y,
    required this.speed,
    required this.chars,
  });
}

class MatrixRainPainter extends CustomPainter {
  final List<MatrixColumn> columns;

  MatrixRainPainter({required this.columns});

  @override
  void paint(Canvas canvas, Size size) {
    const fontSize = 14.0;

    for (final col in columns) {
      for (int i = 0; i < col.chars.length; i++) {
        final y = col.y - (i * fontSize);
        if (y < -fontSize || y > size.height) continue;

        final opacity = (1.0 - (i / col.chars.length)).clamp(0.0, 1.0);

        final tp = TextPainter(
          text: TextSpan(
            text: col.chars[i],
            style: TextStyle(
              color: i == 0
                  ? Colors.white
                  : MatrixColors.green.withOpacity(opacity * 0.85),
              fontSize: fontSize,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              shadows: i == 0
                  ? [
                      const Shadow(
                        color: MatrixColors.green,
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(col.x, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
            backgroundColor: MatrixColors.bg,
            body: Center(
              child: CircularProgressIndicator(color: MatrixColors.green),
            ),
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
      backgroundColor: MatrixColors.bg,
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
                    color: MatrixColors.cardBg.withOpacity(0.9),
                    border: Border.all(
                      color: MatrixColors.green.withOpacity(0.5),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: MatrixColors.green.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: MatrixColors.green,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: MatrixColors.green.withOpacity(0.5),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.movie_filter,
                          size: 50,
                          color: MatrixColors.green,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'MAYA JAAL',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: MatrixColors.green,
                          fontFamily: 'monospace',
                          letterSpacing: 6,
                          shadows: [
                            Shadow(
                              color: MatrixColors.green,
                              blurRadius: 15,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '> secure access node',
                        style: TextStyle(
                          fontSize: 11,
                          color: MatrixColors.green.withOpacity(0.7),
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
                            backgroundColor: MatrixColors.green,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 8,
                            shadowColor: MatrixColors.green,
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
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
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
      backgroundColor: MatrixColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MatrixColors.green.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '> OPTIONS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: MatrixColors.green,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 10),
              Divider(color: MatrixColors.green.withOpacity(0.3)),
              ListTile(
                leading: const Icon(Icons.settings, color: MatrixColors.green),
                title: const Text(
                  'Settings',
                  style: TextStyle(color: MatrixColors.green),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep, color: Colors.orange),
                title: const Text(
                  'Clear History',
                  style: TextStyle(color: Colors.orange),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _clearHistory();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showLogoutConfirm();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showLogoutConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MatrixColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: MatrixColors.green.withOpacity(0.5)),
        ),
        title: const Text(
          'Logout?',
          style: TextStyle(color: MatrixColors.green),
        ),
        content: const Text(
          'Kya aap logout karna chahte ho?',
          style: TextStyle(color: MatrixColors.dimGreen),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: MatrixColors.dimGreen),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
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
          backgroundColor: MatrixColors.cardBg,
        ),
      );
      return;
    }
    if (input.startsWith('mayajaall://')) {
      input = input.replaceFirst(
        'mayajaall://',
        'https://live-score-website-alpha.vercel.app/',
      );
    }
    _saveToHistory(input);
    _linkController.clear();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VideoPlayerScreen(url: input)),
    ).then((_) => _loadHistory());
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: MatrixColors.bg,
      appBar: AppBar(
        title: const Text('MAYA JAAL'),
        backgroundColor: MatrixColors.bg,
        foregroundColor: MatrixColors.green,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: MatrixColors.green),
            onPressed: _showMoreMenu,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              MatrixColors.bg,
              Color(0xFF001A0E),
              MatrixColors.bg,
            ],
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
                  color: MatrixColors.cardBg,
                  border: Border.all(
                    color: MatrixColors.green.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: MatrixColors.green, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        user?.email ?? 'User',
                        style: const TextStyle(
                          color: MatrixColors.green,
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
                  color: MatrixColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: MatrixColors.green.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: MatrixColors.green.withOpacity(0.1),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.link, color: MatrixColors.green),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _linkController,
                        style: const TextStyle(
                          color: MatrixColors.green,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Paste Mayajaal link here...',
                          hintStyle: TextStyle(
                            color: MatrixColors.green.withOpacity(0.4),
                            fontSize: 12,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        maxLines: 1,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.play_circle_fill,
                        color: MatrixColors.green,
                        size: 35,
                      ),
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
                  color: MatrixColors.green,
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
                            Icon(
                              Icons.history,
                              size: 60,
                              color: MatrixColors.green.withOpacity(0.4),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'no history yet',
                              style: TextStyle(
                                color: MatrixColors.green.withOpacity(0.6),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final item = _history[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: MatrixColors.cardBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: MatrixColors.green.withOpacity(0.3),
                              ),
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.play_circle_outline,
                                color: MatrixColors.green,
                              ),
                              title: Text(
                                item.length > 50 ? '${item.substring(0, 50)}...' : item,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: MatrixColors.green,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _deleteHistoryItem(index),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VideoPlayerScreen(url: item),
                                  ),
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
  bool _darkTheme = false;
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
      backgroundColor: MatrixColors.bg,
      appBar: AppBar(
        title: const Text('SETTINGS'),
        backgroundColor: MatrixColors.bg,
        foregroundColor: MatrixColors.green,
      ),
      body: ListView(
        children: [
          _buildTile(
            icon: Icons.dark_mode,
            title: 'Dark Theme',
            subtitle: _darkTheme ? 'ON' : 'OFF',
            trailing: Switch(
              value: _darkTheme,
              activeColor: MatrixColors.green,
              onChanged: _saveDarkTheme,
            ),
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.language,
            title: 'Language',
            subtitle: _language,
            onTap: () => _showLanguageDialog(),
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.download,
            title: 'Download Location',
            subtitle: _downloadLocation,
            onTap: () => _showDownloadLocationDialog(),
          ),
          _buildDivider(),
          const SizedBox(height: 30),
          Center(
            child: Text(
              '> MayaJaal v1.0.0',
              style: TextStyle(
                color: MatrixColors.green.withOpacity(0.5),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: MatrixColors.green),
      title: Text(
        title,
        style: const TextStyle(
          color: MatrixColors.green,
          fontFamily: 'monospace',
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: MatrixColors.green.withOpacity(0.6),
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
      trailing: trailing ??
          const Icon(Icons.arrow_forward_ios, size: 14, color: MatrixColors.green),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(color: MatrixColors.green.withOpacity(0.2));
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MatrixColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: MatrixColors.green.withOpacity(0.5)),
        ),
        title: const Text(
          'Select Language',
          style: TextStyle(color: MatrixColors.green),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _languages.length,
            itemBuilder: (context, index) {
              final lang = _languages[index];
              return RadioListTile<String>(
                title: Text(lang, style: const TextStyle(color: MatrixColors.green)),
                value: lang,
                groupValue: _language,
                activeColor: MatrixColors.green,
                onChanged: (value) {
                  if (value != null) {
                    _saveLanguage(value);
                    Navigator.pop(context);
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: con// ═══════════════════════════════════════════
// VIDEO PLAYER SCREEN (Ye class pehle missing thi!)
// ═══════════════════════════════════════════
class VideoPlayerScreen extends StatefulWidget {
  final String url;
  const VideoPlayerScreen({super.key, required this.url});
  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    String targetUrl = widget.url;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() => _isLoading = true),
          onPageFinished: (url) => setState(() => _isLoading = false),
          onWebResourceError: (error) => setState(() {
            _hasError = true;
            _isLoading = false;
          }),
        ),
      )
      ..loadRequest(Uri.parse(targetUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('MAYA JAAL PLAYER'),
        backgroundColor: Colors.black,
        foregroundColor: MatrixColors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: MatrixColors.green),
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser, color: MatrixColors.green),
            onPressed: () async {
              final uri = Uri.parse(widget.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_hasError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 15),
                  const Text(
                    'Video load nahi ho paya',
                    style: TextStyle(color: MatrixColors.green, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => _controller.reload(),
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: MatrixColors.green),
                    ),
                  ),
                ],
              ),
            )
          else
            WebViewWidget(controller: _controller),
          if (_isLoading && !_hasError)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: MatrixColors.green),
                    SizedBox(height: 15),
                    Text(
                      '> loading stream...',
                      style: TextStyle(
                        color: MatrixColors.green,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
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
