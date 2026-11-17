import 'package:flutter/material.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/core/utils/dates.dart';
import 'package:zlogbook/models/record.dart';

/// 时间轴视图：按修改日期分组倒序。
class TimelineView extends StatelessWidget {
  const TimelineView({
    super.key,
    required this.records,
    required this.tileBuilder,
  });

  final List<AssetRecord> records;
  final Widget Function(AssetRecord record) tileBuilder;

  @override
  Widget build(BuildContext context) {
    final List<AssetRecord> sorted = List<AssetRecord>.from(records)
      ..sort((AssetRecord a, AssetRecord b) =>
          b.updatedAt.compareTo(a.updatedAt));

    final List<_TimelineItem> items = <_TimelineItem>[];
    String? currentDay;
    List<AssetRecord> bucket = <AssetRecord>[];
    DateTime currentDate = DateTime.now();

    void flush() {
      if (bucket.isEmpty) {
        return;
      }
      items.add(_TimelineItem.header(currentDate, bucket.length));
      for (final AssetRecord record in bucket) {
        items.add(_TimelineItem.record(record));
      }
      bucket = <AssetRecord>[];
    }

    for (final AssetRecord record in sorted) {
      final String day = formatDate(record.updatedAt);
      if (currentDay != null && day != currentDay) {
        flush();
      }
      currentDay = day;
      currentDate = record.updatedAt;
      bucket.add(record);
    }
    flush();

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final _TimelineItem item = items[index];
        if (item.record != null) {
          return Padding(
            padding: const EdgeInsets.only(left: 10),
            child: tileBuilder(item.record!),
          );
        }
        return _DayHeader(date: item.date!, count: item.count);
      },
    );
  }
}

class _TimelineItem {
  const _TimelineItem.header(this.date, this.count) : record = null;

  const _TimelineItem.record(this.record)
      : date = null,
        count = 0;

  final DateTime? date;
  final int count;
  final AssetRecord? record;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date, required this.count});

  final DateTime date;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatDate(date),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kInk,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            relativeDayLabel(date),
            style: const TextStyle(fontSize: 12, color: kInkSoft),
          ),
          const Spacer(),
          Text(
            '$count 条',
            style: const TextStyle(fontSize: 12, color: kInkSoft),
          ),
        ],
      ),
    );
  }
}
