import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/media_storage_service.dart';

void main() {
  test('keeps attachments added while a download batch is running', () {
    final batch = [
      {'id': 'downloaded'},
      {'id': 'failed'},
    ];
    final remaining = [
      {'id': 'failed', 'url': '/retry'},
    ];
    final latest = [
      {'id': 'downloaded'},
      {'id': 'failed', 'url': '/retry'},
      {'id': 'arrived-during-download', 'url': '/new'},
    ];

    final merged = mergePendingMediaQueue(
      batch: batch,
      remaining: remaining,
      latest: latest,
    );

    expect(merged.map((item) => item['id']).toSet(),
        {'failed', 'arrived-during-download'});
  });

  test('deduplicates newly queued items while preserving deferred work', () {
    final merged = mergePendingMediaQueue(
      batch: [{'id': 'deferred'}],
      remaining: [{'id': 'deferred', 'url': '/deferred'}],
      latest: [
        {'id': 'new', 'url': '/new'},
        {'id': 'new', 'url': '/duplicate'},
      ],
    );

    expect(merged.length, 2);
    expect(merged.firstWhere((item) => item['id'] == 'deferred')['url'],
        '/deferred');
  });
}
