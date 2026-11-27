import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MayaAI {
  static const base = 'https://www.mayajaal.online/ai-api';
  static Future<String> token() async {
    final value = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (value == null) throw Exception('Sign in required');
    return value;
  }
  static Map<String,dynamic> decode(http.Response r) {
    final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String,dynamic>;
    if (r.statusCode != 200) throw Exception(data['error'] ?? data['detail'] ?? 'HTTP ${r.statusCode}');
    return data;
  }
  static Future<Map<String,dynamic>> text(String text,String source,String target) async => decode(await http.post(Uri.parse('$base/translate/text'),headers:{'Authorization':'Bearer ${await token()}','Content-Type':'application/json'},body:jsonEncode({'text':text,'source':source,'target':target})).timeout(const Duration(seconds:190)));
  static Future<Map<String,dynamic>> audio(File file,String target) async {
    if(await file.length()>10*1024*1024) throw Exception('Maximum file size is 10 MB');
    final client=http.Client();
    try {
      final req=http.MultipartRequest('POST',Uri.parse('$base/translate/audio'));
      req.headers['Authorization']='Bearer ${await token()}';
      req.fields['target']=target;
      req.files.add(await http.MultipartFile.fromPath('audio',file.path));
      return decode(await client.send(req).then(http.Response.fromStream).timeout(const Duration(seconds:190)));
    } finally {client.close();}
  }
  static Future<void> open(BuildContext context) => Navigator.of(context).push<void>(MaterialPageRoute(builder:(_)=>const MayaAIStudio()));
}
class MayaAIStudio extends StatefulWidget {
  const MayaAIStudio({super.key});
  @override State<MayaAIStudio> createState()=>_MayaAIStudioState();
}
class _MayaAIStudioState extends State<MayaAIStudio> {
  final input=TextEditingController();
  String target='hi', result='', original='', error='';
  bool busy=false;
  VideoPlayerController? player;
  File? output;
  @override void initState(){super.initState();load();}
  Future<void> load() async {final p=await SharedPreferences.getInstance();if(mounted&&!busy)setState(()=>target=p.getString('maya_ai_target')=='en'?'en':'hi');}
  @override void dispose(){input.dispose();player?.dispose();final f=output;if(f!=null)f.delete().catchError((Object e)=>f);super.dispose();}
  Future<void> run(bool audio) async {
    if(busy)return;
    setState((){busy=true;error='';result='';original='';});
    try {
      await player?.dispose();player=null;
      if(output!=null){await output!.delete();output=null;}
      Map<String,dynamic> data;
      if(audio){final picked=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['wav','mp3','m4a','aac','ogg','mp4']);final path=picked?.files.single.path;if(path==null)return;data=await MayaAI.audio(File(path),target);}
      else {if(input.text.trim().isEmpty)throw Exception('Enter text first');data=await MayaAI.text(input.text.trim(),target=='hi'?'en':'hi',target);}
      if(!mounted)return;
      final encoded=data['audio_base64'];
      if(encoded is String && encoded.isNotEmpty){final dir=await getTemporaryDirectory();if(!mounted)return;final f=File('${dir.path}/maya_ai_${DateTime.now().microsecondsSinceEpoch}.wav');await f.writeAsBytes(base64Decode(encoded));if(!mounted){await f.delete();return;}output=f;final p=VideoPlayerController.file(f);player=p;await p.initialize();}
      if(mounted)setState((){result='${data['translated'] ?? data['translation'] ?? ''}';original='${data['original'] ?? ''}';});
    }catch(e){if(mounted)setState(()=>error='$e');}finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xff080e0b),appBar:AppBar(title:const Text('MayaJaal AI • Trial')),body:ListView(padding:const EdgeInsets.all(20),children:[
    const Text('Translate without borders',style:TextStyle(fontSize:28,fontWeight:FontWeight.bold,color:Colors.white)),const SizedBox(height:8),const Text('Hindi ↔ English • Text and short local audio clips. Not live dubbing.',style:TextStyle(color:Colors.white70)),const SizedBox(height:20),
    DropdownButton<String>(value:target,items:const [DropdownMenuItem(value:'hi',child:Text('Hindi / हिंदी')),DropdownMenuItem(value:'en',child:Text('English'))],onChanged:busy?null:(v)async{if(v==null)return;setState(()=>target=v);final p=await SharedPreferences.getInstance();await p.setString('maya_ai_target',v);}),
    TextField(controller:input,maxLength:1000,enabled:!busy,maxLines:4,decoration:const InputDecoration(labelText:'Text in the other language',border:OutlineInputBorder())),
    FilledButton.icon(onPressed:busy?null:()=>run(false),icon:const Icon(Icons.translate),label:const Text('Translate text')),
    OutlinedButton.icon(onPressed:busy?null:()=>run(true),icon:const Icon(Icons.audio_file),label:const Text('Translate local audio / video clip')),
    const Text('Selected media is sent to the MayaJaal server for processing. Only select media you have permission to translate.',style:TextStyle(color:Colors.white70)),
    if(busy)const LinearProgressIndicator(),if(error.isNotEmpty)Text(error,style:const TextStyle(color:Colors.orangeAccent)),if(original.isNotEmpty)Text(original),if(result.isNotEmpty)SelectableText(result,style:const TextStyle(fontSize:20,color:Color(0xff00e676))),
    if(player?.value.isInitialized==true)FilledButton.icon(onPressed:busy?null:()async{final p=player;if(p==null)return;await p.seekTo(Duration.zero);await p.play();},icon:const Icon(Icons.play_arrow),label:const Text('Play translated voice')),
  ]));
}
