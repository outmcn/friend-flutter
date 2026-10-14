part of 'main.dart';

class _VoiceRecordPage extends StatefulWidget {
  const _VoiceRecordPage({required this.currentUrl});
  final String? currentUrl;

  @override
  State<_VoiceRecordPage> createState() => _VoiceRecordPageState();
}

class _VoiceRecordPageState extends State<_VoiceRecordPage> {
  final AudioRecorder recorder = AudioRecorder();
  final AudioPlayer player = AudioPlayer();
  final DDPostService service = DDPostService();
  bool recording = false;
  bool saving = false;
  bool playing = false;
  Timer? _recordingTimer;
  int recordingSeconds = 0;
  String? recordingPath;
  String? error;

  @override
  void dispose() {
    _recordingTimer?.cancel();
    recorder.dispose();
    player.dispose();
    service.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    try {
      final active = await recorder.isRecording();
      if (active) {
        final path = await recorder.stop();
        if (path == null || path.isEmpty) throw Exception('停止录音失败，未生成音频文件');
        final file = File(path);
        if (!await file.exists() || await file.length() == 0) {
          throw Exception('录音文件为空');
        }
        if (mounted) {
          setState(() {
            recording = false;
            recordingPath = path;
            error = null;
          });
        }
        _recordingTimer?.cancel();
        return;
      }
      final permission = await recorder.hasPermission();
      if (!permission) throw Exception('没有麦克风权限，请在设置中允许 DD 使用麦克风');
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/friend_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          numChannels: 1,
          sampleRate: 44100,
          bitRate: 128000,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );
      if (!await recorder.isRecording()) throw Exception('录音启动失败');
      recordingSeconds = 0;
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        if (!mounted) return;
        recordingSeconds++;
        if (recordingSeconds >= 15) {
          _recordingTimer?.cancel();
          await _record();
        } else {
          setState(() {});
        }
      });
      if (mounted) {
        setState(() {
          recording = true;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          recording = false;
          error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _preview() async {
    final localPath = recordingPath;
    final url = widget.currentUrl;
    if ((localPath == null || localPath.isEmpty) &&
        (url == null || url.isEmpty)) {
      setState(() => error = '请先录制声音');
      return;
    }
    if (playing) {
      await player.pause();
    } else {
      if (localPath != null && localPath.isNotEmpty) {
        await player.play(DeviceFileSource(localPath));
      } else {
        await player.play(UrlSource(url!));
      }
    }
    if (mounted) setState(() => playing = !playing);
  }

  Future<void> _toggleSonic() async {
    final url = widget.currentUrl;
    if (url == null || url.isEmpty) {
      if (mounted) setState(() => error = '还没有保存的声音');
      return;
    }
    if (playing) {
      await player.pause();
    } else {
      await player.play(UrlSource(url));
    }
    if (mounted) setState(() => playing = !playing);
  }

  Future<void> _deleteCloudVoice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除云端声音'),
        content: const Text('删除后将无法恢复，确定删除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      setState(() {
        saving = true;
        error = null;
      });
      await player.stop();
      await service.updateMe(token: await _token(), voiceKey: '');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _save() async {
    final localPath = recordingPath;
    if (localPath == null || localPath.isEmpty) {
      setState(() => error = '请先录制声音');
      return;
    }
    try {
      setState(() {
        saving = true;
        error = null;
      });
      final token = await _token();
      final bytes = await File(localPath).readAsBytes();
      final signed = await service.voiceUploadUrl(
        token: token,
        fileName: 'voice.m4a',
        contentType: 'audio/mp4',
      );
      final url = signed['url'];
      final key = signed['objectKey'];
      if (url is! String || key is! String) throw Exception('声音上传地址格式错误');
      if (!await service.uploadAvatar(
          url: url, bytes: bytes, contentType: 'audio/mp4')) {
        throw Exception('声音上传失败');
      }
      await service.updateMe(token: token, voiceKey: key);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('friend.auth.token') ?? '';
    if (value.isEmpty) throw Exception('请先登录');
    return value;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('声音录制')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Icon(TIcons.sonic,
                  size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              Text(recording ? '正在录音… ${recordingSeconds}s / 15s' : '录制你的声音名片'),
              const SizedBox(height: 24),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.orange)),
              const Spacer(),
              if (widget.currentUrl?.trim().isNotEmpty == true) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : _toggleSonic,
                        icon:
                            Icon(playing ? Icons.pause : Icons.cloud_outlined),
                        label: const Text('云端声音'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : _deleteCloudVoice,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除云端'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: saving ? null : _record,
                      icon: Icon(recording ? Icons.stop : Icons.mic),
                      label: Text(recording ? '停止录音' : '开始录音'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: saving ? null : _preview,
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      label: const Text('本地试听'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: saving ? null : _save,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: Text(saving ? '保存中…' : '保存声音'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
