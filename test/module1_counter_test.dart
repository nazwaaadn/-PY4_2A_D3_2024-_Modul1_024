// test/module1_counter_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logbook_app_024/features/logbook/counter_controller_test.dart';

void main() {
  var actual, expected;

  group('Module 1 - CounterController (with storage & step)', () {
    late CounterController controller;
    const username = "admin";

    setUp(() async {
      // (1) setup (arrange, build)
      SharedPreferences.setMockInitialValues({}); // mock storage
      controller = CounterController(username);
      await controller.loadLastValue(); // load initial value
    });

    test('initial value should be 0', () {
      // (2) exercise set up data
      actual = controller.value;
      expected = 0;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    test('setStep should change step value', () {
      // (2) exercise (act, operate)
      controller.setStep(5);
      actual = controller.step;
      expected = 5;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    test('setStep should ignore negative value', () {
      // (1) setup (arrange, build)
      controller.setStep(3);

      // (2) exercise (act, operate)
      controller.setStep(-1);
      actual = controller.step;
      expected = 3;

      // (3) verify (assert, check)
      expect(controller.step, 3);
    });

    test('increment should increase counter based on step', () async {
      // (1) setup (arrange, build)
      controller.setStep(2);

      // (2) exercise (act, operate)
      controller.increment();
      actual = controller.value;
      expected = 2;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    test('decrement should decrease counter based on step', () async {
      // (1) setup (arrange, build)
      controller.setStep(2);
      controller.increment(); // counter = 2

      // (2) exercise (act, operate)
      controller.decrement();
      actual = controller.value;
      expected = 0;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    test('decrement should not go below zero', () async {
      // (1) setup (arrange, build)
      controller.setStep(5);

      // (2) exercise (act, operate)
      controller.decrement();
      actual = controller.value;
      expected = 0;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    test('reset should set counter to zero', () async {
      // (1) setup (arrange, build)
      controller.increment();

      // (2) exercise (act, operate)
      controller.reset();
      actual = controller.value;
      expected = 0;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    test('history should record actions', () async {
      // (1) setup (arrange, build)
      controller.setStep(1);

      // (2) exercise (act, operate)
      controller.increment();
      var actual1 = controller.history.isNotEmpty;
      var expected1 = true;
      var actual2 = controller.history.first.action.contains("menambah");
      var expected2 = true;

      // (3) verify (assert, check)
      expect(
        actual1,
        expected1,
        reason: 'Expected $expected1 but got $actual1',
      );
      expect(
        actual2,
        expected2,
        reason: 'Expected $expected2 but got $actual2',
      );
    });

    test('history should not exceed 5 items', () async {
      // (1) setup (arrange, build)
      controller.setStep(1);

      // (2) exercise (act, operate)
      for (int i = 0; i < 6; i++) {
        controller.increment();
      }
      actual = controller.history.length;
      expected = 5;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    test('counter should persist using SharedPreferences', () async {
      // (1) setup (arrange, build)
      controller.setStep(3);
      controller.increment(); // counter = 3
      await controller.saveLastValue(controller.value);

      // buat instance baru (simulasi app restart)
      final newController = CounterController(username);

      // (2) exercise (act, operate)
      await newController.loadLastValue();
      actual = newController.value;
      expected = 3;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });
  });
}
