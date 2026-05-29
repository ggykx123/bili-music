enum MetingServer {
  netease('netease', '网易云音乐'),
  kugou('kugou', '酷狗音乐'),
  tencent('tencent', 'QQ音乐');

  const MetingServer(this.apiValue, this.label);

  final String apiValue;
  final String label;
}
