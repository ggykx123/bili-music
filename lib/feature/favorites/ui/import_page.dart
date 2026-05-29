import 'package:bilimusic/router/player_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  String? selectedPlatform = 'netease';

  @override
  void initState() {
    super.initState();
    markPlayerPageVisible();
  }

  @override
  void dispose() {
    markPlayerPageHidden();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('导入歌单'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 输入框
            TextField(
              decoration: InputDecoration(
                labelText: '歌单ID',
                hintText: '请输入歌单ID',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            // 选择平台 radiogroup
            RadioGroup(
              groupValue: selectedPlatform,
              onChanged: (String? value) {
                setState(() {
                  selectedPlatform = value;
                });
              },
              child: Row(
                children: [
                  Radio(value: 'netease'),
                  const Text('网易云'),
                  Radio(value: 'qq'),
                  const Text('QQ音乐'),
                ],
              ),
            ),
            // 导入按钮
            const SizedBox(height: 16.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // 导入逻辑
                },
                child: Text('导入'),
              ),
            ),

            // 提示
            const SizedBox(height: 16.0),
            // Center(child: const ImportSupportHint()),
          ],
        ),
      ),
    );
  }
}

class ImportSupportHint extends StatelessWidget {
  const ImportSupportHint({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      '支持导入网易云,QQ音乐的歌单',
      style: TextStyle(color: Colors.grey),
    );
  }
}
