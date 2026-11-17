import 'package:flutter/material.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/core/utils/text_utils.dart';

/// 命中高亮的文本。查询词按空白切分，每个词单独高亮。
class HighlightText extends StatelessWidget {
  const HighlightText(
    this.text, {
    super.key,
    this.query = '',
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = style ?? DefaultTextStyle.of(context).style;
    final List<String> keywords = splitKeywords(query);
    if (keywords.isEmpty || text.isEmpty) {
      return Text(text, style: base, maxLines: maxLines, overflow: overflow);
    }

    final RegExp pattern = RegExp(
      keywords.map(RegExp.escape).join('|'),
      caseSensitive: false,
    );
    final List<RegExpMatch> matches = pattern.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text, style: base, maxLines: maxLines, overflow: overflow);
    }

    final TextStyle hit = base.copyWith(
      color: kAccent,
      fontWeight: FontWeight.w600,
      backgroundColor: kAccent.withValues(alpha: 0.12),
    );

    final List<TextSpan> spans = <TextSpan>[];
    int cursor = 0;
    for (final RegExpMatch match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(TextSpan(text: text.substring(match.start, match.end), style: hit));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: base,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
