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

  @override Widget build(BuildContext context)=>ColoredBox(color:Colors.black,child:SafeArea(child:RefreshIndicator(onRefresh:refresh,child:ListView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.all(18),children:[
    Row(children:[const Expanded(child:_WorldBrand()),IconButton(tooltip:'Refresh live rooms',onPressed:refresh,icon:const Icon(Icons.refresh,color:_mint))]),
    const SizedBox(height:24),Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xff123d2c),Color(0xff101715)]),borderRadius:BorderRadius.circular(24),border:Border.all(color:const Color(0xff28533e))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.public,color:_mint,size:42),const SizedBox(height:18),const Text('The world is live.',style:TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.w900)),const SizedBox(height:8),const Text('Explore real places. Meet people. Share your own adventure.',style:TextStyle(color:Colors.white70,fontSize:15)),const SizedBox(height:22),SizedBox(width:double.infinity,height:52,child:FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:_mint,foregroundColor:Colors.black),onPressed:busy?null:create,icon:const Icon(Icons.sensors),label:const Text('Open Creator Studio',style:TextStyle(fontWeight:FontWeight.bold))))])),
    const SizedBox(height:28),Row(children:[const Expanded(child:Text('Explore live',style:TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w800))),Text('${rooms.length} broadcasts',style:const TextStyle(color:_mint))]),const SizedBox(height:12),
    if(error!=null)Text(error!,style:const TextStyle(color:Colors.white70)),if(error==null&&rooms.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:32),child:Column(children:[Icon(Icons.travel_explore,color:Colors.white38,size:48),SizedBox(height:12),Text('No live broadcasts right now',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),SizedBox(height:6),Text('Start your own or pull down to refresh.',style:TextStyle(color:Colors.white54))])),
    for(final r in rooms)Card(color:const Color(0xff141b18),margin:const EdgeInsets.only(bottom:12),child:ListTile(contentPadding:const EdgeInsets.all(14),leading:CircleAvatar(backgroundColor:const Color(0xff204333),child:Icon(r['video']==true?Icons.videocam:Icons.mic,color:_mint)),title:Text('${r['title']}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),subtitle:Text('${r['hostName']} • LIVE',style:const TextStyle(color:Colors.white70)),trailing:const Icon(Icons.arrow_forward,color:_mint),onTap:busy?null:()=>enter(id:r['id'] as String)))
  ]))));
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
SafeArea(child:Column(children:[Container(padding:const EdgeInsets.all(16),color:Colors.transparent,child:Row(children:[IconButton(onPressed:()async{await end();if(mounted)Navigator.pop(context);},icon:const Icon(Icons.arrow_back,color:Colors.white)),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${widget.data['title']}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:18)),Text(ready?'${started.elapsed.inMinutes.toString().padLeft(2,'0')}:${(started.elapsed.inSeconds%60).toString().padLeft(2,'0')} • ${widget.host?room.remoteParticipants.length:(room.remoteParticipants.length-1).clamp(0, 999999)} viewers':'Connecting',style:const TextStyle(color:Colors.white70))])),if(ready)const Chip(label:Text('LIVE',style:TextStyle(color:Colors.white)),backgroundColor:Colors.red)])),const Spacer(),if(ready&&showChat) SizedBox(height:160,child:ListView(reverse:true,padding:const EdgeInsets.symmetric(horizontal:16),children:[for(final m in messages.reversed) Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Text('${m['name']}: ${m['text']}',style:const TextStyle(color:Colors.white,shadows:[Shadow(blurRadius:5,color:Colors.black)])))])),if(ready) Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:Row(children:[IconButton(onPressed:()=>setState(()=>showChat=!showChat),icon:const Icon(Icons.chat_bubble_outline,color:Colors.white)),Expanded(child:TextField(controller:chatInput,maxLength:300,style:const TextStyle(color:Colors.white),decoration:InputDecoration(counterText:'',hintText:'Say something…',filled:true,fillColor:Colors.black54,border:OutlineInputBorder(borderRadius:BorderRadius.circular(30))),onSubmitted:(_)=>sendChat())),IconButton(onPressed:sendChat,icon:const Icon(Icons.send,color:_mint))])),if(error!=null)Padding(padding:const EdgeInsets.all(12),child:Column(children:[Text(error!,style:const TextStyle(color:Colors.white)),if(!ready)OutlinedButton(onPressed:connecting?null:()async{await room.disconnect();await room.dispose();if(!mounted||closing)return;room=lk.Room();await connect();},child:const Text('Retry connection'))])),Container(color:Colors.transparent,padding:const EdgeInsets.all(16),child:Column(children:[if(widget.host&&ready)Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[IconButton(tooltip:'Microphone',onPressed:()async{try{await room.localParticipant!.setMicrophoneEnabled(muted);if(mounted)setState(()=>muted=!muted);}catch(e){if(mounted)setState(()=>error='$e');}},icon:Icon(muted?Icons.mic_off:Icons.mic,color:Colors.white)),if(widget.video&&camera)IconButton(tooltip:'Switch front / back camera',onPressed:flipCamera,icon:const Icon(Icons.cameraswitch,color:_mint)),if(widget.video)IconButton(tooltip:'Camera',onPressed:()async{try{await room.localParticipant!.setCameraEnabled(!camera,cameraCaptureOptions:lk.CameraCaptureOptions(cameraPosition:position));if(mounted)setState(()=>camera=!camera);}catch(e){if(mounted)setState(()=>error='$e');}},icon:Icon(camera?Icons.videocam:Icons.videocam_off,color:Colors.white))]),SizedBox(width:double.infinity,child:FilledButton(onPressed:()async{await end();if(mounted)Navigator.pop(context);},child:Text(widget.host?'End live':'Leave live')))]))]))]));}
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
 @override Widget build(BuildContext context)=>Row(children:[ClipRRect(borderRadius:BorderRadius.circular(9),child:Image.asset('assets/icon/logo.png',width:34,height:34,fit:BoxFit.cover,errorBuilder:(c,e,s)=>const Icon(Icons.public,color:_mint))),const SizedBox(width:8),const Flexible(child:FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:Text.rich(TextSpan(style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,fontFamily:'sans-serif'),children:[TextSpan(text:'Maya',style:TextStyle(color:Colors.white)),TextSpan(text:'Jaal',style:TextStyle(color:_mint)),TextSpan(text:' WORLD',style:TextStyle(color:Colors.white,fontSize:15,letterSpacing:1.5))]))))]);
}
