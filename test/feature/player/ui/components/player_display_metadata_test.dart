import 'package:bilimusic/feature/metadata/domain/metadata.dart';
import 'package:bilimusic/feature/player/domain/playable_item.dart';
import 'package:bilimusic/feature/player/ui/components/player_display_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('player display metadata helpers', () {
    test('resolveDisplayTitle prefers matching metadata title', () {
      final PlayableItem item = _item(pageTitle: '1782644779321');
      final Metadata metadata = Metadata(stableId: item.stableId, title: '刀马旦');

      expect(resolveDisplayTitle(item: item, metadata: metadata), '刀马旦');
      expect(resolveDisplaySubtitle(item: item, metadata: metadata), '投稿标题');
    });

    test('resolveDisplayTitle ignores metadata with different stable id', () {
      final PlayableItem item = _item(pageTitle: '1782644779321');
      const Metadata metadata = Metadata(
        stableId: 'bvid:OTHER:cid:2',
        title: '刀马旦',
      );

      expect(resolveDisplayTitle(item: item, metadata: metadata), '投稿标题');
      expect(resolveDisplaySubtitle(item: item, metadata: metadata), '作者');
    });

    test('resolveDisplayTitle keeps valid page title without metadata', () {
      final PlayableItem item = _item(pageTitle: '01.大城小爱 - 王力宏');

      expect(resolveDisplayTitle(item: item, metadata: null), '01.大城小爱 - 王力宏');
      expect(resolveDisplaySubtitle(item: item, metadata: null), '投稿标题');
    });
  });
}

PlayableItem _item({String? pageTitle}) {
  return PlayableItem(
    aid: 1,
    bvid: 'BVTEST123',
    title: '投稿标题',
    author: '作者',
    coverUrl: 'https://example.com/cover.jpg',
    cid: 100,
    page: 1,
    pageTitle: pageTitle,
  );
}
