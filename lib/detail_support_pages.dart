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
