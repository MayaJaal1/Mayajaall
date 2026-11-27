import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'live_adventures.dart';
import 'maya_ai.dart';
const _green=Color(0xff00e69a);
class LiveAdventuresScreen extends StatefulWidget {
 const LiveAdventuresScreen({super.key});
 @override State<LiveAdventuresScreen> createState()=>_EarthState();
}
class _EarthState extends State<LiveAdventuresScreen>{
 final map=MapController(); LatLng? area; bool available=false,adult=false,loading=false; String? error; String mode='online'; List<dynamic> people=[],requests=[]; Timer? timer; int ticks=0; int page=0; bool working=false; bool guideIntent=false;
 Future<Map<String,dynamic>> api(String path,[Map<String,dynamic>? body]) async {final token=await FirebaseAuth.instance.currentUser?.getIdToken();if(token==null)throw Exception('Sign in required');final uri=Uri.parse('https://www.mayajaal.online/world-api/$path');final h={'Authorization':'Bearer $token','Content-Type':'application/json'};final r=await (body==null?http.get(uri,headers:h):http.post(uri,headers:h,body:jsonEncode(body))).timeout(const Duration(seconds:12));final d=jsonDecode(r.body) as Map<String,dynamic>;if(r.statusCode!=200)throw Exception(d['error']??'Service unavailable');return d;}
 @override void initState(){super.initState();refresh();timer=Timer.periodic(const Duration(seconds:5),(_)=>refresh());}
 @override void dispose(){timer?.cancel();super.dispose();}
 Future<void> refresh() async {if(loading)return;loading=true;try{if(available&&++ticks%6==0)await presence(true);final d=await api('state');if(mounted)setState((){people=d['people'] as List;requests=d['requests'] as List;error=null;});}catch(e){if(mounted)setState(()=>error='$e');}finally{loading=false;}}
 Future<void> presence(bool on) async {await api('presence',on?{'enabled':true,'adult':adult,'lat':area!.latitude,'lng':area!.longitude,'modes':[mode]}:{'enabled':false});}
 Future<void> run(Future<void> Function() f) async {
 if(working||!mounted)return; setState(()=>working=true);
 try{await f();await refresh();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
 finally{if(mounted)setState(()=>working=false);}
 }
 static const _bg=Color(0xff070c0b);
 static const _panel=Color(0xff101b18);
 static const _muted=Color(0xffa3b7af);
 void openPage(int value){setState(()=>page=value);}
 void live()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const WorldLiveScreen()));
 String modeName(String value)=>switch(value){'online'=>'Online help','guide'=>'Local guide','meet'=>'Public meeting',_=>value};
 Future<void> prompt(String title,Future<void> Function(String) submit) async {
   final result=await Navigator.of(context).push<String>(MaterialPageRoute(builder:(_)=>_WorldComposer(title:title)));
   if(mounted&&result!=null&&result.isNotEmpty)await run(()=>submit(result));
 }
 void begin(String kind,{bool offer=false}) {
   if(available){openPage(1);return;}
   setState((){mode=kind;guideIntent=offer;area=null;page=1;});
 }
 Future<void> request() async {
   if(area==null){openPage(1);return;}
   if(!adult){openPage(3);return;}
   final selected=area!; final kind=mode;
   await prompt(kind=='online'?'What should someone show you?':'What do you need at this place?',(s)async{
     await api('request',{'lat':selected.latitude,'lng':selected.longitude,'adult':true,'mode':kind,'text':s});
     if(mounted)openPage(2);
   });
 }
 Future<void> togglePresence() async {
   if(!available&&(area==null||!adult)){openPage(area==null?1:3);return;}
   await run(()async{final next=!available;await presence(next);if(mounted)setState((){available=next;if(next)page=0;});});
 }
 Future<void> advance() async {
   if(area==null||working)return;
   if(!adult){openPage(3);return;}
   if(guideIntent){await togglePresence();}else{await request();}
 }
 Widget panel(Widget child,{Color color=_panel})=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(22),border:Border.all(color:Colors.white.withOpacity(.08))),child:child);
 Widget tag(String text,{Color color=_green})=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:color.withOpacity(.14),borderRadius:BorderRadius.circular(20)),child:Text(text,style:TextStyle(color:color,fontSize:11,fontWeight:FontWeight.w800,letterSpacing:.4)));
 Widget section(String title,String subtitle)=>Padding(padding:const EdgeInsets.only(top:22,bottom:12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(subtitle,style:const TextStyle(color:_muted,fontSize:13))]));
 Widget tile(IconData icon,String title,String subtitle,VoidCallback tap,{Color accent=_green})=>Material(color:_panel,borderRadius:BorderRadius.circular(20),child:InkWell(borderRadius:BorderRadius.circular(20),onTap:tap,child:Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),border:Border.all(color:Colors.white.withOpacity(.08))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:42,height:42,decoration:BoxDecoration(color:accent.withOpacity(.13),borderRadius:BorderRadius.circular(14)),child:Icon(icon,color:accent)),const Spacer(),Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800)),const SizedBox(height:5),Text(subtitle,style:const TextStyle(fontSize:12,color:_muted,height:1.3)),const SizedBox(height:7),Icon(Icons.arrow_forward_rounded,color:accent,size:18)]))));
 Widget hero()=>Container(clipBehavior:Clip.antiAlias,decoration:BoxDecoration(borderRadius:BorderRadius.circular(26),gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xff174737),Color(0xff0c2422),Color(0xff101619)]),border:Border.all(color:_green.withOpacity(.2))),child:Stack(children:[Positioned(right:-32,top:0,child:Icon(Icons.public_rounded,size:210,color:_green.withOpacity(.09))),Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[tag('LIVE ADVENTURES'),const SizedBox(height:19),const Text('Go beyond\nyour world.',style:TextStyle(fontSize:32,height:1.08,fontWeight:FontWeight.w900,letterSpacing:-1)),const SizedBox(height:10),const Text('Watch real places live or show your own adventure to the world.',style:TextStyle(color:_muted,fontSize:14,height:1.45)),const SizedBox(height:22),SizedBox(width:double.infinity,child:FilledButton.icon(style:FilledButton.styleFrom(minimumSize:const Size(0,52),backgroundColor:_green,foregroundColor:Colors.black),onPressed:live,icon:const Icon(Icons.sensors_rounded),label:const Text('Explore & go live',style:TextStyle(fontWeight:FontWeight.w800))))]))]));
 Widget action(IconData icon,String title,String description,VoidCallback tap,{Color accent=_green})=>Padding(padding:const EdgeInsets.only(bottom:10),child:Material(color:_panel,borderRadius:BorderRadius.circular(19),child:InkWell(borderRadius:BorderRadius.circular(19),onTap:tap,child:Padding(padding:const EdgeInsets.all(15),child:Row(children:[Container(width:48,height:48,decoration:BoxDecoration(color:accent.withOpacity(.13),borderRadius:BorderRadius.circular(15)),child:Icon(icon,color:accent,size:25)),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(description,style:const TextStyle(color:_muted,fontSize:12,height:1.4))])),const Icon(Icons.chevron_right_rounded,color:_muted)])))));
 List<Widget> home()=>[
   const Text('YOUR WORLD, WITHOUT BORDERS',style:TextStyle(color:_green,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.7)),const SizedBox(height:12),hero(),
   if(error!=null)Padding(padding:const EdgeInsets.only(top:12),child:panel(Row(children:[const Icon(Icons.cloud_off,color:Colors.orangeAccent),const SizedBox(width:10),const Expanded(child:Text('Connections service is offline. Retry to load requests.')),IconButton(onPressed:refresh,icon:const Icon(Icons.refresh))]))),
   section('Go somewhere without travelling','Ask a local person to help you explore a real place.'),
   action(Icons.travel_explore_rounded,'Request a place','Example: Show me Bhopal Boat Club live.',()=>begin('online')),
   action(Icons.explore_rounded,'Find a local guide','Get advice about a public destination.',()=>begin('guide'),accent:const Color(0xff6bc9ff)),
   action(Icons.groups_outlined,'Meet in a public place','Connect with a consenting adult nearby.',()=>begin('meet'),accent:const Color(0xffb9a3ff)),
   section('Your space','Manage your activity and languages.'),
   action(Icons.forum_rounded,'My connections','${requests.length} requests · Open messages',()=>openPage(2)),
   action(Icons.translate_rounded,'Translate a clip','Hindi / English · text and short audio trial',()=>MayaAI.open(context),accent:const Color(0xffffbd78)),
   action(available?Icons.visibility_off:Icons.wifi_tethering,available?'Stop sharing availability':'Become a local guide',available?'Go offline whenever you want.':'Choose a public area and opt in.',available?()=>togglePresence():()=>begin('guide',offer:true)),
   const Text('Requests are not guaranteed. No private address is required.',style:TextStyle(color:_muted,fontSize:12))];
 Widget mapView()=>ClipRRect(borderRadius:BorderRadius.circular(24),child:SizedBox(height:285,child:Stack(children:[FlutterMap(mapController:map,options:MapOptions(initialCenter:area??const LatLng(22,78),initialZoom:area==null?3:10,onTap:(_,p){if(!available)setState(()=>area=LatLng((p.latitude*100).round()/100,(p.longitude*100).round()/100));}),children:[TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'online.mayajaal.world'),MarkerLayer(markers:[if(area!=null)Marker(point:area!,child:const Icon(Icons.place,color:Colors.orange,size:36)),for(final p in people)if(p['lat'] is num&&p['lng'] is num)Marker(point:LatLng((p['lat'] as num).toDouble(),(p['lng'] as num).toDouble()),child:IconButton(icon:const Icon(Icons.person_pin_circle,color:Colors.green,size:32),onPressed:()=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${p['name']} is available in this approximate area. Select a public area to request help.')))))])]),Positioned(top:12,left:12,child:Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:_bg,borderRadius:BorderRadius.circular(12)),child:Text('${people.length} available members',style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold)))),const Positioned(bottom:4,right:4,child:ColoredBox(color:Colors.black87,child:Text('© OpenStreetMap contributors',style:TextStyle(fontSize:10,color:Colors.white))))])));
 List<Widget> explore()=>[
   tag('STEP 1 / 3  ·  PLACE'),const SizedBox(height:15),Text(available?'Your active area':guideIntent?'Where can you help?':'Where do you want to explore?',style:const TextStyle(fontSize:29,fontWeight:FontWeight.w900,letterSpacing:-.8)),const SizedBox(height:8),Text(available?'Stop availability before changing your area.':'Zoom in and tap the public area on the map. Your current location is not required.',style:const TextStyle(color:_muted,height:1.45)),const SizedBox(height:18),mapView(),const SizedBox(height:14),
   panel(Row(children:[Icon(area==null?Icons.touch_app_outlined:Icons.check_circle_outline,color:_green),const SizedBox(width:12),Expanded(child:Text(area==null?'No place selected. Tap the map first.':'Selected area · ${area!.latitude.toStringAsFixed(2)}, ${area!.longitude.toStringAsFixed(2)}',style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600)))])),
   const SizedBox(height:14),if(error!=null)Text('Service error: $error',style:const TextStyle(color:Colors.orangeAccent)),
   if(available)SizedBox(height:54,child:FilledButton(onPressed:working?null:togglePresence,child:const Text('Stop sharing availability')))else ...[
   SizedBox(height:54,child:FilledButton.icon(onPressed:area==null||working?null:advance,icon:const Icon(Icons.arrow_forward_rounded),label:Text(guideIntent?'Continue to availability':'Continue with ${modeName(mode)}'))),
   const SizedBox(height:10),TextButton(onPressed:()=>openPage(0),child:const Text('Choose a different activity'))]];
 List<Widget> safety()=>[
   tag('STEP 2 / 3  ·  SAFETY'),const SizedBox(height:25),const Icon(Icons.shield_outlined,size:70,color:_green),const SizedBox(height:16),const Text('Explore safely.',style:TextStyle(fontSize:32,fontWeight:FontWeight.w900)),const SizedBox(height:10),const Text('Only share public areas. Never share private addresses or payment credentials. Meet only in safe public places.',style:TextStyle(color:_muted,fontSize:15,height:1.5)),const SizedBox(height:24),
   SizedBox(height:56,child:FilledButton(onPressed:working?null:()async{setState(()=>adult=true);await advance();},child:Text(guideIntent?'I am 18+ · Go available':'I am 18+ · Agree & continue'))),const SizedBox(height:10),OutlinedButton(onPressed:()=>openPage(1),child:const Text('Back to map')),const SizedBox(height:12),const Text('Continue only if you are 18 or older and agree to these rules.',style:TextStyle(color:_muted,fontSize:12))];
 List<Widget> connections()=>[const Text('My connections',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900)),const SizedBox(height:6),const Text('Manage requests and conversations.',style:TextStyle(color:_muted)),const SizedBox(height:20),if(error!=null)Text(error!,style:const TextStyle(color:Colors.orangeAccent)),if(requests.isEmpty)panel(Column(children:[const Icon(Icons.forum_outlined,color:_green,size:45),const SizedBox(height:14),const Text('No active requests',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:7),const Text('Explore Earth to make your first connection.',textAlign:TextAlign.center,style:TextStyle(color:_muted)),const SizedBox(height:15),FilledButton(onPressed:()=>openPage(1),child:const Text('Explore Earth'))])),for(final q in requests)Padding(padding:const EdgeInsets.only(bottom:12),child:panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(modeName('${q['mode']}'),style:const TextStyle(fontWeight:FontWeight.w800,fontSize:16))),tag('${q['status']}')]),const SizedBox(height:10),Text('${q['text']}'),if(q['incoming']==true)Wrap(spacing:8,children:[FilledButton(onPressed:working?null:()=>run(()async{await api('action',{'id':q['id'],'action':'accept'});}),child:const Text('Accept')),OutlinedButton(onPressed:working?null:()=>run(()async{await api('action',{'id':q['id'],'action':'decline'});}),child:const Text('Decline'))]),if(q['status']=='accepted')...[const Divider(),for(final m in (q['messages'] as List? ?? []))Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Text('${m['mineUid']==FirebaseAuth.instance.currentUser?.uid?'You':'Partner'}: ${m['text']}')),Wrap(spacing:8,children:[TextButton.icon(onPressed:working?null:()=>prompt('Send a message',(s)async{await api('message',{'id':q['id'],'text':s});}),icon:const Icon(Icons.chat_bubble_outline),label:const Text('Chat')),TextButton(onPressed:working?null:()=>prompt('Report reason',(s)async{await api('report',{'uid':q['peer'],'reason':s});}),child:const Text('Report')),TextButton(onPressed:working?null:()=>run(()async{await api('block',{'uid':q['peer']});}),child:const Text('Block'))])],if(q['status']=='accepted'||q['mine']==true&&q['status']=='searching')TextButton(onPressed:working?null:()=>run(()async{await api('action',{'id':q['id'],'action':'close'});}),child:const Text('Close request'))])))];
 @override Widget build(BuildContext context)=>Theme(data:ThemeData.dark().copyWith(scaffoldBackgroundColor:_bg,colorScheme:const ColorScheme.dark(primary:_green,surface:_panel,onPrimary:Colors.black)),child:Scaffold(body:SafeArea(child:Column(children:[Padding(padding:const EdgeInsets.fromLTRB(16,8,12,10),child:Row(children:[if(page!=0)IconButton(onPressed:()=>openPage(page==3?1:0),icon:const Icon(Icons.arrow_back_rounded))else Image.asset('assets/icon/logo.png',width:36,height:36),const SizedBox(width:8),const Expanded(child:Text.rich(TextSpan(style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,letterSpacing:-.5),children:[TextSpan(text:'MayaJaal '),TextSpan(text:'WORLD',style:TextStyle(color:_green,fontSize:15,letterSpacing:1))]))),if(working)const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)),IconButton(tooltip:'Refresh',onPressed:refresh,icon:const Icon(Icons.refresh_rounded))])),Expanded(child:RefreshIndicator(onRefresh:refresh,child:ListView(key:ValueKey(page),physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.fromLTRB(16,8,16,22),children:page==0?home():page==1?explore():page==3?safety():connections())))]))));
}
class _WorldComposer extends StatefulWidget {
 final String title;
 const _WorldComposer({required this.title});
 @override State<_WorldComposer> createState()=>_WorldComposerState();
}
class _WorldComposerState extends State<_WorldComposer>{
 final controller=TextEditingController();
 @override void dispose(){controller.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xff070c0b),appBar:AppBar(backgroundColor:Colors.transparent,foregroundColor:Colors.white,title:Text(widget.title)),body:SafeArea(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(widget.title,style:TextStyle(color:Colors.white,fontSize:26,fontWeight:FontWeight.bold)),const SizedBox(height:10),const Text('Do not include private addresses or sensitive information.',style:TextStyle(color:Colors.white60)),const SizedBox(height:20),Expanded(child:TextField(controller:controller,autofocus:true,maxLength:300,maxLines:null,expands:true,onChanged:(_)=>setState((){}),style:const TextStyle(color:Colors.white,fontSize:18),decoration:const InputDecoration(hintText:'Write here…',hintStyle:TextStyle(color:Colors.white54),border:InputBorder.none))),FilledButton(style:FilledButton.styleFrom(backgroundColor:_green,foregroundColor:Colors.black,minimumSize:const Size(0,52)),onPressed:controller.text.trim().isEmpty?null:()=>Navigator.pop(context,controller.text.trim()),child:const Text('Send'))]))));
}
