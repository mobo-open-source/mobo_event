import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/features/ticket/helper/ticket_validator.dart';

void main() {
  group('TicketValidator.name', () {
    test('requires something other than whitespace', () {
      expect(TicketValidator.name(null), 'Name is required');
      expect(TicketValidator.name(''), 'Name is required');
      expect(TicketValidator.name('   '), 'Name is required');
      expect(TicketValidator.name('VIP'), isNull);
      expect(TicketValidator.name('  VIP  '), isNull);
    });
  });

  group('TicketValidator.seats', () {
    test('is optional: empty means unlimited', () {
      expect(TicketValidator.seats(null), isNull);
      expect(TicketValidator.seats(''), isNull);
      expect(TicketValidator.seats('  '), isNull);
    });

    test('accepts whole numbers including 0', () {
      expect(TicketValidator.seats('0'), isNull);
      expect(TicketValidator.seats('100'), isNull);
      expect(TicketValidator.seats(' 25 '), isNull);
      expect(TicketValidator.seats('2147483647'), isNull);
    });

    test('rejects anything that is not a whole number', () {
      for (final input in ['abc', '1.5', '1,5', '-', '1 2', '10a']) {
        expect(
          TicketValidator.seats(input),
          'Enter a whole number',
          reason: input,
        );
      }
    });

    test('rejects negative numbers', () {
      expect(TicketValidator.seats('-1'), 'Seats cannot be negative');
    });

    test('rejects a number the database column cannot hold', () {
      expect(TicketValidator.seats('2147483648'), 'That number is too large');
    });
  });

  group('TicketValidator.price', () {
    test('is optional', () {
      expect(TicketValidator.price(null), isNull);
      expect(TicketValidator.price(''), isNull);
    });

    test('accepts plain non-negative numbers', () {
      for (final input in ['0', '25', '25.5', '25.50', ' 10 ', '0.0']) {
        expect(TicketValidator.price(input), isNull, reason: input);
      }
    });

    test('rejects text and non-finite numbers', () {
      for (final input in ['abc', '12,50', r'$25', 'NaN', 'Infinity', '-']) {
        expect(
          TicketValidator.price(input),
          'Enter a valid price, e.g. 25 or 25.50',
          reason: input,
        );
      }
    });

    test('rejects a negative price', () {
      expect(TicketValidator.price('-5'), 'Price cannot be negative');
    });
  });

  group('TicketValidator.limitPerOrder', () {
    test('is optional', () {
      expect(TicketValidator.limitPerOrder(null), isNull);
      expect(TicketValidator.limitPerOrder(''), isNull);
    });

    test('accepts 0 up to the cap', () {
      expect(TicketValidator.limitPerOrder('0'), isNull);
      expect(TicketValidator.limitPerOrder('10'), isNull);
      expect(TicketValidator.limitPerOrder('30'), isNull);
    });

    test('rejects a value that is not a whole number', () {
      expect(TicketValidator.limitPerOrder('a'), 'Enter a whole number');
      expect(TicketValidator.limitPerOrder('2.5'), 'Enter a whole number');
    });

    test('rejects a negative limit', () {
      expect(TicketValidator.limitPerOrder('-1'), 'Limit cannot be negative');
    });

    test('rejects more than the per-order cap', () {
      expect(
        TicketValidator.limitPerOrder('31'),
        'Limit per order cannot be more than 30',
      );
    });

    test('cannot exceed the seats when seats are limited', () {
      expect(
        TicketValidator.limitPerOrder('11', seatsMax: 10),
        'Limit per order cannot be more than the maximum seats (10)',
      );
      expect(TicketValidator.limitPerOrder('10', seatsMax: 10), isNull);
    });

    test('is not held to the seats when they are unlimited', () {
      expect(TicketValidator.limitPerOrder('20', seatsMax: 0), isNull);
      expect(TicketValidator.limitPerOrder('20', seatsMax: null), isNull);
    });
  });

  group('TicketValidator.saleDates', () {
    final jan1 = DateTime(2026, 1, 1);
    final jan2 = DateTime(2026, 1, 2);

    test('accepts a missing date on either side', () {
      expect(TicketValidator.saleDates(null, null), isNull);
      expect(TicketValidator.saleDates(jan1, null), isNull);
      expect(TicketValidator.saleDates(null, jan1), isNull);
    });

    test('accepts an end on or after the start', () {
      expect(TicketValidator.saleDates(jan1, jan2), isNull);
      expect(TicketValidator.saleDates(jan1, jan1), isNull);
    });

    test('rejects an end before the start', () {
      expect(
        TicketValidator.saleDates(jan2, jan1),
        'Sale end date cannot be earlier than the start date',
      );
    });
  });

  group('TicketValidator.isValid', () {
    bool valid({
      String name = 'VIP',
      String seats = '',
      String price = '',
      String limit = '',
      bool hasPrice = false,
      bool hasLimit = false,
      DateTime? saleStart,
      DateTime? saleEnd,
    }) => TicketValidator.isValid(
      name: name,
      seats: seats,
      price: price,
      limit: limit,
      hasPrice: hasPrice,
      hasLimit: hasLimit,
      saleStart: saleStart,
      saleEnd: saleEnd,
    );

    test('a name alone is enough — every other field is optional', () {
      expect(valid(), isTrue);
    });

    test('needs a name', () {
      expect(valid(name: ''), isFalse);
      expect(valid(name: '  '), isFalse);
    });

    test('rejects bad seats', () {
      expect(valid(seats: 'abc'), isFalse);
      expect(valid(seats: '-3'), isFalse);
      expect(valid(seats: '50'), isTrue);
    });

    test('only checks price where the server has it', () {
      expect(valid(price: 'abc', hasPrice: false), isTrue);
      expect(valid(price: 'abc', hasPrice: true), isFalse);
      expect(valid(price: '12.5', hasPrice: true), isTrue);
    });

    test('only checks the limit where the server has it', () {
      expect(valid(limit: '99', hasLimit: false), isTrue);
      expect(valid(limit: '99', hasLimit: true), isFalse);
      expect(valid(limit: '5', hasLimit: true), isTrue);
    });

    test('checks the limit against the seats, with spaces tolerated', () {
      expect(valid(seats: ' 10 ', limit: '11', hasLimit: true), isFalse);
      expect(valid(seats: ' 10 ', limit: '10', hasLimit: true), isTrue);
    });

    test('rejects an end date before the start date', () {
      expect(
        valid(saleStart: DateTime(2026, 1, 5), saleEnd: DateTime(2026, 1, 1)),
        isFalse,
      );
      expect(
        valid(saleStart: DateTime(2026, 1, 1), saleEnd: DateTime(2026, 1, 5)),
        isTrue,
      );
    });
  });
}
