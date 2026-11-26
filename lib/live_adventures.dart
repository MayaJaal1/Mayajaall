import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';

const _base = String.fromEnvironment(
  'MAYA_LIVE_API',
  defaultValue: 'https://www.mayajaal.online/live-api',
);

const _mint = Color(0xff00e676);

Map<String, dynamic> _parseLiveResponse(int status, String text) {
  Object? decoded;
  try {
    decoded = jsonDecode(text);
  } catch (_) {}
  final data = decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  if (status < 200 || status >= 300) {
    final detail = data?['error'] ?? data?['detail'] ?? data?['message'];
    if (detail is String && detail.trim().isNotEmpty) {
      throw Exception(detail.length > 240 ? detail.substring(0, 240) : detail);
    }
    throw Exception('Live service HTTP $status. Please try again.');
  }
  if (data == null)
    throw Exception(
        'The live service returned an invalid response. Please retry.');
  return data;
}

Future<Map<String, dynamic>> _api(String path,
    {Map<String, dynamic>? body}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Sign in first');
  final uri =
      Uri.tryParse('${_base.trim().replaceAll(RegExp(r'/+$'), '')}$path');
  if (uri == null ||
      uri.scheme != 'https' ||
      !uri.hasAuthority ||
      uri.host.isEmpty) {
    throw Exception('A valid HTTPS live service address is required.');
  }
  final client = http.Client();
  try {
    Future<http.Response> send(bool refresh) async {
      final token = await user.getIdToken(refresh);
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      };
      return await (body == null
              ? client.get(uri, headers: headers)
              : client.post(uri, headers: headers, body: jsonEncode(body)))
          .timeout(const Duration(seconds: 15));
    }

    var response = await send(false);
    if (response.statusCode == 401) response = await send(true);
    if (FirebaseAuth.instance.currentUser?.uid != user.uid)
      throw Exception('Sign in again to continue.');
    return _parseLiveResponse(response.statusCode, response.body);
  } on TimeoutException {
    throw Exception(
        'The live service took too long to respond. Please try again.');
  } finally {
    client.close();
  }
}

class LiveAdventuresScreen extends StatefulWidget {
  const LiveAdventuresScreen({super.key});

  @override
  State<LiveAdventuresScreen> createState() => _LiveAdventuresState();
}

class _LiveAdventuresState extends State<LiveAdventuresScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> rooms = [];
  bool _refreshing = false, _foreground = true;
  String? error;
  bool busy = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(refresh());

    timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (mounted &&
            _foreground &&
            !busy &&
            (ModalRoute.of(context)?.isCurrent ?? true)) unawaited(refresh());
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && mounted && (ModalRoute.of(context)?.isCurrent ?? true))
      unawaited(refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (_refreshing || !_foreground || !mounted) return;
    _refreshing = true;
    try {
      final response = await _api('/rooms');
      final value = response['rooms'];
      if (value is! List) throw Exception('Invalid room list');
      final next = value
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .where((r) => r['id'] is String && (r['id'] as String).isNotEmpty)
          .toList();
      if (mounted)
        setState(() {
          rooms = next;
          error = null;
        });
    } catch (_) {
      if (mounted)
        setState(
            () => error = 'Could not load live adventures. Pull to retry.');
    } finally {
      _refreshing = false;
    }
  }

  Future<void> enter({
    String? id,
    String? title,
    bool video = true,
  }) async {
    if (busy) return;

    setState(() => busy = true);

    try {
      if (id == null) {
        if (!await Permission.microphone.request().isGranted) {
          throw Exception('Microphone permission required');
        }

        if (video && !await Permission.camera.request().isGranted) {
          throw Exception('Camera permission required');
        }
      }

      final r = await _api(
        id == null ? '/host' : '/join',
        body: id == null
            ? {
                'title': title,
                'video': video,
              }
            : {
                'id': id,
              },
      );

      if (r['url'] is! String ||
          r['token'] is! String ||
          r['id'] is! String ||
          (r['url'] as String).isEmpty ||
          (r['token'] as String).isEmpty) {
        throw Exception(
            'The live service returned incomplete connection details.');
      }
      if (!mounted) {
        if (id == null) {
          try {
            await _api('/end', body: {'id': r['id']});
          } catch (_) {}
        }
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _AdventureRoom(
            data: r,
            host: id == null,
            video: video,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        refresh();
      }
    }
  }

  Future<void> create() async {
    String title = '';
    bool video = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Start an adventure'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                maxLength: 80,
                onChanged: (v) => title = v,
                decoration: const InputDecoration(
                  labelText: 'Adventure title',
                ),
              ),
              SwitchListTile(
                title: const Text('Video (off = audio only)'),
                value: video,
                onChanged: (v) => update(() => video = v),
              ),
              const Text(
                'Broadcast only with consent. Do not film '
                'private locations or dangerous activities.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted && title.trim().isNotEmpty) {
      await enter(
        title: title.trim(),
        video: video,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'LIVE ADVENTURES',
              style: TextStyle(
                color: _mint,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Explore the world together. Join a real-time broadcast.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: busy ? null : create,
              icon: const Icon(Icons.sensors),
              label: const Text('Go live'),
            ),
            const SizedBox(height: 24),
            const Text(
              'On air',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(error!),
              ),
            if (error == null && rooms.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No active adventures right now.'),
              ),
            for (final r in rooms)
              Card(
                child: ListTile(
                  leading: Icon(
                    r['video'] == true ? Icons.videocam : Icons.mic,
                    color: _mint,
                  ),
                  title: Text('${r['title']}'),
                  subtitle: Text('${r['hostName']} • LIVE'),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: busy ? null : () => enter(id: r['id'] as String),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdventureRoom extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool host;
  final bool video;

  const _AdventureRoom({
    required this.data,
    required this.host,
    required this.video,
  });

  @override
  State<_AdventureRoom> createState() => _AdventureRoomState();
}

class _AdventureRoomState extends State<_AdventureRoom> {
  final room = lk.Room();

  Future<void>? _ending;
  String? error;

  bool ready = false;
  bool muted = false;
  bool camera = true;
  bool closing = false;

  @override
  void initState() {
    super.initState();

    camera = widget.video;
    connect();

    room.addListener(_roomChanged);
  }

  void _roomChanged() {
    if (mounted && !closing) setState(() {});
  }

  Future<void> connect() async {
    try {
      await room.connect(
        widget.data['url'] as String,
        widget.data['token'] as String,
      );

      if (!mounted || closing) {
        await room.disconnect();
        return;
      }

      if (widget.host) {
        await room.localParticipant!.setMicrophoneEnabled(true);

        if (!mounted || closing) {
          await room.disconnect();
          return;
        }
        if (widget.video) {
          await room.localParticipant!.setCameraEnabled(true);
        }
      }

      if (mounted && !closing) {
        setState(() => ready = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Connection failed: $e');
      }

      await end();
    }
  }

  Future<void> end() => _ending ??= _close();

  Future<void> _close() async {
    closing = true;

    try {
      await room.disconnect();
    } catch (_) {}

    if (widget.host) {
      try {
        await _api(
          '/end',
          body: {
            'id': widget.data['id'],
          },
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    room.removeListener(_roomChanged);

    unawaited(
      end().whenComplete(() => room.dispose()),
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    lk.VideoTrack? track;

    // FIX: Explicit participant type for LiveKit.
    final participants = <lk.Participant>[
      if (widget.host) ...[
        if (room.localParticipant != null) room.localParticipant!,
      ] else
        ...room.remoteParticipants.values,
    ];

    for (final p in participants) {
      for (final pub in p.videoTrackPublications) {
        final t = pub.track;

        if (t is lk.VideoTrack) {
          track = t;
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.data['title']}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: error != null
                  ? Text(error!)
                  : !ready
                      ? const CircularProgressIndicator()
                      : track != null
                          ? lk.VideoTrackRenderer(track)
                          : const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.graphic_eq,
                                  size: 80,
                                  color: _mint,
                                ),
                                Text('Audio / waiting for video'),
                              ],
                            ),
            ),
          ),
          if (widget.host && ready)
            Wrap(
              children: [
                IconButton(
                  tooltip: 'Toggle microphone',
                  onPressed: () async {
                    try {
                      await room.localParticipant!.setMicrophoneEnabled(muted);

                      if (mounted) {
                        setState(() => muted = !muted);
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() => error = '$e');
                      }
                    }
                  },
                  icon: Icon(
                    muted ? Icons.mic_off : Icons.mic,
                  ),
                ),
                if (widget.video)
                  IconButton(
                    tooltip: 'Toggle camera',
                    onPressed: () async {
                      try {
                        await room.localParticipant!.setCameraEnabled(!camera);

                        if (mounted) {
                          setState(() => camera = !camera);
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => error = '$e');
                        }
                      }
                    },
                    icon: Icon(
                      camera ? Icons.videocam : Icons.videocam_off,
                    ),
                  ),
              ],
            ),
          SafeArea(
            child: FilledButton(
              onPressed: closing
                  ? null
                  : () async {
                      setState(() => closing = true);
                      await end();

                      if (mounted) {
                        Navigator.pop(context);
                      }
                    },
              child: Text(
                widget.host
                    ? (closing ? 'Ending broadcast…' : 'End broadcast')
                    : (closing ? 'Leaving…' : 'Leave adventure'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
