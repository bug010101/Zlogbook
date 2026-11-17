import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zlogbook/core/app_info.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/services/features_parser.dart';
import 'package:zlogbook/widgets/common.dart';

/// 功能清单：解析 assets/features.txt 纯文本渲染，不引入 markdown 依赖。
class FeaturesPage extends StatelessWidget {
  const FeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('功能清单')),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(AppInfo.featuresAsset),
        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final String? data = snapshot.data;
          if (snapshot.hasError || data == null) {
            return const EmptyState(
              icon: Icons.description_outlined,
              title: '找不到功能清单',
              subtitle: 'assets/features.txt 未打包进应用',
            );
          }
          return _content(FeaturesParser.parse(data));
        },
      ),
    );
  }

  Widget _content(List<FeatureBlock> blocks) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      itemCount: blocks.length,
      itemBuilder: (BuildContext context, int index) =>
          _block(blocks[index]),
    );
  }

  Widget _block(FeatureBlock block) {
    switch (block.type) {
      case FeatureBlockType.spacer:
        return const SizedBox(height: 8);
      case FeatureBlockType.version:
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Row(
            children: <Widget>[
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: kAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text.rich(
                _span(block.segments, const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: kInk,
                )),
              ),
            ],
          ),
        );
      case FeatureBlockType.group:
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text.rich(
            _span(block.segments, const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: kInk,
            )),
          ),
        );
      case FeatureBlockType.bullet:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 7, right: 8),
                child: Icon(Icons.circle, size: 4, color: kInkSoft),
              ),
              Expanded(
                child: Text.rich(
                  _span(block.segments, const TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    color: kInk,
                  )),
                ),
              ),
            ],
          ),
        );
      case FeatureBlockType.text:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text.rich(
            _span(block.segments, const TextStyle(
              fontSize: 13,
              height: 1.6,
              color: kInkSoft,
            )),
          ),
        );
    }
    return const SizedBox.shrink();
  }

  TextSpan _span(List<FeatureSegment> segments, TextStyle base) {
    return TextSpan(
      style: base,
      children: segments
          .map(
            (FeatureSegment segment) => TextSpan(
              text: segment.text,
              style: TextStyle(
                fontWeight: segment.bold ? FontWeight.w700 : null,
                fontStyle: segment.italic ? FontStyle.italic : null,
                fontFamily: segment.code ? 'monospace' : null,
                backgroundColor:
                    segment.code ? kAccent.withValues(alpha: 0.08) : null,
              ),
            ),
          )
          .toList(),
    );
  }
}
