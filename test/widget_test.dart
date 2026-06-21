// import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bpa_app/main.dart';

void main() {
  testWidgets('Login screen smoke test', (WidgetTester tester) async {
    // 1. অ্যাপটি বিল্ড করুন (MyApp এর বদলে BpaApp ব্যবহার করা হয়েছে)
    await tester.pumpWidget(const BpaApp());

    // 2. চেক করুন যে স্ক্রিনে 'Login' এবং 'Register' লেখা বাটন বা টেক্সট আছে কিনা
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);

    // 3. নিশ্চিত হোন যে আগের কাউন্টার অ্যাপের '0' এখন আর নেই
    expect(find.text('0'), findsNothing);
  });
}