import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/core/services/event_access_rights.dart';
import 'package:mobo_event/features/event/model/event_slot.dart';
import 'package:mobo_event/features/event/pages/event_edit_screen.dart';
import 'package:mobo_event/features/event/services/event_detailed_services.dart';
import 'package:mobo_event/shared/helper/helper_method.dart';
import 'package:mobo_event/shared/widgets/shimmer_card/shimmer_card.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:timezone/data/latest.dart' as tz;

import '../../../shared/widgets/dialogs/common_dialog.dart';
import '../../../shared/widgets/dialogs/pinned_footer_layout.dart';
import '../../../shared/widgets/forms/field_label.dart';
import '../../../shared/widgets/mobo/mobo_button.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../provider/event_detailed_provider.dart';
import 'package:timezone/standalone.dart' as tz;
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';

class CalendarScreen extends StatefulWidget {
  final int eventId;
  final DateTime? fromDate;
  final DateTime? toDate;

  /// True when opened from the create/edit forms, which replace themselves
  /// with this screen; false when pushed on top of Event Details.
  final bool returnToEdit;
  const CalendarScreen({
    super.key,
    this.fromDate,
    this.toDate,
    required this.eventId,
    this.returnToEdit = true,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final services = EventDetailedServices();
  bool initialLoading = true;

  Map<DateTime, List<EventSlotModel>> _events = {};

  List<EventSlotModel> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  /// The day-name strip above a month grid: a pale brand-tint band with the
  /// names in the brand colour (white on a faint wash in dark mode).
  ///
  /// [compact] is the short-window version: a fixed 28dp strip instead of one
  /// padded to ~36dp, so the grid under it gets the height.
  Widget _weekdayStrip(bool isDark, {bool compact = false}) {
    final style = TextStyle(
      color: isDark ? Colors.white : AppTheme.primaryColor,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );
    return Container(
      width: double.infinity,
      height: compact ? 28 : null,
      alignment: compact ? Alignment.center : null,
      padding: compact ? null : const EdgeInsets.symmetric(vertical: 10),
      color: isDark
          ? Colors.white.withValues(alpha: 0.12)
          : AppTheme.primaryTint,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final day in const [
            "SUN",
            "MON",
            "TUE",
            "WED",
            "THU",
            "FRI",
            "SAT",
          ])
            Text(day, style: style),
        ],
      ),
    );
  }

  /// Previous / month name / next row above a month grid.
  ///
  /// [compact] is the short-window version: a fixed 52dp row with 40dp arrow
  /// buttons instead of ~72dp.
  Widget _monthNav({
    required bool isDark,
    required String label,
    required VoidCallback onPrev,
    required VoidCallback onNext,
    bool compact = false,
  }) {
    // Brand-filled, as in the design: the arrows and the month are one family
    // of buttons. Material rather than a coloured Container, so the arrow's
    // ripple draws on top of the fill instead of beneath it.
    Widget arrow(IconData icon, VoidCallback onTap) => Material(
      color: AppTheme.primaryColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        visualDensity: compact ? VisualDensity.compact : null,
        color: Colors.white,
        icon: Icon(icon),
        onPressed: onTap,
      ),
    );

    return Container(
      height: compact ? 52 : null,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 0 : 12),
      decoration: BoxDecoration(
        color: AppTheme.surface(isDark),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          arrow(Icons.chevron_left, onPrev),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(vertical: compact ? 9 : 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          arrow(Icons.chevron_right, onNext),
        ],
      ),
    );
  }

  Future<DateTimeRange?> _showRangeCalendarPopup({
    DateTimeRange? initialRange,
  }) async {
    final firstDay = widget.fromDate ?? DateTime(2020);
    final lastDay = widget.toDate ?? DateTime(2030);

    DateTime focusedDay = initialRange?.start ?? firstDay;
    if (focusedDay.isBefore(firstDay)) focusedDay = firstDay;
    if (focusedDay.isAfter(lastDay)) focusedDay = lastDay;

    DateTime? rangeStart = initialRange?.start;
    DateTime? rangeEnd = initialRange?.end;

    return showDialog<DateTimeRange>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPopupState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            // The full-size dialog needs ~560dp; a phone on its side has ~300,
            // so there the header, rows and strip shrink and the body scrolls.
            final compact = context.isShortScreen;
            final onSurface = isDark ? Colors.white : Colors.black87;

            final prevMonth = DateTime(focusedDay.year, focusedDay.month - 1);
            final nextMonth = DateTime(focusedDay.year, focusedDay.month + 1);
            final canPrev =
                prevMonth.year > firstDay.year ||
                (prevMonth.year == firstDay.year &&
                    prevMonth.month >= firstDay.month);
            final canNext = !nextMonth.isAfter(lastDay);

            // Laid out like the create-activity date picker (Material's,
            // in the brand theme): a brand header band naming what is being
            // picked over the range so far, the month with its arrows, a
            // single-letter weekday row, and Cancel / OK text buttons.
            Widget headerBand() {
              final fmt = DateFormat("MMM d");
              final placeholder = TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
              );
              return Container(
                width: double.infinity,
                color: primaryColor,
                padding: compact
                    ? const EdgeInsets.fromLTRB(20, 10, 20, 12)
                    : const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Select date range",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 12),
                    Text.rich(
                      TextSpan(
                        children: [
                          rangeStart == null
                              ? TextSpan(text: "Start date", style: placeholder)
                              : TextSpan(text: fmt.format(rangeStart!)),
                          const TextSpan(text: " – "),
                          rangeEnd == null
                              ? TextSpan(text: "End date", style: placeholder)
                              : TextSpan(text: fmt.format(rangeEnd!)),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 20 : 24,
                      ),
                    ),
                  ],
                ),
              );
            }

            Widget monthArrow({
              required IconData icon,
              required String tooltip,
              required DateTime? target,
            }) => IconButton(
              visualDensity: compact ? VisualDensity.compact : null,
              tooltip: tooltip,
              color: onSurface,
              icon: Icon(icon),
              onPressed: target == null
                  ? null
                  : () => setPopupState(() => focusedDay = target),
            );

            // The month label starts 24 in, level with the header's text.
            Widget monthRow() => Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                compact ? 0 : 8,
                0,
                compact ? 0 : 4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat("MMMM yyyy").format(focusedDay),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                      ),
                    ),
                  ),
                  monthArrow(
                    icon: Icons.chevron_left,
                    tooltip: 'Previous month',
                    target: canPrev ? prevMonth : null,
                  ),
                  monthArrow(
                    icon: Icons.chevron_right,
                    tooltip: 'Next month',
                    target: canNext ? nextMonth : null,
                  ),
                ],
              ),
            );

            final dayStyle = TextStyle(
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w500,
              color: onSurface,
            );
            final pickedStyle = dayStyle.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            );
            final weekdayStyle = TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryLabelColor(isDark),
            );
            final rowHeight = compact ? 34.0 : 44.0;
            final weekdayHeight = compact ? 24.0 : 32.0;

            Widget calendar() => TableCalendar(
              headerVisible: false,
              rowHeight: rowHeight,
              daysOfWeekHeight: weekdayHeight,
              firstDay: firstDay,
              lastDay: lastDay,
              focusedDay: focusedDay.isAfter(lastDay)
                  ? lastDay
                  : focusedDay.isBefore(firstDay)
                  ? firstDay
                  : focusedDay,
              availableGestures: AvailableGestures.horizontalSwipe,
              rangeStartDay: rangeStart,
              rangeEndDay: rangeEnd,
              rangeSelectionMode: RangeSelectionMode.toggledOn,
              onPageChanged: (day) {
                setPopupState(() {
                  focusedDay = day;
                });
              },
              onDaySelected: (selectedDay, newFocusedDay) {
                setPopupState(() {
                  focusedDay = newFocusedDay;

                  if (rangeStart == null ||
                      (rangeStart != null && rangeEnd != null)) {
                    rangeStart = selectedDay;
                    rangeEnd = null;
                  } else if (selectedDay.isBefore(rangeStart!)) {
                    rangeEnd = rangeStart;
                    rangeStart = selectedDay;
                  } else {
                    rangeEnd = selectedDay;
                  }
                });
              },
              daysOfWeekStyle: DaysOfWeekStyle(
                // S M T W T F S, as the Material picker heads its columns.
                dowTextFormatter: (date, locale) =>
                    DateFormat('EEEEE', locale as String?).format(date),
                weekdayStyle: weekdayStyle,
                weekendStyle: weekdayStyle,
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                cellMargin: EdgeInsets.all(compact ? 2 : 4),
                defaultTextStyle: dayStyle,
                weekendTextStyle: dayStyle,
                withinRangeTextStyle: dayStyle,
                // Days outside the event, which a slot can't fall on.
                disabledTextStyle: dayStyle.copyWith(
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                // Today: a brand ring, as in the Material picker.
                todayDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryColor),
                ),
                todayTextStyle: dayStyle.copyWith(color: primaryColor),
                // The two ends: filled brand circles; the days between sit
                // on a pale band of the same colour.
                rangeStartDecoration: const BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                rangeEndDecoration: const BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                rangeStartTextStyle: pickedStyle,
                rangeEndTextStyle: pickedStyle,
                rangeHighlightColor: primaryColor.withValues(alpha: 0.15),
              ),
            );

            final textButtonStyle = TextButton.styleFrom(
              foregroundColor: primaryColor,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            );

            Widget actions() => Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, compact ? 4 : 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: textButtonStyle,
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: textButtonStyle,
                    // Greyed until both ends of the range are picked.
                    onPressed: rangeStart == null || rangeEnd == null
                        ? null
                        : () => Navigator.pop(
                            context,
                            DateTimeRange(
                              start: DateTime(
                                rangeStart!.year,
                                rangeStart!.month,
                                rangeStart!.day,
                              ),
                              end: DateTime(
                                rangeEnd!.year,
                                rangeEnd!.month,
                                rangeEnd!.day,
                              ),
                            ),
                          ),
                    child: const Text("OK"),
                  ),
                ],
              ),
            );

            // One column. The body scrolls only when the window is too short
            // for it (a phone on its side, where the header and grid also
            // shrink); Cancel / OK stay pinned underneath, and scroll with the
            // body only when the keyboard-sized room left is tiny.
            final content = PinnedFooterLayout(
              scrollAllBelow: 200,
              gap: compact ? 0 : 4,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  headerBand(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        monthRow(),
                        // Room for a six-week month always, so the buttons
                        // don't jump as months of four or five weeks pass.
                        SizedBox(
                          height: weekdayHeight + 6 * rowHeight,
                          child: calendar(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              footer: actions(),
            );

            return Dialog(
              backgroundColor: AppTheme.surface(isDark),
              insetPadding: compact
                  ? const EdgeInsets.symmetric(horizontal: 24, vertical: 8)
                  : const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              // The create-activity picker's 28 corners; the clip rounds the
              // header band with them.
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: ConstrainedBox(
                // A phone-width picker, even on a wide landscape window.
                constraints: const BoxConstraints(maxWidth: 360),
                child: content,
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData(widget.eventId);
    if (widget.fromDate != null) {
      _focusedDay = widget.fromDate!;
      _selectedDay = widget.fromDate!;
    }
  }

  /// date_tz is a related field and can be empty; Odoo's slot calendar
  /// falls back to UTC in that case, so do the same instead of throwing.
  tz.Location _location(String name) {
    try {
      return tz.getLocation(name);
    } catch (_) {
      return tz.getLocation('UTC');
    }
  }

  Future<void> _loadInitialData(int id) async {
    try {
      final slots = await services.fetchEventSlotDetails(id);
      tz.initializeTimeZones();

      // Grouped by the slot's day in the event timezone — the same day the
      // slot's `date` field holds on the server.
      final grouped = <DateTime, List<EventSlotModel>>{};
      for (final slot in slots) {
        final from = tz.TZDateTime.from(
          slot.startDatetime.toUtc(),
          _location(slot.dateTz),
        );
        final dayKey = DateTime(from.year, from.month, from.day);
        grouped.putIfAbsent(dayKey, () => []).add(slot);
      }

      if (!mounted) return;
      setState(() {
        _events = grouped;
        initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(context, cleanedError(e.toString()));
      setState(() {
        initialLoading = false;
      });
    }
  }

  /// Checks the two event.slot constraints (_check_hours and
  /// _check_time_range) before the create call, so the user gets a readable
  /// message instead of a raw ValidationError. Returns null when valid.
  String? _slotError(DateTimeRange range, TimeOfDay from, TimeOfDay to) {
    final start = timeToDouble(from);
    final end = timeToDouble(to);
    if (end <= start) {
      return "The end time must be later than the start time.";
    }

    final eventStart = widget.fromDate;
    final eventEnd = widget.toDate;
    if (eventStart == null || eventEnd == null) return null;

    // widget.fromDate / toDate are already in the event timezone, and slot
    // hours are expressed in that timezone too, so wall-clock values compare
    // directly.
    DateTime wall(DateTime d) =>
        DateTime(d.year, d.month, d.day, d.hour, d.minute);
    final firstSlotStart = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
      from.hour,
      from.minute,
    );
    final lastSlotEnd = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      to.hour,
      to.minute,
    );
    if (firstSlotStart.isBefore(wall(eventStart)) ||
        lastSlotEnd.isAfter(wall(eventEnd))) {
      final fmt = DateFormat("d MMM yyyy, h:mm a");
      return "Slots must be within the event time range "
          "(${fmt.format(eventStart)} – ${fmt.format(eventEnd)}).";
    }
    return null;
  }

  /// Slots are saved as soon as they are created, so leaving this screen has
  /// nothing to discard. From Details just pop — it reads the provider this
  /// screen refreshes, so the slot count is already up to date. The forms
  /// replaced themselves with this screen, so rebuild a fresh edit form.
  void _backToEdit() {
    if (!widget.returnToEdit) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const EventEditScreen()),
    );
  }

  Future<void> _deleteSlot(EventSlotModel slot) async {
    final confirm = await CommonDialog.confirm(
      context,
      title: 'Delete Slot',
      message:
          'Are you sure you want to delete the slot "${slot.displayName}"?',
      confirmText: 'Delete',
    );
    if (confirm != true || !mounted) return;

    final provider = Provider.of<EventDetailedProvider>(context, listen: false);
    try {
      loadingDialog(
        context,
        "Deleting Slot",
        "Please wait while we delete the slot",
        LoadingAnimationWidget.fourRotatingDots(color: primaryColor, size: 30),
      );
      // Odoo refuses to unlink a slot that still has registrations
      // (_unlink_except_if_registrations); that message is shown as-is.
      await services.deleteSlot(slot.id);
      await _loadInitialData(widget.eventId);
      await provider.fetchEventDetails(widget.eventId);
      if (!mounted) return;
      hideLoadingDialog(context);
      CustomSnackbar.showSuccess(context, "Slot deleted");
    } catch (e) {
      if (!mounted) return;
      hideLoadingDialog(context);
      CustomSnackbar.showError(context, cleanedError(e.toString()));
    }
  }

  /// TableCalendar asserts focusedDay is inside `[firstDay, lastDay]`; a fixed
  /// 2020–2030 window broke on events outside it.
  DateTime get _calendarFirstDay =>
      DateTime((widget.fromDate ?? DateTime.now()).year - 1, 1, 1);
  DateTime get _calendarLastDay =>
      DateTime((widget.toDate ?? DateTime.now()).year + 1, 12, 31);
  DateTime _clampToCalendar(DateTime day) {
    if (day.isBefore(_calendarFirstDay)) return _calendarFirstDay;
    if (day.isAfter(_calendarLastDay)) return _calendarLastDay;
    return day;
  }

  bool _isDayActive(DateTime day) {
    if (widget.fromDate == null || widget.toDate == null) return true;
    final start = DateTime(
      widget.fromDate!.year,
      widget.fromDate!.month,
      widget.fromDate!.day,
    );
    final end = DateTime(
      widget.toDate!.year,
      widget.toDate!.month,
      widget.toDate!.day,
    );
    final current = DateTime(day.year, day.month, day.day);
    return !current.isBefore(start) && !current.isAfter(end);
  }

  double timeToDouble(TimeOfDay time) {
    return time.hour + (time.minute / 60.0);
  }

  String _dmy(DateTime d) => "${d.day}/${d.month}/${d.year}";

  /// Read-only picker field in the create form's date-field recipe (filled,
  /// radius 12, leading icon, field value/hint styles), a touch taller
  /// (~54px) so it reads as a proper input inside the dialog.
  Widget _pickerField({
    required List<List<dynamic>> icon,
    required String? value,
    required String hint,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            decoration: BoxDecoration(
              color: AppTheme.inputFill(isDark),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                HugeIcon(
                  icon: icon,
                  size: 20,
                  color: isDark ? Colors.white : Colors.grey[700],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value ?? hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: value == null
                        ? AppTheme.fieldHintStyle(isDark)
                        : AppTheme.fieldValueStyle(isDark),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<TimeOfDay?> _pickTime(BuildContext context, TimeOfDay initial) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        final baseTheme = Theme.of(context);
        return Theme(
          data: baseTheme.copyWith(
            colorScheme: baseTheme.colorScheme.copyWith(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: AppTheme.surface(isDark),
              onSurface: isDark ? Colors.white : Colors.black87,
            ),
            timePickerTheme: AppTheme.timePickerTheme(isDark),
            textSelectionTheme: AppTheme.timePickerTextSelection,
          ),
          child: child!,
        );
      },
    );
  }

  void _addEventDialog() {
    DateTimeRange? selectedRange;
    TimeOfDay? fromTime;
    TimeOfDay? toTime;
    // Server-side failure from the last save attempt; cleared on any edit.
    String? saveError;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogContext) {
        // A phone on its side has ~300dp, so the dialog gives up some of its
        // breathing room: the title, fields and buttons then fit with at most
        // a short scroll in the fields.
        final compact = dialogContext.isShortScreen;
        return Dialog(
          backgroundColor: AppTheme.surface(isDark),
          elevation: 0,
          insetPadding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: compact ? 8 : 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              // Messages are shown inline: a SnackBar belongs to the page's
              // Scaffold, which sits underneath this dialog's barrier.
              final isFilled =
                  selectedRange != null && fromTime != null && toTime != null;
              final inputError = isFilled
                  ? _slotError(selectedRange!, fromTime!, toTime!)
                  : null;
              final errorText = inputError ?? saveError;
              final canSave = isFilled && inputError == null;
              // Title and Cancel/Save stay put; only the fields in between
              // scroll. When even those leave no room (the keyboard up on a
              // phone on its side) everything scrolls as one page instead.
              return PinnedFooterLayout(
                scrollAllBelow: 200,
                crossAxisAlignment: CrossAxisAlignment.start,
                header: Padding(
                  padding: EdgeInsets.fromLTRB(24, compact ? 6 : 16, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Add Event Slot",
                          style: TextStyle(
                            color: AppTheme.textPrimaryOn(isDark),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          size: 22,
                          color: AppTheme.textPrimaryOn(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                body: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: compact ? 4 : 12),
                      const FieldLabel("Date Range", isRequired: true),
                      const SizedBox(height: 10),
                      _pickerField(
                        icon: HugeIcons.strokeRoundedCalendar03,
                        value: selectedRange == null
                            ? null
                            : "${_dmy(selectedRange!.start)} → ${_dmy(selectedRange!.end)}",
                        hint: "Select date range",
                        onTap: () async {
                          final range = await _showRangeCalendarPopup(
                            initialRange: selectedRange,
                          );
                          if (range != null) {
                            setStateDialog(() {
                              selectedRange = range;
                              saveError = null;
                            });
                          }
                        },
                      ),
                      SizedBox(height: compact ? 12 : 20),
                      const FieldLabel("Time Range", isRequired: true),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _pickerField(
                              icon: HugeIcons.strokeRoundedClock01,
                              value: fromTime?.format(context),
                              hint: "From",
                              onTap: () async {
                                final time = await _pickTime(
                                  context,
                                  fromTime ?? TimeOfDay.now(),
                                );
                                if (time != null) {
                                  setStateDialog(() {
                                    fromTime = time;
                                    saveError = null;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _pickerField(
                              icon: HugeIcons.strokeRoundedClock01,
                              value: toTime?.format(context),
                              hint: "To",
                              onTap: () async {
                                final time = await _pickTime(
                                  context,
                                  toTime ?? fromTime ?? TimeOfDay.now(),
                                );
                                if (time != null) {
                                  setStateDialog(() {
                                    toTime = time;
                                    saveError = null;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: errorText == null
                            ? const SizedBox.shrink()
                            : Padding(
                                key: ValueKey(errorText),
                                padding: const EdgeInsets.only(top: 8, left: 4),
                                child: Text(
                                  errorText,
                                  style: const TextStyle(
                                    color: StatusColors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                footer: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    compact ? 12 : 28,
                    24,
                    compact ? 16 : 24,
                  ),
                  child: MoboButtonRow(
                    secondaryLabel: "Cancel",
                    onSecondary: () => Navigator.pop(context),
                    primaryLabel: "Save",
                    onPrimary: !canSave
                        ? null
                        : () async {
                            final detailProvider =
                                Provider.of<EventDetailedProvider>(
                                  context,
                                  listen: false,
                                );

                            // One slot per day. Only the stored inputs
                            // are sent: start/end_datetime are computed
                            // on the server from date + hours in the
                            // event timezone (_compute_datetimes).
                            DateTime current = selectedRange!.start;
                            final List<Map<String, dynamic>> slots = [];
                            while (!current.isAfter(selectedRange!.end)) {
                              slots.add({
                                "event_id": widget.eventId,
                                "date": DateFormat(
                                  "yyyy-MM-dd",
                                ).format(current),
                                "start_hour": timeToDouble(fromTime!),
                                "end_hour": timeToDouble(toTime!),
                              });
                              current = DateTime(
                                current.year,
                                current.month,
                                current.day + 1,
                              );
                            }

                            final dialogNavigator = Navigator.of(context);
                            try {
                              loadingDialog(
                                context,
                                "Creating Event Slot",
                                "Please wait while we create the slots",
                                LoadingAnimationWidget.fourRotatingDots(
                                  color: primaryColor,
                                  size: 30,
                                ),
                              );

                              await services.createEventSlots(slots);
                              await _loadInitialData(widget.eventId);
                              await detailProvider.fetchEventDetails(
                                widget.eventId,
                              );
                              if (!mounted) return;
                              hideLoadingDialog(this.context);
                              dialogNavigator.pop();

                              // Stay here so the new slots show on the
                              // calendar and more can be added.
                              setState(() {
                                _selectedDay = selectedRange!.start;
                                _focusedDay = selectedRange!.start;
                              });
                              CustomSnackbar.showSuccess(
                                this.context,
                                slots.length == 1
                                    ? "Slot created"
                                    : "${slots.length} slots created",
                              );
                            } catch (e) {
                              if (!mounted) return;
                              hideLoadingDialog(this.context);
                              // The add dialog is still open, so show
                              // the failure inside it.
                              setStateDialog(
                                () => saveError = cleanedError(e.toString()),
                              );
                            }
                          },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// The grid card: month row, day-name strip and the month itself.
  ///
  /// [compact] / [rowHeight] are the landscape version: tighter rows, sized by
  /// the caller to the height the pane has.
  Widget _calendarCard(
    bool isDark, {
    double rowHeight = 52,
    bool compact = false,
  }) {
    // The selected-day ring: 40dp, or a little under the row when that is
    // shorter than 44.
    final ring = math.min(40.0, rowHeight - 4);
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 0 : 20),
      decoration: BoxDecoration(
        color: AppTheme.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [AppShadows.cardShadow],
      ),
      child: Column(
        children: [
          _monthNav(
            isDark: isDark,
            compact: compact,
            label: DateFormat("MMMM yyyy").format(_focusedDay),
            onPrev: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
              });
            },
            onNext: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
              });
            },
          ),
          _weekdayStrip(isDark, compact: compact),

          TableCalendar<EventSlotModel>(
            headerVisible: false,
            rowHeight: rowHeight,
            // Month swipes only. The default also claims vertical drags (a
            // format swipe, which does nothing here since no format
            // callback is set), and that would stop a finger on the grid
            // from scrolling the landscape page it sits in.
            availableGestures: AvailableGestures.horizontalSwipe,

            firstDay: _calendarFirstDay,
            lastDay: _calendarLastDay,
            focusedDay: _clampToCalendar(_focusedDay),

            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),

            eventLoader: _getEventsForDay,

            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            daysOfWeekVisible: false,

            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              isTodayHighlighted: false,
              // The slot marker is placed from the cell's margin, so a short
              // row needs a thin one to keep the dot clear of the day number.
              cellMargin: EdgeInsets.all(compact ? 2 : 6),
              markerDecoration: const BoxDecoration(
                color: StatusColors.green,
                shape: BoxShape.circle,
              ),

              markerSize: 6,
            ),

            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final isActive = _isDayActive(day);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${day.day}",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark
                                  ? Colors.grey[600]
                                  : Colors.grey.shade400),
                      ),
                    ),
                  ],
                );
              },

              todayBuilder: (context, day, focusedDay) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? primaryColor.withValues(alpha: 0.18)
                        : const Color(0xFFF6DCDC),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "${day.day}",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                );
              },

              selectedBuilder: (context, day, focusedDay) {
                final isActive = _isDayActive(day);

                return Container(
                  height: ring,
                  width: ring,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "${day.day}",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? (isDark ? Colors.white : Colors.black)
                          : Colors.grey,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// One slot of the selected day.
  Widget _slotTile(BuildContext context, EventSlotModel event, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
      decoration: BoxDecoration(
        color: AppTheme.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
          width: 0.5,
        ),
        boxShadow: const [AppShadows.cardShadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const HugeIcon(icon: HugeIcons.strokeRoundedCalendar03),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.seatsTaken == 1
                      ? "1 attendee"
                      : "${event.seatsTaken} attendees",
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.secondaryLabelColor(isDark),
                  ),
                ),
              ],
            ),
          ),

          // Deleting a slot is an unlink on `event.slot`.
          if (context.watch<AccessRights>().canDeleteSlot)
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              position: PopupMenuPosition.under,
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: isDark ? Colors.white : Colors.black,
              ),
              onSelected: (value) {
                if (value == 'delete') _deleteSlot(event);
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: StatusColors.red),
                      SizedBox(width: 10),
                      Text('Delete', style: TextStyle(color: StatusColors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _slotList(List<EventSlotModel> events, bool isDark) {
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) =>
          _slotTile(context, events[index], isDark),
    );
  }

  /// Landscape: the same page as upright — month grid, then the selected
  /// day's slots — as one column that scrolls as a whole and is capped to a
  /// readable width, so a phone on its side doesn't need ~600dp of height to
  /// show the grid and the list at once. The grid gets shorter rows and a
  /// compact header to leave room for the slots.
  Widget _landscapeBody(bool isDark, List<EventSlotModel> events) {
    return ListView.builder(
      // The bottom clears the add button.
      padding: const EdgeInsets.only(top: 10, bottom: 80),
      itemCount: events.length + 1,
      itemBuilder: (context, index) => ConstrainedContent(
        maxWidth: 600,
        child: index == 0
            ? Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _calendarCard(isDark, rowHeight: 40, compact: true),
              )
            : _slotTile(context, events[index - 1], isDark),
      ),
    );
  }

  Widget _loadingBody({required bool landscape}) {
    return SingleChildScrollView(
      child: ConstrainedContent(
        maxWidth: landscape ? 600 : double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              FullCardShimmer(height: 300),
              SizedBox(height: 10),
              FullCardShimmer(height: 200),
              SizedBox(height: 10),
              FullCardShimmer(height: 100),
              SizedBox(height: 10),
              FullCardShimmer(height: 100),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = _selectedDay == null
        ? <EventSlotModel>[]
        : _getEventsForDay(_selectedDay!);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final landscape = context.isLandscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _backToEdit();
      },

      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Event Calendar",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: GestureDetector(
            onTap: _backToEdit,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
        // Adding a slot is a create on `event.slot` (Odoo 19+).
        floatingActionButton: context.watch<AccessRights>().canAddSlot
            ? FloatingActionButton(
                backgroundColor: primaryColor,
                onPressed: _addEventDialog,
                child: const Icon(Icons.add, color: Colors.white),
              )
            : null,
        // Side insets keep the content clear of a display cutout when the
        // phone is on its side; they are zero upright.
        body: SafeArea(
          top: false,
          bottom: false,
          child: initialLoading
              ? _loadingBody(landscape: landscape)
              : landscape
              ? _landscapeBody(isDark, events)
              : Column(
                  children: [
                    SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _calendarCard(isDark),
                    ),

                    const SizedBox(height: 10),
                    Expanded(child: _slotList(events, isDark)),
                  ],
                ),
        ),
      ),
    );
  }

  /// To Odoo Date Time
  String toOdooDateTime(DateTime dt) {
    final utc = dt.toUtc();
    return "${utc.year.toString().padLeft(4, '0')}-"
        "${utc.month.toString().padLeft(2, '0')}-"
        "${utc.day.toString().padLeft(2, '0')} "
        "${utc.hour.toString().padLeft(2, '0')}:"
        "${utc.minute.toString().padLeft(2, '0')}:"
        "${utc.second.toString().padLeft(2, '0')}";
  }
}
