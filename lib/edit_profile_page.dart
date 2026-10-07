part of 'main.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final service = DDPostService();
  final nickname = TextEditingController();
  XFile? image;
  List<int>? croppedAvatar;
  bool loading = true;
  bool saving = false;
  String? _avatarPreviewUrl;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    service.dispose();
    nickname.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final token = p.getString('friend.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      final data = await service.fetchMe(token);
      final profile = data['user'] is Map<String, dynamic>
          ? data['user'] as Map<String, dynamic>
          : data;
      nickname.text = '${profile['nickname'] ?? ''}';
      if (profile['avatarKey'] is String &&
          (profile['avatarKey'] as String).trim().isNotEmpty) {
        final signed = await service.resolveAvatarUrl(
          token,
          profile['avatarKey'],
        );
        if (mounted) {
          setState(() => _avatarPreviewUrl = signed);
        }
      }
    } catch (e) {
      if (mounted) error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pickAvatar() async {
    try {
      final value = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (value == null || !mounted) return;
      final cropped = await Navigator.push<List<int>>(
        context,
        MaterialPageRoute(builder: (_) => AvatarCropPage(file: value)),
      );
      if (cropped != null && mounted) {
        setState(() {
          croppedAvatar = cropped;
          image = null;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '头像选择失败：$e');
    }
  }

  Future<String?> _avatarObjectKey(String token) async {
    if (croppedAvatar == null) return null;
    final response = await service.avatarUploadUrl(
      token: token,
      fileName: 'avatar.jpg',
      contentType: 'image/jpeg',
    );
    final url = response['url'];
    final objectKey = response['objectKey'];
    if (url is! String || objectKey is! String) throw Exception('头像上传地址格式错误');
    final upload = await service.uploadAvatar(
      url: url,
      bytes: croppedAvatar!,
      contentType: 'image/jpeg',
    );
    if (!upload) throw Exception('头像上传失败');
    return objectKey;
  }

  Future<void> save() async {
    try {
      setState(() => saving = true);
      final p = await SharedPreferences.getInstance();
      final token = p.getString('friend.auth.token') ?? '';
      if (token.isEmpty) throw Exception('请先登录');
      final avatarKey = await _avatarObjectKey(token);
      await service.updateMe(
        token: token,
        nickname: nickname.text.trim(),
        avatarKey: avatarKey,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('编辑资料'), actions: [
          TextButton(
              onPressed: loading || saving ? null : save,
              child: Text(saving ? '保存中…' : '保存'))
        ]),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(18), children: [
                GestureDetector(
                  onTap: pickAvatar,
                  child: Center(
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: ClipPath(
                        clipper: _FixedCircleClipper(),
                        child: ColoredBox(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: croppedAvatar != null
                              ? Image.memory(
                                  Uint8List.fromList(croppedAvatar!),
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.contain,
                                )
                              : (_avatarPreviewUrl == null
                                  ? const Icon(Icons.add_a_photo_outlined,
                                      size: 30)
                                  : Image.network(
                                      _avatarPreviewUrl!,
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.broken_image_outlined),
                                    )),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.orange)),
                TextField(
                    controller: nickname,
                    maxLength: 5,
                    decoration: const InputDecoration(labelText: '昵称')),
              ]),
      );
}
