import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';

const _base = String.fromEnvironment('MAYA_LIVE_API', defaultValue: 'https://www.mayajaal.online/live-api');
const _mint = Color(0xff00e676);
Future<Map<String, dynamic>> _api(String path, {Map<String,dynamic>? body}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Sign in first');
  final token = await user.getIdToken();
  final uri = Uri.parse('$_base$path');
  if (uri.scheme != 'https') throw Exception('HTTPS required');
  final headers = {'Authorization':'Bearer $token','Content-Type':'application/json'};
  final response = await (body == null ? http.get(uri,headers:headers) : http.post(uri,headers:headers,body:jsonEncode(body))).timeout(const Duration(seconds:15));
  final data = jsonDecode(response.body) as Map<String,dynamic>;
  if(response.statusCode != 200) throw Exception(data['error'] ?? 'Live service unavailable');
  return data;
}
class LiveAdventuresScreen extends StatefulWidget {
  const LiveAdventuresScreen({super.key});
  @override State<LiveAdventuresScreen> createState()=>_LiveAdventuresState();
}
class _LiveAdventuresState extends State<LiveAdventuresScreen> {
  List<dynamic> rooms=[]; String? error; bool busy=false; Timer? timer;
  @override void initState(){super.initState(); refresh(); timer=Timer.periodic(const Duration(seconds:10),(_)=>refresh());}
  @override void dispose(){timer?.cancel();super.dispose();}
  Future<void> refresh() async {if(refreshing)return;refreshing=true;try {final r=await _api('/rooms'); if(mounted)setState((){rooms=r['rooms'] as List;error=null;loaded=true;});}catch(e){if(mounted)setState(()=>error='Could not load live adventures. Pull to retry.');}finally{refreshing=false;}}
  Future<void> enter({String? id,String? title,bool video=true, lk.CameraPosition position=lk.CameraPosition.front}) async {
    if(busy)return; setState(()=>busy=true);
    try {
      if(id==null){if(!await Permission.microphone.request().isGranted)throw Exception('Microphone permission required');if(video && !await Permission.camera.request().isGranted)throw Exception('Camera permission required');}
      final r=await _api(id==null?'/host':'/join',body:id==null?{'title':title,'video':video}:{'id':id});
      if(!mounted)return;
      await Navigator.of(context).push(MaterialPageRoute(builder:(_)=>_AdventureRoom(data:r,host:id==null,video:video,position:position)));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}finally{if(mounted){setState(()=>busy=false);refresh();}}
  }
  Future<void> create() async {
    final result=await Navigator.of(context).push<Map<String,dynamic>>(MaterialPageRoute(builder:(_)=>const _WorldStudio()));
    if(result!=null && mounted) await enter(title:result['title'] as String,video:result['video'] as bool,position:result['position'] as lk.CameraPosition);
  }

  String query = '';
  int mode = 0;
  bool loaded = false;
  bool refreshing = false;
  @override
  Widget build(BuildContext context) {
    final visible = rooms.where((r) {
      final matches = '${r['title']} ${r['hostName']}'.toLowerCase().contains(query.toLowerCase());
      return matches && (mode == 0 || (mode == 1 ? r['video'] == true : r['video'] != true));
    }).toList();
    return Theme(data: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black), child: ColoredBox(color: Colors.black, child: SafeArea(child: RefreshIndicator(color: _mint, onRefresh: refresh, child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
      SliverPadding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 12), sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Expanded(child: _WorldBrand()), IconButton(tooltip: 'Refresh', onPressed: refresh, icon: const Icon(Icons.refresh_rounded, color: _mint))]),
        const SizedBox(height: 24),
        const Text('DISCOVER  /  CONNECT', style: TextStyle(color: _mint, fontSize: 11, letterSpacing: 2.2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('See the world\nlive.', style: TextStyle(color: Colors.white, fontSize: 38, height: 1.06, letterSpacing: -1.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text('Real people. Real moments. Anywhere.', style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5)),
        const SizedBox(height: 22),
        Material(color: const Color(0xff10251c), borderRadius: BorderRadius.circular(20), child: InkWell(borderRadius: BorderRadius.circular(20), onTap: busy ? null : create, child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: _mint, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.sensors_rounded, color: Colors.black)),
          const SizedBox(width: 14), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Creator Studio', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)), SizedBox(height: 4), Text('Start a video or audio live', style: TextStyle(color: Colors.white60, fontSize: 12))])), const Icon(Icons.arrow_forward_rounded, color: _mint)
        ])))),
        const SizedBox(height: 28),
        Row(children: [const Expanded(child: Text('Live now', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.6))), Text('${rooms.length} broadcasts', style: const TextStyle(color: _mint, fontSize: 12))]),
        const SizedBox(height: 14),
        TextField(onChanged: (v) => setState(() => query = v), style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Search live broadcasts', prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54), filled: true, fillColor: const Color(0xff151817), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [for (var i = 0; i < 3; i++) ChoiceChip(label: Text(['All live', 'Video', 'Audio'][i]), selected: mode == i, selectedColor: const Color(0xff16442d), onSelected: (_) => setState(() => mode = i))]),
        if (busy) const LinearProgressIndicator(color: _mint),
        if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(error!, style: const TextStyle(color: Colors.orangeAccent))),
      ]))),
      if (!loaded && error == null) const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(color: _mint)))
      else if (visible.isEmpty) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [const Icon(Icons.public_rounded, color: Colors.white38, size: 42), const SizedBox(height: 12), Text(rooms.isEmpty ? 'No broadcasts available' : 'No matching broadcasts', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)), const SizedBox(height: 8), TextButton(onPressed: refresh, child: const Text('Refresh', style: TextStyle(color: _mint)))])))
      else SliverPadding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), sliver: SliverGrid(delegate: SliverChildBuilderDelegate((context, i) {
        final r = visible[i]; final video = r['video'] == true;
        return Material(color: const Color(0xff151817), borderRadius: BorderRadius.circular(18), clipBehavior: Clip.antiAlias, child: InkWell(onTap: busy ? null : () => enter(id: r['id'] as String, video: video), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Stack(fit: StackFit.expand, children: [DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: video ? const [Color(0xff214b38), Color(0xff101916)] : const [Color(0xff263849), Color(0xff11191f)]))), Center(child: Icon(video ? Icons.videocam_outlined : Icons.graphic_eq_rounded, size: 42, color: Colors.white54)), Positioned(top: 10, left: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xffc62828), borderRadius: BorderRadius.circular(6)), child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)))), const Positioned(bottom: 10, right: 10, child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28))])),
          Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${r['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text('${r['hostName']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12)), const SizedBox(height: 5), Text(video ? 'Watch live' : 'Listen live', style: const TextStyle(color: _mint, fontSize: 11, fontWeight: FontWeight.w600))]))
        ])));
      }, childCount: visible.length), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, mainAxisExtent: 225, crossAxisSpacing: 12, mainAxisSpacing: 12))),
    ])))));
  }

}
class _AdventureRoom extends StatefulWidget {
  final Map<String,dynamic> data; final bool host,video; final lk.CameraPosition position;
  const _AdventureRoom({required this.data,required this.host,required this.video,required this.position});
  @override State<_AdventureRoom> createState()=>_AdventureRoomState();
}
class _AdventureRoomState extends State<_AdventureRoom> {
  lk.Room room=lk.Room(); late lk.CameraPosition position=widget.position; bool flipping=false;
  Future<void> flipCamera() async {if(flipping||!camera)return; final p=room.localParticipant;if(p==null)return; flipping=true;try{for(final pub in p.videoTrackPublications){final t=pub.track;if(t is lk.LocalVideoTrack){final next=position==lk.CameraPosition.front?lk.CameraPosition.back:lk.CameraPosition.front;await t.setCameraPosition(next);if(mounted)setState(()=>position=next);break;}}}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text("Camera switch failed: $e")));}finally{flipping=false;}}
   Timer? ticker, chatTimer; final chatInput=TextEditingController(); List<dynamic> messages=[]; bool showChat=true; bool sending=false; final started=Stopwatch();
  Future<void> loadChat() async {if(!ready||closing)return;try{final r=await _api('/chat/${widget.data['id']}');if(mounted)setState(()=>messages=r['messages'] as List);}catch(_) {}}
  Future<void> sendChat() async {final text=chatInput.text.trim();if(text.isEmpty||sending)return;sending=true;try{await _api('/chat',body:{'id':widget.data['id'],'text':text});if(mounted){chatInput.clear();await loadChat();}}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}finally{sending=false;}}
   String? error; bool connecting=false; bool ready=false, muted=false, camera=true, closing=false;
  @override void initState(){super.initState();camera=widget.video;connect();chatTimer=Timer.periodic(const Duration(seconds:5),(_)=>loadChat());ticker=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState((){});});}
  Future<void> connect() async {if(connecting||closing)return; connecting=true; if(mounted)setState((){error=null;ready=false;});try{await room.connect(widget.data['url'] as String,widget.data['token'] as String);if(!mounted){await room.disconnect();return;}if(widget.host){await room.localParticipant!.setMicrophoneEnabled(true);if(widget.video)await room.localParticipant!.setCameraEnabled(true,cameraCaptureOptions:lk.CameraCaptureOptions(cameraPosition:position));}if(mounted){started.start();setState(()=>ready=true);}}catch(e){if(mounted)setState(()=>error='Connection failed: $e');}finally{connecting=false;}}
  Future<void> end() async {if(closing)return;closing=true;try{await room.disconnect();}catch(_){}if(widget.host){try{await _api('/end',body:{'id':widget.data['id']});}catch(_){}}}
  @override void dispose(){ticker?.cancel();chatTimer?.cancel();chatInput.dispose();unawaited(end().whenComplete(()=>room.dispose()));super.dispose();}
  @override Widget build(BuildContext context){lk.VideoTrack? track;if(widget.host){final p=room.localParticipant;if(p!=null){for(final pub in p.videoTrackPublications){final t=pub.track;if(t is lk.VideoTrack){track=t;break;}}}}else{for(final p in room.remoteParticipants.values){for(final pub in p.videoTrackPublications){final t=pub.track;if(t is lk.VideoTrack){track=t;break;}}}}return Scaffold(backgroundColor:Colors.black,body:Stack(fit:StackFit.expand,children:[
if(track!=null) lk.VideoTrackRenderer(track) else Center(child:Padding(padding:const EdgeInsets.all(32),child:!ready&&error==null?const CircularProgressIndicator():Text(error??'Audio broadcast / waiting for video',textAlign:TextAlign.center,style:const TextStyle(color:Colors.white)))),
const IgnorePointer(child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.black87,Colors.transparent,Colors.transparent,Colors.black87],stops:[0,.22,.55,1])))),
SafeArea(child:Column(children:[Container(padding:const EdgeInsets.all(16),color:Colors.transparent,child:Row(children:[IconButton(onPressed:()async{await end();if(mounted)Navigator.pop(context);},icon:const Icon(Icons.arrow_back,color:Colors.white)),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const _WorldBrand(),Text('${widget.data['title']}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:18)),Text(ready?'${started.elapsed.inMinutes.toString().padLeft(2,'0')}:${(started.elapsed.inSeconds%60).toString().padLeft(2,'0')} • ${widget.host?room.remoteParticipants.length:(room.remoteParticipants.length-1).clamp(0, 999999)} viewers':'Connecting',style:const TextStyle(color:Colors.white70))])),if(ready)const Chip(label:Text('LIVE',style:TextStyle(color:Colors.white)),backgroundColor:Colors.red)])),const Spacer(),if(ready&&showChat) SizedBox(height:160,child:ListView(reverse:true,padding:const EdgeInsets.symmetric(horizontal:16),children:[for(final m in messages.reversed) Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Text('${m['name']}: ${m['text']}',style:const TextStyle(color:Colors.white,shadows:[Shadow(blurRadius:5,color:Colors.black)])))])),if(ready) Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:Row(children:[IconButton(onPressed:()=>setState(()=>showChat=!showChat),icon:const Icon(Icons.chat_bubble_outline,color:Colors.white)),Expanded(child:TextField(controller:chatInput,maxLength:300,style:const TextStyle(color:Colors.white),decoration:InputDecoration(counterText:'',hintText:'Say something…',filled:true,fillColor:Colors.black54,border:OutlineInputBorder(borderRadius:BorderRadius.circular(30))),onSubmitted:(_)=>sendChat())),IconButton(onPressed:sendChat,icon:const Icon(Icons.send,color:_mint))])),if(error!=null)Padding(padding:const EdgeInsets.all(12),child:Column(children:[Text(error!,style:const TextStyle(color:Colors.white)),if(!ready)OutlinedButton(onPressed:connecting?null:()async{await room.disconnect();await room.dispose();if(!mounted||closing)return;room=lk.Room();await connect();},child:const Text('Retry connection'))])),Container(color:Colors.transparent,padding:const EdgeInsets.all(16),child:Column(children:[if(widget.host&&ready)Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[IconButton(tooltip:'Microphone',onPressed:()async{try{await room.localParticipant!.setMicrophoneEnabled(muted);if(mounted)setState(()=>muted=!muted);}catch(e){if(mounted)setState(()=>error='$e');}},icon:Icon(muted?Icons.mic_off:Icons.mic,color:Colors.white)),if(widget.video&&camera)IconButton(tooltip:'Switch front / back camera',onPressed:flipCamera,icon:const Icon(Icons.cameraswitch,color:_mint)),if(widget.video)IconButton(tooltip:'Camera',onPressed:()async{try{await room.localParticipant!.setCameraEnabled(!camera,cameraCaptureOptions:lk.CameraCaptureOptions(cameraPosition:position));if(mounted)setState(()=>camera=!camera);}catch(e){if(mounted)setState(()=>error='$e');}},icon:Icon(camera?Icons.videocam:Icons.videocam_off,color:Colors.white))]),SizedBox(width:double.infinity,child:FilledButton(onPressed:()async{await end();if(mounted)Navigator.pop(context);},child:Text(widget.host?'End live':'Leave live')))]))]))]));}
}
class _WorldStudio extends StatefulWidget {
 const _WorldStudio();
 @override State<_WorldStudio> createState()=>_WorldStudioState();
}
class _WorldStudioState extends State<_WorldStudio>{
 final title=TextEditingController(); bool video=true; lk.CameraPosition position=lk.CameraPosition.front;
 Future<void> flipPreview() async {final t=preview;if(t==null||loading)return;setState(()=>loading=true);try{final next=position==lk.CameraPosition.front?lk.CameraPosition.back:lk.CameraPosition.front;await t.setCameraPosition(next);if(mounted)setState(()=>position=next);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text("Camera switch failed: $e")));}finally{if(mounted)setState(()=>loading=false);}}
 lk.LocalVideoTrack? preview; bool loading=false; String? cameraError;
 @override void initState(){super.initState(); startPreview();}
 Future<void> startPreview() async {
  if(loading)return;
  setState((){loading=true;cameraError=null;});
  try{
   if(!await Permission.camera.request().isGranted)throw Exception('Camera permission required');
   final t=await lk.LocalVideoTrack.createCameraTrack(lk.CameraCaptureOptions(cameraPosition:position));
   if(!mounted||!video){await t.stop();await t.dispose();return;}
   setState(()=>preview=t);
  }catch(e){if(mounted)setState(()=>cameraError='$e');}
  finally{if(mounted)setState(()=>loading=false);}
 }
 Future<void> stopPreview() async {final t=preview;preview=null;if(t!=null){await t.stop();await t.dispose();}}
 @override void dispose(){title.dispose();unawaited(stopPreview());super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.black,body:Stack(fit:StackFit.expand,children:[
 if(video&&preview!=null)lk.VideoTrackRenderer(preview!) else Container(decoration:const BoxDecoration(gradient:RadialGradient(colors:[Color(0xff124d36),Colors.black])),child:Center(child:loading?const CircularProgressIndicator(color:_mint):Column(mainAxisSize:MainAxisSize.min,children:[Icon(video?Icons.videocam_outlined:Icons.graphic_eq,size:84,color:_mint),if(cameraError!=null&&video)TextButton(onPressed:startPreview,child:const Text('Retry camera'))]))),
 const IgnorePointer(child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.black87,Colors.transparent,Colors.transparent,Colors.black87],stops:[0,.25,.55,1])))),
 SafeArea(child:Column(children:[Row(children:[IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close,color:Colors.white)),const Expanded(child:_WorldBrand()),const Padding(padding:EdgeInsets.all(16),child:Text('PREVIEW',style:TextStyle(color:_mint,fontWeight:FontWeight.bold)))]),if(video&&preview!=null)Align(alignment:Alignment.centerRight,child:Padding(padding:const EdgeInsets.all(16),child:IconButton.filled(tooltip:'Switch front / back camera',onPressed:loading?null:flipPreview,icon:const Icon(Icons.cameraswitch)))),const Spacer(),Padding(padding:const EdgeInsets.all(20),child:Column(children:[TextField(controller:title,maxLength:80,onChanged:(_)=>setState((){}),textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.bold),decoration:const InputDecoration(hintText:'Name your adventure',hintStyle:TextStyle(color:Colors.white70),border:InputBorder.none,counterStyle:TextStyle(color:Colors.white54))),Row(mainAxisAlignment:MainAxisAlignment.center,children:[ChoiceChip(label:const Text('Video'),avatar:const Icon(Icons.videocam),selected:video,onSelected:loading?null:(_)async{if(video)return;setState(()=>video=true);await startPreview();}),const SizedBox(width:12),ChoiceChip(label:const Text('Audio'),avatar:const Icon(Icons.mic),selected:!video,onSelected:loading?null:(_)async{setState(()=>video=false);await stopPreview();if(mounted)setState((){});})]),const SizedBox(height:20),SizedBox(width:double.infinity,height:58,child:FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:_mint,foregroundColor:Colors.black),onPressed:loading||title.text.trim().isEmpty||(video&&preview==null)?null:()async{final name=title.text.trim();setState(()=>loading=true);await stopPreview();if(mounted)Navigator.pop(context,{'title':name,'video':video,'position':position});},icon:const Icon(Icons.sensors),label:const Text('GO LIVE',style:TextStyle(fontWeight:FontWeight.w900,letterSpacing:2)))),const SizedBox(height:12),const Text('Respect privacy. Broadcast only with consent.',style:TextStyle(color:Colors.white70,fontSize:12))]))]))]));
}

class _WorldBrand extends StatelessWidget {
 const _WorldBrand();
 @override Widget build(BuildContext context)=>Row(children:[ClipRRect(borderRadius:BorderRadius.circular(9),child:Image.asset('assets/icon/logo.png',width:34,height:34,fit:BoxFit.cover,errorBuilder:(c,e,s)=>const Icon(Icons.public,color:_mint))),const SizedBox(width:8),const Flexible(child:FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:Text.rich(TextSpan(style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,fontFamily:'Roboto'),children:[TextSpan(text:'Maya',style:TextStyle(color:Colors.white)),TextSpan(text:'Jaal',style:TextStyle(color:_mint)),TextSpan(text:' WORLD',style:TextStyle(color:Colors.white,fontSize:15,letterSpacing:1.5))]))))]);
}
