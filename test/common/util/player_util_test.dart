import 'package:bilimusic/common/util/player_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlayerUtil.buildRenderableLyrics', () {
    test('returns plain lyrics when lyrics are not timed', () {
      const String rawLyrics = '纯文本歌词';

      final String? result = PlayerUtil.buildRenderableLyrics(
        rawLyrics,
        const Duration(seconds: 1),
      );

      expect(result, rawLyrics);
    });
  });

  group('PlayerUtil.stripLyricTimingMarks', () {
    test('removes common karaoke word timing marks', () {
      expect(
        PlayerUtil.stripLyricTimingMarks(
          '[0,1000](0,500)歌(500,500,0)词<1000,400,0>',
        ),
        '歌词',
      );
    });
  });
}
