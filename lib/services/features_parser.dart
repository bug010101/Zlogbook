import 'dart:convert';

/// features.txt 的解析结果：只支持少量语法，遇到不认识的标记按原文显示。
enum FeatureBlockType { version, group, bullet, text, spacer }

class FeatureSegment {
  const FeatureSegment({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.code = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool code;
}

class FeatureBlock {
  const FeatureBlock(this.type, this.segments);

  final FeatureBlockType type;
  final List<FeatureSegment> segments;

  String get plainText =>
      segments.map((FeatureSegment segment) => segment.text).join();
}

class FeaturesParser {
  const FeaturesParser._();

  static List<FeatureBlock> parse(String source) {
    final List<FeatureBlock> blocks = <FeatureBlock>[];
    final List<String> lines = const LineSplitter().convert(source);
    for (final String rawLine in lines) {
      final String line = rawLine.replaceAll('\r', '');
      final String trimmed = line.trim();
      if (trimmed.isEmpty) {
        blocks.add(const FeatureBlock(FeatureBlockType.spacer, <FeatureSegment>[]));
        continue;
      }
      if (trimmed.startsWith('## ')) {
        blocks.add(
          FeatureBlock(
            FeatureBlockType.group,
            parseInline(trimmed.substring(3)),
          ),
        );
        continue;
      }
      if (trimmed.startsWith('#')) {
        blocks.add(
          FeatureBlock(
            FeatureBlockType.version,
            parseInline(_stripHashes(trimmed)),
          ),
        );
        continue;
      }
      if (trimmed.startsWith('- ')) {
        blocks.add(
          FeatureBlock(
            FeatureBlockType.bullet,
            parseInline(trimmed.substring(2)),
          ),
        );
        continue;
      }
      blocks.add(FeatureBlock(FeatureBlockType.text, parseInline(trimmed)));
    }
    return blocks;
  }

  static String _stripHashes(String line) {
    int index = 0;
    while (index < line.length && line[index] == '#') {
      index++;
    }
    return line.substring(index).trim();
  }

  /// 支持 **加粗**、*斜体*、`代码`，其余原样保留。
  static List<FeatureSegment> parseInline(String text) {
    final List<FeatureSegment> segments = <FeatureSegment>[];
    final StringBuffer buffer = StringBuffer();

    void flush() {
      if (buffer.isNotEmpty) {
        segments.add(FeatureSegment(text: buffer.toString()));
        buffer.clear();
      }
    }

    int i = 0;
    while (i < text.length) {
      if (text.startsWith('**', i)) {
        final int end = text.indexOf('**', i + 2);
        if (end > i + 1) {
          flush();
          segments.add(
            FeatureSegment(text: text.substring(i + 2, end), bold: true),
          );
          i = end + 2;
          continue;
        }
      }
      if (text[i] == '`') {
        final int end = text.indexOf('`', i + 1);
        if (end > i) {
          flush();
          segments.add(
            FeatureSegment(text: text.substring(i + 1, end), code: true),
          );
          i = end + 1;
          continue;
        }
      }
      if (text[i] == '*') {
        final int end = text.indexOf('*', i + 1);
        if (end > i + 1) {
          flush();
          segments.add(
            FeatureSegment(text: text.substring(i + 1, end), italic: true),
          );
          i = end + 1;
          continue;
        }
      }
      buffer.write(text[i]);
      i++;
    }
    flush();
    if (segments.isEmpty) {
      segments.add(const FeatureSegment(text: ''));
    }
    return segments;
  }
}
