import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ads never gate playback, downloads, login, live rooms or creator earnings.
class MayaAds {
  static const enabled = bool.fromEnvironment('MAYA_ADS_ENABLED');
  static const test = bool.fromEnvironment('MAYA_ADS_TRIAL');
  static const _bridge = MethodChannel('mayajaal/ads');
  static const _consentKey = test ? 'maya_ads_trial_consent_v2' : 'maya_ads_live_consent_v2';
  static const _adFreeKey = test ? 'maya_ads_trial_free_until_v2' : 'maya_ads_live_free_until_v2';
  static const _vastTestTag = String.fromEnvironment('MAYA_VAST_TEST_TAG');
  // Production in-stream ads require a separately approved integration. Never use the sample tag for revenue.
  static bool get scheduledVideoAvailable => available && test;
  static Future<void> playScheduledVideo() async {
    if (!canShow || !scheduledVideoAvailable) return;
    try { await _bridge.invokeMethod<bool>('scheduledVideoTest', _vastTestTag); }
    catch (e) { debugPrint('MayaAds VAST trial: $e'); }
  }
  static final changes = ValueNotifier<int>(0);
  static bool? consent;
  static DateTime? adFreeUntil;
  static Timer? _expiry;
  static bool _loaded = false;
  static Future<void>? _loading;
  static DateTime? _qualifiedExit;
  static bool get available => enabled && Platform.isAndroid;
  static bool get permitted => available && consent == true;
  static bool get canShow => permitted && !(adFreeUntil?.isAfter(DateTime.now()) ?? false);

  static Future<void> load() => _loading ??= _load();
  static Future<void> _load() async {
    if (_loaded || !available) return;
    try {
      final p = await SharedPreferences.getInstance();
      consent = p.getBool(_consentKey);
      adFreeUntil = DateTime.fromMillisecondsSinceEpoch(p.getInt(_adFreeKey) ?? 0);
      _loaded = true;
      _scheduleExpiry();
      if (permitted) await _bridge.invokeMethod<bool>('configure', true).timeout(const Duration(seconds: 20));
    } catch (e) { debugPrint('MayaAds init: $e'); }
    finally { changes.value++; }
  }
  static void _scheduleExpiry() {
    _expiry?.cancel();
    final remaining = adFreeUntil?.difference(DateTime.now());
    if (remaining != null && remaining > Duration.zero) {
      _expiry = Timer(remaining, () => changes.value++);
    }
  }
  static Future<void> setConsent(bool allowed) async {
    if (!available) return;
    await load();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_consentKey, allowed);
    consent = allowed;
    if (!allowed) _qualifiedExit = null;
    changes.value++;
    try { await _bridge.invokeMethod<bool>('configure', allowed).timeout(const Duration(seconds: 20)); }
    catch (e) { debugPrint('MayaAds consent: $e'); }
    finally { changes.value++; }
  }
  static Future<void> prepareInterstitial() async {
    await load();
    if (!canShow) return;
    try { await _bridge.invokeMethod<void>('preload'); } catch (_) {}
  }
  static void beginVideo() { _qualifiedExit = null; }
  static void qualifyVideoExit() {
    if (canShow) _qualifiedExit = DateTime.now();
  }
  static Future<void> afterVideo(BuildContext context) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final at = _qualifiedExit; _qualifiedExit = null;
    if (!canShow || at == null || DateTime.now().difference(at) > const Duration(seconds: 8)) return;
    if (!context.mounted || ModalRoute.of(context)?.isCurrent != true || !canShow || WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    try { await _bridge.invokeMethod<void>('showInterstitial'); } catch (_) {}
  }
  static Future<bool> reward() async {
    if (!canShow) return false;
    try {
      final earned = await _bridge.invokeMethod<bool>('reward');
      if (earned != true || !permitted) return false;
      adFreeUntil = DateTime.now().add(const Duration(minutes: 30));
      final p = await SharedPreferences.getInstance();
      await p.setInt(_adFreeKey, adFreeUntil!.millisecondsSinceEpoch);
      _scheduleExpiry(); changes.value++;
      return true;
    } catch (_) { return false; }
  }
  static Future<void> settings(BuildContext context) => Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const _AdsSettings()));
}

class _AdsSettings extends StatefulWidget {
  const _AdsSettings();
  @override State<_AdsSettings> createState() => _AdsSettingsState();
}
class _AdsSettingsState extends State<_AdsSettings> {
  bool busy = false;
  String message = '';
  @override void initState() { super.initState(); unawaited(MayaAds.load()); }
  Future<void> _choose(bool allowed) async {
    setState(() => busy = true);
    try { await MayaAds.setConsent(allowed); }
    catch (_) { if (mounted) setState(() => message = 'Could not save your choice. Please retry.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> _reward() async {
    setState(() { busy = true; message = 'Loading optional video…'; });
    final earned = await MayaAds.reward();
    if (mounted) setState(() { busy = false; message = earned ? '30 minutes without MayaJaal in-app ads unlocked on this device.' : 'No reward received. You can continue using the app normally.'; });
  }
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff080e0b),
    appBar: AppBar(title: const Text('Advertising & privacy')),
    body: ValueListenableBuilder<int>(valueListenable: MayaAds.changes, builder: (_, __, ___) => ListView(padding: const EdgeInsets.all(24), children: [
      const Icon(Icons.shield_outlined, color: Color(0xff00e676), size: 54),
      const SizedBox(height: 20),
      const Text('Your choice. Your experience.', style: TextStyle(fontSize: 27, color: Colors.white, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      const Text('MayaJaal uses InMobi to show ads. The ad SDK may collect and use advertising identifiers, device and network information to deliver and measure ads. Only enable if you are 18 or older and consent to this processing. You can withdraw here at any time. Core features work without consent.', style: TextStyle(color: Colors.white70, height: 1.45)),
      if (MayaAds.test) const Padding(padding: EdgeInsets.only(top: 12), child: Text('Developer build: keep InMobi test mode enabled. No real earnings.', style: TextStyle(color: Colors.amber))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : () => _choose(true), child: const Text('I am 18+ and allow ads')),
      OutlinedButton(onPressed: busy ? null : () => _choose(false), child: const Text('Do not allow ads')),
      const SizedBox(height: 12),
      Text(MayaAds.consent == true ? 'Ads allowed' : 'Ads disabled', style: const TextStyle(color: Colors.white70)),
      const Divider(height: 40),
      const Text('Ad-free break', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
      const Text('Optional rewarded video: unlock 30 minutes without MayaJaal in-app ads on this device. No cash or creator earnings.', style: TextStyle(color: Colors.white70)),
      if (MayaAds.permitted && !MayaAds.canShow) const Text('Your ad-free break is active.', style: TextStyle(color: Color(0xff00e676))),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: busy || !MayaAds.canShow ? null : _reward, icon: const Icon(Icons.ondemand_video), label: const Text('Watch optional video')),
      if (busy) const LinearProgressIndicator(),
      if (message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(message, style: const TextStyle(color: Colors.white70))),
    ])),
  );
}

/// A real Android platform view; it collapses when the network has no ad.
class MayaAdSlot extends StatefulWidget {
  final bool nativeAd;
  final bool active;
  final bool askConsent;
  const MayaAdSlot({super.key, this.nativeAd = false, this.active = true, this.askConsent = false});
  @override State<MayaAdSlot> createState() => _MayaAdSlotState();
}
class _MayaAdSlotState extends State<MayaAdSlot> with WidgetsBindingObserver {
  bool foreground = true, failed = false;
  MethodChannel? _channel;
  int? _viewId;
  Timer? _timeout;
  @override void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    foreground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    MayaAds.changes.addListener(_changed); unawaited(MayaAds.load());
  }
  void _changed() { if (mounted) setState(() { if (!MayaAds.canShow) failed = false; }); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() { foreground = state == AppLifecycleState.resumed; if (!foreground) _forgetView(); });
  }
  @override void didUpdateWidget(covariant MayaAdSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) failed = false;
  }
  void _forgetView() { _timeout?.cancel(); _channel?.setMethodCallHandler(null); _channel = null; _viewId = null; }
  void _onView(int id) {
    if (!mounted) return;
    _channel?.setMethodCallHandler(null); _timeout?.cancel();
    _viewId = id;
    final ch = MethodChannel('mayajaal/ads/view/$id'); _channel = ch;
    ch.setMethodCallHandler((call) async {
      if (!mounted || _viewId != id) return;
      if (call.method == 'loaded') _timeout?.cancel();
      if (call.method == 'failed') { _timeout?.cancel(); setState(() => failed = true); }
    });
    _timeout = Timer(const Duration(seconds: 35), () { if (mounted && _viewId == id) setState(() => failed = true); });
    unawaited(ch.invokeMethod<void>('load').catchError((Object _) { if (mounted && _viewId == id) setState(() => failed = true); }));
  }
  @override void dispose() {
    _timeout?.cancel(); _channel?.setMethodCallHandler(null); MayaAds.changes.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this); super.dispose();
  }
  @override Widget build(BuildContext context) {
    if (!MayaAds.available || !widget.active || !foreground || ModalRoute.of(context)?.isCurrent != true) { _forgetView(); return const SizedBox.shrink(); }
    if (widget.askConsent && MayaAds.consent == null) {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: TextButton.icon(onPressed: () => MayaAds.settings(context), icon: const Icon(Icons.privacy_tip_outlined, size: 16), label: const Text('Advertising preferences')));
    }
    if (!MayaAds.canShow || failed) { _forgetView(); return const SizedBox.shrink(); }
    return LayoutBuilder(builder: (_, box) {
      if (box.maxWidth < (widget.nativeAd ? 260 : 320)) return const SizedBox.shrink();
      return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Sponsored', style: TextStyle(fontSize: 10, color: Colors.white54)),
        SizedBox(height: widget.nativeAd ? 320 : 50, width: widget.nativeAd ? box.maxWidth : 320,
          child: AndroidView(viewType: 'mayajaal/inmobi_slot', creationParams: {'native': widget.nativeAd}, creationParamsCodec: const StandardMessageCodec(), onPlatformViewCreated: _onView)),
      ]));
    });
  }
}

/// Elapsed foreground watch time, not the seekable media position.
/// Each threshold is consumed at most once in the current video screen.
class MayaVideoAdSchedule {
  static const seconds = <int>[10, 60, 600, 1200, 2400, 4800, 9600, 15000];
  int _elapsedMs = 0;
  int _next = 0;
  bool add(int elapsedMs) {
    if (elapsedMs <= 0) return false;
    _elapsedMs += elapsedMs;
    var due = false;
    while (_next < seconds.length && _elapsedMs >= seconds[_next] * 1000) {
      _next++;
      due = true;
    }
    return due;
  }
}
