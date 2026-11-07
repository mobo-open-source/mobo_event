import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/utils/contact_validators.dart';

void main() {
  group('ContactValidators.phone', () {
    test('accepts an empty value, since the field is optional', () {
      expect(ContactValidators.phone(null), isNull);
      expect(ContactValidators.phone(''), isNull);
      expect(ContactValidators.phone('   '), isNull);
    });

    test('accepts numbers in the formats people actually type', () {
      for (final number in [
        '+91 98765 43210',
        '+1 (555) 123-4567',
        '(555) 123-4567',
        '555.123.4567',
        '0471 2345678',
        '0171/1234567',
        '+44 20 7946 0958',
        '9876543210',
        '  +91 98765 43210  ',
      ]) {
        expect(ContactValidators.phone(number), isNull, reason: number);
      }
    });

    test('accepts the international dialling prefix without counting it', () {
      expect(ContactValidators.phone('0091 98765 43210'), isNull);
      // 15 digits after the 00 prefix is still the E.164 maximum.
      expect(ContactValidators.phone('00 123456789012345'), isNull);
    });

    test('accepts a trailing extension', () {
      expect(ContactValidators.phone('555-123-4567 ext 12'), isNull);
      expect(ContactValidators.phone('555-123-4567 ext. 12'), isNull);
      expect(ContactValidators.phone('555-123-4567 x12'), isNull);
      expect(ContactValidators.phone('555-123-4567 EXT 12'), isNull);
    });

    test('rejects letters and other symbols', () {
      for (final number in ['abc1234567', '98765-4321a', 'N/A', '555#1234567']) {
        expect(
          ContactValidators.phone(number, label: 'Phone'),
          'Phone can only contain digits, spaces and + - ( ) . /',
          reason: number,
        );
      }
    });

    test('names the field it was asked about', () {
      expect(
        ContactValidators.phone('abc', label: 'Mobile'),
        startsWith('Mobile can only contain'),
      );
      expect(
        ContactValidators.phone('123', label: 'Mobile'),
        'Mobile number is too short (minimum 7 digits)',
      );
    });

    test('rejects a + that is not the first character', () {
      expect(
        ContactValidators.phone('91+9876543210'),
        'Use + only at the start of the number',
      );
      expect(
        ContactValidators.phone('++919876543210'),
        'Use + only at the start of the number',
      );
    });

    test('rejects unbalanced brackets', () {
      expect(
        ContactValidators.phone('(555 123-4567'),
        'Check the brackets in the Phone number',
      );
      expect(
        ContactValidators.phone('555) 123-4567'),
        'Check the brackets in the Phone number',
      );
      expect(
        ContactValidators.phone(')555( 123-4567'),
        'Check the brackets in the Phone number',
      );
    });

    test('rejects a number that is too short', () {
      expect(
        ContactValidators.phone('123456'),
        'Phone number is too short (minimum 7 digits)',
      );
      expect(
        ContactValidators.phone('+'),
        'Phone number is too short (minimum 7 digits)',
      );
      // The extension is not part of the number.
      expect(
        ContactValidators.phone('123 ext 4567'),
        'Phone number is too short (minimum 7 digits)',
      );
    });

    test('rejects a number that is too long', () {
      expect(
        ContactValidators.phone('+1234567890123456'),
        'Phone number is too long (maximum 15 digits)',
      );
    });

    test('accepts exactly the minimum and maximum lengths', () {
      expect(ContactValidators.phone('1234567'), isNull);
      expect(ContactValidators.phone('+123456789012345'), isNull);
    });
  });

  group('ContactValidators.website', () {
    test('accepts an empty value, since the field is optional', () {
      expect(ContactValidators.website(null), isNull);
      expect(ContactValidators.website(''), isNull);
      expect(ContactValidators.website('  '), isNull);
    });

    test('accepts addresses with or without a scheme', () {
      for (final site in [
        'example.com',
        'www.example.com',
        'http://example.com',
        'https://www.example.com',
        'HTTPS://Example.COM',
        'https://example.com/',
        'https://example.com/path/to/page',
        'https://example.com/path?query=1&x=y#section',
        'example.com?ref=app',
        'https://sub.domain.example.co.uk',
        'https://example.com:8080/admin',
        'example.com:443',
        'https://my-site.io',
        'https://example.digital',
        'https://192.168.1.10',
        'https://192.168.1.10:8069',
        '  https://example.com  ',
      ]) {
        expect(ContactValidators.website(site), isNull, reason: site);
      }
    });

    test('accepts internationalised domain names', () {
      expect(ContactValidators.website('https://bücher.de'), isNull);
      expect(ContactValidators.website('münchen.example.com'), isNull);
      expect(ContactValidators.website('https://example.xn--p1ai'), isNull);
    });

    test('rejects spaces', () {
      expect(
        ContactValidators.website('exa mple.com'),
        'Website cannot contain spaces',
      );
      expect(
        ContactValidators.website('https://example.com/a b'),
        'Website cannot contain spaces',
      );
    });

    test('rejects a scheme other than http and https', () {
      expect(
        ContactValidators.website('ftp://example.com'),
        'Website must start with http:// or https://',
      );
      expect(
        ContactValidators.website('file:///etc/passwd'),
        'Website must start with http:// or https://',
      );
    });

    test('points out an email address typed into the website field', () {
      const message = 'Enter a website address, not an email address';
      expect(ContactValidators.website('john@example.com'), message);
      expect(ContactValidators.website('mailto:john@example.com'), message);
      expect(ContactValidators.website('https://john@example.com'), message);
    });

    test('rejects something that is not a domain name', () {
      const message = 'Enter a valid website, e.g. www.example.com';
      for (final site in [
        'localhost',
        'example',
        'www',
        'example.',
        '.com',
        'example..com',
        '-example.com',
        'example-.com',
        'my_site.com',
        'example.c',
        'example.123',
        '192.168.1',
        '999.1.1.1',
        'http://',
        'https://',
        '//example.com',
        'example.com:abc',
        'tel:1234567',
        'https://[::1]',
      ]) {
        expect(ContactValidators.website(site), message, reason: site);
      }
    });

    test('rejects labels and names that are too long', () {
      final longLabel = 'a' * 64;
      expect(
        ContactValidators.website('$longLabel.com'),
        'Enter a valid website, e.g. www.example.com',
      );
      expect(
        ContactValidators.website('${'a' * 63}.com'),
        isNull,
      );
      // 4 labels of 63 characters plus dots pass 253 characters.
      final longName = List.filled(4, 'a' * 63).join('.');
      expect(
        ContactValidators.website('$longName.com'),
        'Enter a valid website, e.g. www.example.com',
      );
    });

    test('rejects a port outside 1-65535', () {
      const message = 'The port must be between 1 and 65535';
      expect(ContactValidators.website('example.com:0'), message);
      expect(ContactValidators.website('example.com:99999'), message);
      expect(ContactValidators.website('example.com:65535'), isNull);
    });
  });
}
