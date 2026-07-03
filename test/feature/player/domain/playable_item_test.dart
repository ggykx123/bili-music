import 'package:bilimusic/feature/player/domain/playable_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlayableItem', () {
    test('lyricSearchTitles prefers page title before video title', () {
      final PlayableItem item = _item(
        title: 'Video Title',
        pageTitle: 'Part Title',
      );

      expect(item.lyricSearchTitles, <String>['Part Title', 'Video Title']);
    });

    test('lyricSearchTitles falls back to video title', () {
      final PlayableItem item = _item(title: 'Video Title', pageTitle: '   ');

      expect(item.lyricSearchTitles, <String>['Video Title']);
    });

    test('lyricSearchTitles removes duplicate video title', () {
      final PlayableItem item = _item(
        title: 'Same Title',
        pageTitle: 'Same Title',
      );

      expect(item.lyricSearchTitles, <String>['Same Title']);
    });

    test('displayTitle prefers page title when available', () {
      final PlayableItem item = _item(
        title: 'Video Title',
        pageTitle: 'Part Title',
        page: 2,
      );

      expect(item.displayTitle, 'Part Title');
      expect(item.displaySubtitle, 'Video Title');
    });

    test('displayTitle falls back to video title without page title', () {
      final PlayableItem item = _item(title: 'Video Title', pageTitle: ' ');

      expect(item.displayTitle, 'Video Title');
      expect(item.displaySubtitle, 'author');
    });

    test('displayTitle ignores owner mid stored as page title', () {
      final PlayableItem item = _item(
        title: 'Video Title',
        pageTitle: '1782644779321',
        ownerMid: 1782644779321,
      );

      expect(item.hasPageTitle, isFalse);
      expect(item.displayTitle, 'Video Title');
      expect(item.displaySubtitle, 'author');
    });

    test('displayTitle ignores numeric page title', () {
      final PlayableItem item = _item(
        title: 'Video Title',
        pageTitle: '1779235553988',
      );

      expect(item.hasPageTitle, isFalse);
      expect(item.displayTitle, 'Video Title');
      expect(item.displaySubtitle, 'author');
    });

    test('lyricSearchTitles ignores numeric page title', () {
      final PlayableItem item = _item(
        title: 'Video Title',
        pageTitle: '1779235553988',
      );

      expect(item.lyricSearchTitles, <String>['Video Title']);
    });
  });
}

PlayableItem _item({
  required String title,
  String? pageTitle,
  int? page,
  int? ownerMid,
}) {
  return PlayableItem(
    aid: 1,
    bvid: 'BVTEST123',
    title: title,
    author: 'author',
    coverUrl: 'https://example.com/cover.jpg',
    ownerMid: ownerMid,
    page: page,
    pageTitle: pageTitle,
  );
}
