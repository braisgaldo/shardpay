// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shardpay/core/expense_math.dart';
import 'package:shardpay/models/app_models.dart';

void main() {
  test('equal allocations sum 100%', () {
    final members = const [
      GroupMember(userId: 'a', name: 'A', email: 'a@a.com'),
      GroupMember(userId: 'b', name: 'B', email: 'b@b.com'),
      GroupMember(userId: 'c', name: 'C', email: 'c@c.com'),
    ];

    final allocations = equalAllocations(members);
    final total = allocations.fold<double>(0, (sum, item) => sum + item.percentage);

    expect((total - 100).abs() < 0.01, isTrue);
  });
}
