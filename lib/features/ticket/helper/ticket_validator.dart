/// What Odoo's `event.event.ticket` would refuse, checked up front so the
/// ticket dialogs' buttons only enable for a ticket the server will take, and
/// the user sees why when they don't.
///
/// Each field check returns the message to show under the field, or null when
/// the value is fine. Seats, price and limit are optional — an empty box means
/// "unlimited" / "use the product's price" / "server default".
///
/// The rules are the same on Odoo 17, 18 and 19 except where noted: the
/// per-order limit only exists on 19, and price / ticket type only exist where
/// a product module is installed (`event_sale` on 17, `event_product` on 18+).
/// Callers say which of those the connected server has.
class TicketValidator {
  const TicketValidator._();

  /// Odoo 19's cap on `limit_max_per_order` (`event.event.EVENT_MAX_TICKETS`).
  static const int maxLimitPerOrder = 30;

  /// Largest value a PostgreSQL `integer` column — every Odoo Integer field —
  /// can hold; more is a database error rather than a validation message.
  static const int _maxInteger = 2147483647;

  static String? name(String? value) =>
      (value ?? '').trim().isEmpty ? 'Name is required' : null;

  /// Maximum seats: a whole number, where 0 (or empty) means unlimited.
  static String? seats(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;

    final seats = int.tryParse(text);
    if (seats == null) return 'Enter a whole number';
    if (seats < 0) return 'Seats cannot be negative';
    if (seats > _maxInteger) return 'That number is too large';
    return null;
  }

  /// Ticket price: a plain, non-negative number.
  static String? price(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;

    final price = double.tryParse(text);
    // tryParse also accepts "NaN" and "Infinity", which are not prices.
    if (price == null || !price.isFinite) {
      return 'Enter a valid price, e.g. 25 or 25.50';
    }
    if (price < 0) return 'Price cannot be negative';
    return null;
  }

  /// Odoo 19's limit per order (`_constrains_limit_max_per_order`): not
  /// negative, at most [maxLimitPerOrder], and no more than the ticket's own
  /// seats when those are limited ([seatsMax] above 0).
  static String? limitPerOrder(String? value, {int? seatsMax}) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;

    final limit = int.tryParse(text);
    if (limit == null) return 'Enter a whole number';
    if (limit < 0) return 'Limit cannot be negative';
    if (limit > maxLimitPerOrder) {
      return 'Limit per order cannot be more than $maxLimitPerOrder';
    }
    if (seatsMax != null && seatsMax > 0 && limit > seatsMax) {
      return 'Limit per order cannot be more than the maximum seats '
          '($seatsMax)';
    }
    return null;
  }

  /// `_constrains_dates_coherency`: the sale can't end before it starts.
  /// The same day is fine — Odoo only refuses start > end.
  static String? saleDates(DateTime? start, DateTime? end) {
    if (start != null && end != null && end.isBefore(start)) {
      return 'Sale end date cannot be earlier than the start date';
    }
    return null;
  }

  /// Whether every field passes — what a dialog's button gates on. [hasPrice]
  /// and [hasLimit] say whether the connected server's ticket model has those
  /// fields at all; a field it lacks isn't shown, so it isn't checked.
  static bool isValid({
    required String name,
    required String seats,
    required String price,
    required String limit,
    required bool hasPrice,
    required bool hasLimit,
    DateTime? saleStart,
    DateTime? saleEnd,
  }) {
    return TicketValidator.name(name) == null &&
        TicketValidator.seats(seats) == null &&
        (!hasPrice || TicketValidator.price(price) == null) &&
        (!hasLimit ||
            TicketValidator.limitPerOrder(
                  limit,
                  seatsMax: int.tryParse(seats.trim()),
                ) ==
                null) &&
        saleDates(saleStart, saleEnd) == null;
  }
}
