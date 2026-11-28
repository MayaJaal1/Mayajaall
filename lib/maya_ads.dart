import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ads never gate playback, downloads, login, live rooms or creator earnings.
class MayaAds {
  static const enabled = bool.fromEnvironment('MAYA_ADS_ENABLED');
  static const test = bool.fromEnvironment('MAYA_ADS_TRIAL');
  // Enable only after verifying non-targeted delivery, audience and regional privacy requirements.
  static const contextualApproved = bool.fromEnvironment('MAYA_ADS_CONTEXTUAL_APPROVED');
  static const startEnabled = bool.fromEnvironment('MAYA_STARTIO_ENABLED');
  static const inmobiEnabled = bool.fromEnvironment('MAYA_INMOBI_ENABLED');
  static const startContextualApproved = bool.fromEnvironment('MAYA_STARTIO_CONTEXTUAL_APPROVED');
  static const _bridge = MethodChannel('mayajaal/ads');
  static const _oldConsentKey = test ? 'maya_ads_trial_consent_v2' : 'maya_ads_live_consent_v2';
  static const _consentKey = test ? 'maya_ads_trial_consent_v3' : 'maya_ads_live_consent_v3';
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
  static int retryGeneration = 0;
  static DateTime? _lastManualRetry;
  static bool get breakActive => adFreeUntil?.isAfter(DateTime.now()) ?? false;
  static String get networkNames => [if (_startPermitted) 'Start.io', if (_inmobiPermitted) 'InMobi'].join(' → ');
  static bool? consent;
  static DateTime? adFreeUntil;
  static Timer? _expiry;
  static bool _loaded = false;
  static bool sdkReady = false;
  static bool configuring = false;
  static String sdkStatus = 'Not initialized';
  static final deliveryStatus = ValueNotifier<String>('No ad request yet');
  static Future<void>? _loading;
  static DateTime? _qualifiedExit;
  static bool get available => enabled && Platform.isAndroid;
  static bool get _startPermitted => startEnabled && (consent == true || (!test && startContextualApproved && consent == null));
  static bool get _inmobiPermitted => inmobiEnabled && (consent == true || (!test && contextualApproved && consent == null));
  static bool get permitted => available && (_startPermitted || _inmobiPermitted);
  static bool get canShow => permitted && sdkReady && !breakActive;

  static Future<void> load() => _loading ??= _load();
  static Future<void> _load() async {
    if (_loaded || !available) return;
    try {
      final p = await SharedPreferences.getInstance();
      consent = p.getBool(_consentKey) ?? (p.getBool(_oldConsentKey) == false ? false : null);
      adFreeUntil = DateTime.fromMillisecondsSinceEpoch(p.getInt(_adFreeKey) ?? 0);
      _loaded = true;
      _scheduleExpiry();
      if (permitted) await _configure(true);
    } catch (e) { debugPrint('MayaAds init: $e'); }
    finally { changes.value++; }
  }
  static void _scheduleExpiry() {
    _expiry?.cancel();
    final remaining = adFreeUntil?.difference(DateTime.now());
    if (remaining != null && remaining > Duration.zero) {
      _expiry = Timer(remaining, () {
        adFreeUntil = null;
        retryGeneration++;
        deliveryStatus.value = 'Ad-free break ended; waiting for visible ad slot';
        changes.value++;
      });
    }
  }
  static Future<void> _configure(bool allowed) async {
    configuring = true;
    sdkReady = false;
    sdkStatus = allowed ? 'Initializing ad networks…' : 'Advertising disabled';
    deliveryStatus.value = allowed ? 'Initializing permitted networks' : 'Ads disabled by privacy choice or build configuration';
    changes.value++;
    try {
      final ok = await _bridge.invokeMethod<bool>('configure', {'start': allowed && _startPermitted, 'inmobi': allowed && _inmobiPermitted}).timeout(const Duration(seconds: 20));
      sdkReady = allowed && ok == true;
      sdkStatus = allowed ? (sdkReady ? 'Ad SDK ready' : 'Ad SDK initialization unsuccessful') : 'Advertising disabled';
      deliveryStatus.value = !allowed ? 'Ads disabled' : !sdkReady ? 'SDK initialization failed' : breakActive ? 'Existing ad-free break active until ${adFreeUntil!.toLocal()}' : 'SDK ready: $networkNames. Waiting for visible ad slot';
      debugPrint('MayaAds: $sdkStatus');
    } catch (e) {
      sdkStatus = 'Ad SDK initialization error: $e';
      deliveryStatus.value = sdkStatus;
      debugPrint('MayaAds configure: $e');
    } finally {
      configuring = false;
      changes.value++;
    }
  }
  static Future<void> setConsent(bool allowed) async {
    if (!available) return;
    await load();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_consentKey, allowed);
    consent = allowed;
    if (!allowed) _qualifiedExit = null;
    await _configure(allowed);
  }
  static Future<bool> retryAds() async {
    await load();
    if (!permitted || configuring) return false;
    if (breakActive) {
      deliveryStatus.value = 'Existing ad-free break active until ${adFreeUntil!.toLocal()}';
      return false;
    }
    final now = DateTime.now();
    if (_lastManualRetry != null && now.difference(_lastManualRetry!) < const Duration(seconds: 60)) {
      return false;
    }
    _lastManualRetry = now;
    await _configure(true);
    if (!canShow) return false;
    retryGeneration++;
    changes.value++;
    return true;
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
  static Future<void> settings(BuildContext context) => Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const _AdsSettings()));
}

class _AdsSettings extends StatefulWidget {
  const _AdsSettings();
  @override State<_AdsSettings> createState() => _AdsSettingsState();
}
class _AdsSettingsState extends State<_AdsSettings> {
  bool busy = false;
  String message = '';
  bool showDiagnostic = false;
  int diagnosticGeneration = 0;
  @override void initState() { super.initState(); unawaited(MayaAds.load()); }
  Future<void> _choose(bool allowed) async {
    setState(() { busy = true; showDiagnostic = false; message = ''; });
    try { await MayaAds.setConsent(allowed); }
    catch (_) { if (mounted) setState(() => message = 'Could not save your choice. Please retry.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> _retry() async {
    setState(() { busy = true; showDiagnostic = false; message = ''; });
    try {
      final ok = await MayaAds.retryAds();
      if (!mounted) return;
      setState(() {
        showDiagnostic = ok;
        if (ok) diagnosticGeneration++;
        message = ok ? 'Checking one visible banner. See delivery status above.' :
          MayaAds.breakActive ? 'An existing ad-free reward is still active.' :
          !MayaAds.sdkReady ? MayaAds.sdkStatus : 'Retry limited to once per minute.';
      });
    } catch (e) {
      if (mounted) setState(() => message = 'Retry failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff080e0b),
    appBar: AppBar(title: const Text('Privacy preferences')),
    body: ValueListenableBuilder<int>(valueListenable: MayaAds.changes, builder: (_, __, ___) => ListView(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24), children: [
      const Icon(Icons.shield_outlined, color: Color(0xff00e676), size: 54),
      const SizedBox(height: 20),
      const Text('Your choice. Your experience.', style: TextStyle(fontSize: 27, color: Colors.white, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      const Text('MayaJaal uses Start.io and InMobi to show ads. The ad SDK may collect and use advertising identifiers, device and network information to deliver and measure ads. Non-targeted ads may be shown where permitted. If consent is required, enable only if you are 18 or older and agree to the processing described. You can disable in-app ads here. Core features do not depend on this choice.', style: TextStyle(color: Colors.white70, height: 1.45)),
      if (MayaAds.test) const Padding(padding: EdgeInsets.only(top: 12), child: Text('Developer build: keep both networks in test mode. No real earnings.', style: TextStyle(color: Colors.amber))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : () => _choose(true), child: const Text('I am 18+ and allow ads')),
      OutlinedButton(onPressed: busy ? null : () => _choose(false), child: const Text('Do not allow ads')),
      const SizedBox(height: 12),
      Text(MayaAds.permitted ? 'Ads enabled' : 'Ads disabled', style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 12),
      Text('SDK: ${MayaAds.sdkStatus}', style: const TextStyle(color: Colors.white70)),
      ValueListenableBuilder<String>(valueListenable: MayaAds.deliveryStatus, builder: (_, value, __) => Text('Ad delivery: $value', style: const TextStyle(color: Colors.white70))),
      Text('Permitted networks: ${MayaAds.networkNames.isEmpty ? 'None' : MayaAds.networkNames}', style: const TextStyle(color: Colors.white70)),
      if (MayaAds.permitted) OutlinedButton(onPressed: busy || MayaAds.configuring || MayaAds.breakActive ? null : _retry, child: const Text('Retry ad connection')),
      if (MayaAds.breakActive) Text('Existing ad-free reward ends at ${MayaAds.adFreeUntil!.toLocal()}. Ads will resume automatically.', style: const TextStyle(color: Color(0xff00e676))),
      if (showDiagnostic && MayaAds.canShow) MayaAdSlot(key: ValueKey(diagnosticGeneration), retryAutomatically: false),
      if (busy) const LinearProgressIndicator(),
      if (message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(message, style: const TextStyle(color: Colors.white70))),
    ])),
  );
}

/// A real Android platform view; it collapses when the network has no ad.
class MayaAdSlot extends StatefulWidget {
  final bool nativeAd;
  final bool active;
  final bool retryAutomatically;
  const MayaAdSlot({super.key, this.nativeAd = false, this.active = true, this.retryAutomatically = true});
  @override State<MayaAdSlot> createState() => _MayaAdSlotState();
}
class _MayaAdSlotState extends State<MayaAdSlot> with WidgetsBindingObserver {
  bool foreground = true, failed = false;
  MethodChannel? _channel;
  int? _viewId;
  Timer? _timeout;
  Timer? _retry;
  int _attempt = 0;
  int _generation = MayaAds.retryGeneration;
  @override void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    MayaAds.changes.addListener(_changed); unawaited(MayaAds.load());
  }
  void _changed() {
    if (!mounted) return;
    setState(() {
      if (!MayaAds.canShow || _generation != MayaAds.retryGeneration) {
        _generation = MayaAds.retryGeneration;
        failed = false; _retry?.cancel(); _attempt = 0;
        _forgetView();
      }
    });
  }
  void _failed(String message) {
    if (!mounted) return;
    _timeout?.cancel();
    MayaAds.deliveryStatus.value = message;
    debugPrint('MayaAds slot: $message');
    setState(() => failed = true);
    _retry?.cancel();
    if (!widget.retryAutomatically) return;
    final delay = [60, 120, 240, 300][_attempt.clamp(0, 3).toInt()];
    _attempt++;
    _retry = Timer(Duration(seconds: delay), () {
      if (mounted && foreground && widget.active && MayaAds.canShow) {
        setState(() => failed = false);
      }
    });
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() { foreground = state == AppLifecycleState.resumed; if (!foreground) { _forgetView(); _retry?.cancel(); } else { failed = false; } });
  }
  @override void didUpdateWidget(covariant MayaAdSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) { failed = false; _retry?.cancel(); }
    if (!widget.active) _retry?.cancel();
  }
  void _forgetView() { _timeout?.cancel(); _channel?.setMethodCallHandler(null); _channel = null; _viewId = null; }
  void _onView(int id) {
    if (!mounted) return;
    _channel?.setMethodCallHandler(null); _timeout?.cancel();
    _viewId = id;
    final ch = MethodChannel('mayajaal/ads/view/$id'); _channel = ch;
    ch.setMethodCallHandler((call) async {
      if (!mounted || _viewId != id) return;
      if (call.method == 'status') {
        MayaAds.deliveryStatus.value = '${call.arguments ?? 'Ad request in progress'}';
      }
      if (call.method == 'loaded') {
        _timeout?.cancel();
        _attempt = 0;
        MayaAds.deliveryStatus.value = '${call.arguments ?? 'Ad network'}: ${widget.nativeAd ? 'Native ad loaded' : 'Banner loaded'}';
      }
      if (call.method == 'failed') {
        _failed('${call.arguments ?? 'Ad request failed'}');
      }
    });
    MayaAds.deliveryStatus.value = 'Requesting ${widget.nativeAd ? 'native' : 'banner'} via ${MayaAds.networkNames}';
    _timeout = Timer(const Duration(seconds: 55), () { if (mounted && _viewId == id) { _failed('Ad request timed out'); } });
    unawaited(ch.invokeMethod<void>('load').catchError((Object e) { if (mounted && _viewId == id) { _failed('Ad bridge error: $e'); } }));
  }
  @override void dispose() {
    _retry?.cancel(); _timeout?.cancel(); _channel?.setMethodCallHandler(null); MayaAds.changes.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this); super.dispose();
  }
  @override Widget build(BuildContext context) {
    if (!MayaAds.available || !widget.active || !foreground || ModalRoute.of(context)?.isCurrent != true) { _forgetView(); return const SizedBox.shrink(); }
    if (!MayaAds.canShow || failed) { _forgetView(); return const SizedBox.shrink(); }
    return LayoutBuilder(builder: (_, box) {
      if (box.maxWidth < (widget.nativeAd ? 260 : 320)) {
        if (!widget.retryAutomatically) return const Text('Not enough width for a 320dp banner. Rotate your device.', style: TextStyle(color: Colors.white70));
        return const SizedBox.shrink();
      }
      return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Sponsored', style: TextStyle(fontSize: 10, color: Colors.white54)),
        SizedBox(height: widget.nativeAd ? 320 : 50, width: widget.nativeAd ? box.maxWidth : 320,
          child: AndroidView(key: ValueKey(_generation), viewType: 'mayajaal/inmobi_slot', creationParams: {'native': widget.nativeAd}, creationParamsCodec: const StandardMessageCodec(), onPlatformViewCreated: _onView)),
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
