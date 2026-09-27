import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:app_links/app_links.dart';

void main() {
  runApp(const MayaJaalApp());
}

class MayaJaalApp extends StatelessWidget {
  const MayaJaalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MayaJaal',
      theme: ThemeData(primarySwatch: Colors.blue),
      // App shuru hote hi Login Screen dikhegi
      home: const LoginScreen(),
    );
  }
}

// ==================== 1. LOGIN SCREEN ====================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _handleLogin() {
    // Yahan aap apna login validation laga sakte ho (jaise Firebase ya API)
    if (_usernameController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
      // Login successful hone par StreamScreen (Main App) par bhej do
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const StreamScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter username and password')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.video_library, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                const Text(
                  'Welcome to MayaJaal',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    onPressed: _handleLogin,
                    child: const Text('Login', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== 2. STREAM / PLAYER SCREEN ====================
class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key});

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  late final WebViewController _controller;
  bool isLoaded = false;
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _initWebView("");
    _initDeepLinks();
  }

  void _initWebView(String url) {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000));

    if (url.isNotEmpty) {
      setState(() {
        isLoaded = true;
      });
      _controller.loadRequest(Uri.parse(url));
    }
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null && initialUri.toString().contains('fileId=')) {
        _initWebView(initialUri.toString());
      }

      _appLinks.uriLinkStream.listen((uri) {
        if (uri.toString().isNotEmpty && uri.toString().contains('fileId=')) {
          setState(() {
            isLoaded = true;
          });
          _controller.loadRequest(Uri.parse(uri.toString()));
        }
      });
    } catch (e) {
      debugPrint("Deep link error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MayaJaal Video Player'),
        backgroundColor: Colors.grey[900],
      ),
      body: !isLoaded
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.play_circle_filled, size: 80, color: Colors.blue),
                    SizedBox(height: 20),
                    Text(
                      'Logged in Successfully!',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Now, click any video streaming link from your Telegram Bot to play it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : WebViewWidget(controller: _controller),
      backgroundColor: Colors.black,
    );
  }
}
