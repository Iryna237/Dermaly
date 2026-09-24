import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ziskin/models/routine_product.dart';

void main() {
  RoutineProduct product(String category, [RoutineTime time = RoutineTime.both]) =>
      RoutineProduct(category: category, name: 'Product', description: 'Desc', time: time);

  group('RoutineProduct.fromJson', () {
    test('anything other than a map is rejected', () {
      expect(RoutineProduct.fromJson(null), isNull);
      expect(RoutineProduct.fromJson('Foaming cleanser'), isNull);
      expect(RoutineProduct.fromJson(const ['Foaming cleanser']), isNull);
    });

    test('a product without a name is rejected', () {
      expect(RoutineProduct.fromJson({'category': 'Cleanser'}), isNull);
      expect(RoutineProduct.fromJson({'name': '   '}), isNull);
    });

    test('missing fields get sensible defaults', () {
      final parsed = RoutineProduct.fromJson({'name': '  Gentle Gel  '})!;

      expect(parsed.name, 'Gentle Gel');
      expect(parsed.category, 'Care');
      expect(parsed.description, 'Recommended for your skin.');
      expect(parsed.time, RoutineTime.both);
    });

    test('the time of day is read loosely', () {
      RoutineTime timeOf(Object? raw) =>
          RoutineProduct.fromJson({'name': 'Serum', 'time': raw})!.time;

      expect(timeOf('morning'), RoutineTime.morning);
      expect(timeOf('AM'), RoutineTime.morning);
      expect(timeOf(' Evening '), RoutineTime.evening);
      expect(timeOf('night'), RoutineTime.evening);
      expect(timeOf('PM'), RoutineTime.evening);
      expect(timeOf('noon'), RoutineTime.both);
      expect(timeOf(null), RoutineTime.both);
    });

    test('a saved product reads back the same', () {
      const original = RoutineProduct(
        category: 'Protection',
        name: 'SPF 50 Fluid',
        description: 'Daily broad-spectrum protection.',
        time: RoutineTime.morning,
      );

      final copy = RoutineProduct.fromJson(original.toJson())!;

      expect(copy.category, original.category);
      expect(copy.name, original.name);
      expect(copy.description, original.description);
      expect(copy.time, original.time);
      expect(copy.id, original.id);
    });
  });

  group('RoutineProduct', () {
    test('the id ignores letter case', () {
      const product = RoutineProduct(
        category: 'Cleanser',
        name: 'Foaming Gel',
        description: 'Desc',
      );
      expect(product.id, 'cleanser|foaming gel');
    });

    test('morning and evening follow the time of day', () {
      final morning = product('Serum', RoutineTime.morning);
      final evening = product('Serum', RoutineTime.evening);
      final both = product('Serum');

      expect([morning.isMorning, morning.isEvening], [true, false]);
      expect([evening.isMorning, evening.isEvening], [false, true]);
      expect([both.isMorning, both.isEvening], [true, true]);
    });

    test('the time label reads as shown on the product sheet', () {
      expect(product('Serum', RoutineTime.morning).timeLabel, 'Morning');
      expect(product('Serum', RoutineTime.evening).timeLabel, 'Night');
      expect(product('Serum').timeLabel, 'Morning & Night');
    });

    test('the illustration follows the category', () {
      expect(product('Cleansing Foam').imagePath, 'assets/images/cleanser.png');
      expect(product('Sun Protection').imagePath, 'assets/images/sunscreen.png');
      expect(product('SPF').imagePath, 'assets/images/sunscreen.png');
      expect(product('Moisturizer').imagePath, 'assets/images/moisturizer.png');
      expect(product('Hydrating Toner').imagePath, 'assets/images/moisturizer.png');
      expect(product('Serum').imagePath, 'assets/images/serum.png');
      expect(product('Eye Cream').imagePath, 'assets/images/serum.png');
    });

    test('the icon follows the category', () {
      expect(product('Cleanser').icon, Icons.bubble_chart_outlined);
      expect(product('Sunscreen').icon, Icons.wb_sunny_outlined);
      expect(product('Moisturizer').icon, Icons.water_drop_outlined);
      expect(product('Treatment').icon, Icons.science_outlined);
      expect(product('Exfoliant').icon, Icons.auto_awesome_outlined);
      expect(product('Clay Mask').icon, Icons.spa_outlined);
      expect(product('Eye Cream').icon, Icons.visibility_outlined);
      expect(product('Toner').icon, Icons.medication_outlined);
    });
  });
}
