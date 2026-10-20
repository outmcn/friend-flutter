part of 'main.dart';

class ReportPostPage extends StatefulWidget {
  const ReportPostPage({
    super.key,
    required this.postId,
    required this.service,
    required this.token,
  });
  final int postId;
  final DDPostService service;
  final Future<String> Function() token;

  @override
  State<ReportPostPage> createState() => _ReportPostPageState();
}

class _ReportPostPageState extends State<ReportPostPage> {
  static const reportReasons = [
    '低俗色情',
    '攻击辱骂',
    '涉嫌诈骗',
    '未成年人',
    '政治敏感',
    '网络谣言',
    '违法信息',
    '血腥暴力',
    '广告引流',
    '网乞相关',
    '恶意诱导到其他平台',
    '其他',
  ];

  String? reason;
  bool submitting = false;
  String? error;

  Future<void> submit() async {
    if (reason == null || submitting) return;
    try {
      setState(() {
        submitting = true;
        error = null;
      });
      await widget.service.reportPost(
        token: await widget.token(),
        postId: widget.postId,
        reason: reason!,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          submitting = false;
          error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('举报动态')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              '请选择举报原因',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: reason,
              onChanged: (value) {
                if (!submitting) setState(() => reason = value);
              },
              child: Column(
                children: reportReasons
                    .map(
                      (item) => RadioListTile<String>(
                        value: item,
                        title: Text(item),
                        secondary: const Icon(Icons.chevron_right),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.orange)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: reason == null || submitting ? null : submit,
              child: Text(submitting ? '提交中…' : '提交举报'),
            ),
          ],
        ),
      );
}


class PostAppealPage extends StatefulWidget {
  const PostAppealPage({super.key, required this.postId, required this.service, required this.token});
  final int postId; final DDPostService service; final Future<String> Function() token;
  @override State<PostAppealPage> createState() => _PostAppealPageState();
}
class _PostAppealPageState extends State<PostAppealPage> {
  final controller = TextEditingController(); bool submitting=false; String? error;
  @override void dispose(){controller.dispose();super.dispose();}
  Future<void> submit() async { final text=controller.text.trim(); if(text.isEmpty||submitting)return; setState(()=>submitting=true); try { await widget.service.appealPost(token:await widget.token(),postId:widget.postId,content:text); if(mounted)Navigator.pop(context,true); } catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));} finally{if(mounted)setState(()=>submitting=false);} }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('申诉')),body:ListView(padding:const EdgeInsets.all(16),children:[const Text('请填写申诉内容',style:TextStyle(fontSize:20,fontWeight:FontWeight.w700)),const SizedBox(height:12),TextField(controller:controller,maxLength:1000,minLines:5,maxLines:10,decoration:const InputDecoration(border:OutlineInputBorder(),hintText:'请说明申诉理由')),if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),const SizedBox(height:16),FilledButton(onPressed:submitting?null:submit,child:Text(submitting?'提交中…':'提交申诉'))]));
}
