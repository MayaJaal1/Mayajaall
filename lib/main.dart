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
      home: const StreamScreen(),
    );
  }
}

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
      // App shuru hote hi check karein ki kya kisi link se khula hai
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null && initialUri.toString().contains('fileId=')) {
        _initWebView(initialUri.toString());
      }

      // Live link clicks listen karna
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
      appBar: AppBar(title: const Text('MayaJaal Video Player')),
      body: !isLoaded
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.video_library, size: 80, color: Colors.blue),
                    SizedBox(height: 20),
                    Text(
                      'Welcome to MayaJaal!',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Please click a video streaming link directly from your Telegram Bot to play.',
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
