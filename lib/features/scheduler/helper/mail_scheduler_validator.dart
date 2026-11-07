/// Validation for the communication (mail scheduler) form.
class MailSchedulerValidator {
  const MailSchedulerValidator._();

  /// Largest value a PostgreSQL `integer` column — every Odoo Integer field —
  /// can hold; more is a database error rather than a validation message.
  static const int _maxInteger = 2147483647;

  /// The interval's number: required, a whole number of at least 1. Only
  /// asked for when the unit is not "now" — an instant send has no interval.
  static String? interval(String? value, {required String unit}) {
    if (unit == 'now') return null;

    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Interval is required';

    final n = int.tryParse(text);
    if (n == null) return 'Enter a whole number';
    if (n < 1) return 'Interval must be at least 1';
    if (n > _maxInteger) return 'That number is too large';
    return null;
  }
}
