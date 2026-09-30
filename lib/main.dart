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

const String supabaseUrl = 'https://inxlnctaixbkfblwlmhr.supabase.co';
const String supabaseAnonKey = 'sb_publishable_6b9xe3mDBduO-soZTk3t2A_W1sQpD5K';
const String webClientId = '985001671962-rok8qnng0rumjsd8mgr8uhr92o5vhs4n.apps.googleusercontent.com';

const Color kGreen = Color(0xFF00FF41);
const Color kBg = Color(0xFF000000);
const Color kCardBg = Color(0xFF0A0A0A);
const Color kDimGreen = Color(0xFF4FBF8B);

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_theme') ?? true;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
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

    // 🌟 Agar app pehle se open ho to direct player screen par redirect karein
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(url: finalUrl),
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
                  : VideoPlayerScreen(url: _incomingUrl!)),
        );
      },
    );
  }
}
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
  static const _chars = 'アイウエオカキクケコサシスセソタチツテトナニヌネノ0123456789ABCDEFXYZ';

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
              title: const Text('Settings', style: TextStyle(color: kGreen)),
              onTap: () {
                Navigator.pop(c);
                Navigator.push(c, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep, color: Colors.orange),
              title: const Text('Clear History', style: TextStyle(color: Colors.orange)),
              onTap: () {
                Navigator.pop(c);
                _clearHistory();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
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
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
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
                        user?.email ?? 'User',
                        style: const TextStyle(color: kGreen, fontSize: 13, fontFamily: 'monospace'),
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
                        style: const TextStyle(color: kGreen, fontFamily: 'monospace', fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Paste Mayajaal link here...',
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
              const Text(
                '> WATCH HISTORY',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kGreen, letterSpacing: 2),
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
                            Text('no history yet', style: TextStyle(color: kGreen.withOpacity(0.6), fontFamily: 'monospace')),
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
                                item.length > 50 ? '${item.substring(0, 50)}...' : item,
                                style: const TextStyle(fontSize: 12, color: kGreen, fontFamily: 'monospace'),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                                onPressed: () => _deleteHistoryItem(i),
                              ),
                              onTap: () {
                                Navigator.push(
                                  c,
                                  MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: item)),
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
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkTheme = true;
  String _language = 'English';
  String _downloadLocation = 'Internal Storage / Mayajaall';

  final List<String> _languages = ['English', 'Hindi', 'Bengali', 'Tamil', 'Telugu', 'Marathi', 'Gujarati', 'Kannada', 'Malayalam', 'Punjabi'];
  final List<String> _downloadLocations = ['Internal Storage / Mayajaall', 'Internal Storage / Download', 'Internal Storage / Movies', 'SD Card / Mayajaall'];

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
      appBar: AppBar(title: const Text('SETTINGS'), backgroundColor: kBg, foregroundColor: kGreen),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.dark_mode, color: kGreen),
            title: const Text('Dark Theme', style: TextStyle(color: kGreen, fontFamily: 'monospace')),
            subtitle: Text(_darkTheme ? 'ON' : 'OFF', style: TextStyle(color: kGreen.withOpacity(0.6), fontSize: 12)),
            trailing: Switch(value: _darkTheme, activeColor: kGreen, onChanged: _saveDarkTheme),
          ),
          Divider(color: kGreen.withOpacity(0.2)),
          ListTile(
            leading: const Icon(Icons.language, color: kGreen),
            title: const Text('Language', style: TextStyle(color: kGreen, fontFamily: 'monospace')),
            subtitle: Text(_language, style: TextStyle(color: kGreen.withOpacity(0.6), fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: kGreen),
            onTap: () => _showLanguageDialog(),
          ),
          Divider(color: kGreen.withOpacity(0.2)),
          ListTile(
            leading: const Icon(Icons.download, color: kGreen),
            title: const Text('Download Location', style: TextStyle(color: kGreen, fontFamily: 'monospace')),
            subtitle: Text(_downloadLocation, style: TextStyle(color: kGreen.withOpacity(0.6), fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: kGreen),
            onTap: () => _showDownloadLocationDialog(),
          ),
          Divider(color: kGreen.withOpacity(0.2)),
          const SizedBox(height: 30),
          Center(
            child: Text('> MayaJaal v1.0.0', style: TextStyle(color: kGreen.withOpacity(0.5), fontFamily: 'monospace', fontSize: 12)),
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
        title: const Text('Select Language', style: TextStyle(color: kGreen)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _languages.length,
            itemBuilder: (c2, i) => RadioListTile<String>(
              title: Text(_languages[i], style: const TextStyle(color: kGreen)),
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
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel', style: TextStyle(color: kDimGreen))),
        ],
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
        title: const Text('Select Download Location', style: TextStyle(color: kGreen)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _downloadLocations.length,
            itemBuilder: (c2, i) => RadioListTile<String>(
              title: Text(_downloadLocations[i], style: const TextStyle(color: kGreen, fontSize: 13)),
              value: _downloadLocations[i],
              groupValue: _downloadLocation,
              activeColor: kGreen,
              onChanged: (value) {
                if (value != null) {
                  _saveDownloadLocation(value);
                  Navigator.pop(c);
                }
              },
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel', style: TextStyle(color: kDimGreen))),
        ],
      ),
    );
  }
}

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
      ..loadRequest(Uri.parse(widget.url));
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
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser, color: kGreen),
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
                  const Icon(Icons.error_outline, size: 70, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Video load nahi ho paya',
                    style: TextStyle(color: kGreen, fontSize: 18, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _controller.reload(),
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
                    child: const Text('Go Back', style: TextStyle(color: kGreen)),
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
                    CircularProgressIndicator(color: kGreen),
                    SizedBox(height: 15),
                    Text(
                      '> loading stream...',
                      style: TextStyle(color: kGreen, fontFamily: 'monospace', letterSpacing: 2),
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
