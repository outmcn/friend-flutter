/// Call state shared by persistence, conversation previews and timeline bubbles.
class ImCall {
  static bool isCall(Map<String, dynamic> row) =>
      row['kind'] == 'call' || row['_timelineKind'] == 'call';

  static int? duration(dynamic value) {
    final parsed = value is num ? value : num.tryParse('$value');
    if (parsed == null || !parsed.isFinite || parsed < 0) return null;
    return parsed.toInt();
  }

  static bool terminal(dynamic status) => const {
        'ended',
        'cancelled',
        'rejected',
        'missed',
        'unanswered'
      }.contains(status);

  static Map<String, dynamic> merge(
      Map<String, dynamic> previous, Map<String, dynamic> update) {
    final next = <String, dynamic>{
      ...previous,
      for (final entry in update.entries)
        if (entry.value != null) entry.key: entry.value,
      'kind': 'call',
      '_timelineKind': 'call',
    };
    for (final key in [
      'callerId',
      'calleeId',
      'conversationId',
      'answeredAt',
      'endedAt'
    ]) {
      final snake = key.replaceAllMapped(
          RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
      final value = update[key] ?? update[snake] ?? previous[key];
      if (value != null) next[key] = value;
    }
    // The latest server event is authoritative for call direction.
    for (final key in ['callerId', 'calleeId']) {
      final snake = key.replaceAllMapped(
          RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
      final value = update[key] ?? update[snake];
      if (value != null && '$value'.isNotEmpty) next[key] = '$value';
    }
    next['createdAt'] = previous['createdAt'] ??
        update['startedAt'] ??
        update['createdAt'] ??
        update['started_at'] ??
        DateTime.now().toIso8601String();
    final local = duration(
        update['localDurationSeconds'] ?? update['local_duration_seconds']);
    final old = duration(
        previous['localDurationSeconds'] ?? previous['local_duration_seconds']);
    if (local != null || old != null) {
      next['localDurationSeconds'] = local == null
          ? old
          : old == null || local > old
              ? local
              : old;
    } else {
      next.remove('localDurationSeconds');
    }
    next['answered'] = previous['answered'] == true ||
        update['answered'] == true ||
        next['answeredAt'] != null ||
        previous['status'] == 'answered' ||
        update['status'] == 'answered';
    if ((terminal(previous['status']) && !terminal(update['status'])) ||
        (previous['status'] == 'answered' && update['status'] == 'ringing')) {
      next['status'] = previous['status'];
    }
    return next;
  }

  static String statusText(Map<String, dynamic> row) {
    final status = row['status'];
    if (status == 'cancelled') return '已取消';
    if (status == 'rejected') return '已拒绝';
    if (status == 'missed' || status == 'unanswered') return '未接听';
    final seconds =
        duration(row['localDurationSeconds'] ?? row['local_duration_seconds']);
    if (seconds != null) {
      return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    }
    if (status == 'answered') return '已接听';
    if (status == 'ended') return '已结束';
    if (status == 'ringing') return '等待接听';
    return '未接听';
  }
}
