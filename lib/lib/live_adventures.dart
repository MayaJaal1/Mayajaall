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
  Future<void> refresh() async {try {final r=await _api('/rooms'); if(mounted)setState((){rooms=r['rooms'] as List;error=null;});}catch(e){if(mounted)setState(()=>error='Could not load live adventures. Pull to retry.');}}
  Future<void> enter({String? id,String? title,bool video=true}) async {
    if(busy)return; setState(()=>busy=true);
    try {
      if(id==null){if(!await Permission.microphone.request().isGranted)throw Exception('Microphone permission required');if(video && !await Permission.camera.request().isGranted)throw Exception('Camera permission required');}
      final r=await _api(id==null?'/host':'/join',body:id==null?{'title':title,'video':video}:{'id':id});
      if(!mounted)return;
      await Navigator.of(context).push(MaterialPageRoute(builder:(_)=>_AdventureRoom(data:r,host:id==null,video:video)));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}finally{if(mounted){setState(()=>busy=false);refresh();}}
  }
  Future<void> create() async {
    String title=''; bool video=true;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(title:const Text('Start an adventure'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(maxLength:80,onChanged:(v)=>title=v,decoration:const InputDecoration(labelText:'Adventure title')),SwitchListTile(title:const Text('Video (off = audio only)'),value:video,onChanged:(v)=>update(()=>video=v)),const Text('Broadcast only with consent. Do not film private locations or dangerous activities.')]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Continue'))])));
    if(ok==true && mounted && title.trim().isNotEmpty)await enter(title:title.trim(),video:video);
  }
  @override Widget build(BuildContext context)=>SafeArea(child:RefreshIndicator(onRefresh:refresh,child:ListView(padding:const EdgeInsets.all(18),children:[const Text('LIVE ADVENTURES',style:TextStyle(color:_mint,fontSize:25,fontWeight:FontWeight.w900)),const SizedBox(height:8),const Text('Explore the world together. Join a real-time broadcast.',style:TextStyle(color:Colors.white70)),const SizedBox(height:20),FilledButton.icon(onPressed:busy?null:create,icon:const Icon(Icons.sensors),label:const Text('Go live')),const SizedBox(height:24),const Text('On air',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),if(error!=null)Padding(padding:const EdgeInsets.all(12),child:Text(error!)),if(error==null && rooms.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('No active adventures right now.')),for(final r in rooms)Card(child:ListTile(leading:Icon(r['video']==true?Icons.videocam:Icons.mic,color:_mint),title:Text('${r['title']}'),subtitle:Text('${r['hostName']} • LIVE'),trailing:const Icon(Icons.arrow_forward),onTap:busy?null:()=>enter(id:r['id'] as String)))])));
}
class _AdventureRoom extends StatefulWidget {
  final Map<String,dynamic> data; final bool host,video;
  const _AdventureRoom({required this.data,required this.host,required this.video});
  @override State<_AdventureRoom> createState()=>_AdventureRoomState();
}
class _AdventureRoomState extends State<_AdventureRoom> {
  final room=lk.Room(); Timer? ticker; String? error; bool ready=false, muted=false, camera=true, closing=false;
  @override void initState(){super.initState();camera=widget.video;connect();ticker=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState((){});});}
  Future<void> connect() async {try{await room.connect(widget.data['url'] as String,widget.data['token'] as String);if(!mounted){await room.disconnect();return;}if(widget.host){await room.localParticipant!.setMicrophoneEnabled(true);if(widget.video)await room.localParticipant!.setCameraEnabled(true);}if(mounted)setState(()=>ready=true);}catch(e){if(mounted)setState(()=>error='Connection failed: $e');await end();}}
  Future<void> end() async {if(closing)return;closing=true;try{await room.disconnect();}catch(_){}if(widget.host){try{await _api('/end',body:{'id':widget.data['id']});}catch(_){}}}
  @override void dispose(){ticker?.cancel();unawaited(end().whenComplete(()=>room.dispose()));super.dispose();}
  @override Widget build(BuildContext context){lk.VideoTrack? track;final participants=widget.host?[if(room.localParticipant!=null)room.localParticipant!]:room.remoteParticipants.values.toList();for(final p in participants){for(final pub in p.videoTrackPublications){final t=pub.track;if(t is lk.VideoTrack){track=t;break;}}}return Scaffold(appBar:AppBar(title:Text('${widget.data['title']}')),body:Column(children:[Expanded(child:Center(child:error!=null?Text(error!):!ready?const CircularProgressIndicator():track!=null?lk.VideoTrackRenderer(track):const Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.graphic_eq,size:80,color:_mint),Text('Audio / waiting for video')]))),if(widget.host && ready)Wrap(children:[IconButton(tooltip:'Toggle microphone',onPressed:()async{try{await room.localParticipant!.setMicrophoneEnabled(muted);if(mounted)setState(()=>muted=!muted);}catch(e){if(mounted)setState(()=>error='$e');}},icon:Icon(muted?Icons.mic_off:Icons.mic)),if(widget.video)IconButton(tooltip:'Toggle camera',onPressed:()async{try{await room.localParticipant!.setCameraEnabled(!camera);if(mounted)setState(()=>camera=!camera);}catch(e){if(mounted)setState(()=>error='$e');}},icon:Icon(camera?Icons.videocam:Icons.videocam_off))]),SafeArea(child:FilledButton(onPressed:()async{await end();if(mounted)Navigator.pop(context);},child:Text(widget.host?'End broadcast':'Leave adventure')))]));}
}
