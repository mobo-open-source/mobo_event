import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/features/event/model/event_slot.dart';
import 'package:mobo_event/features/event/pages/event_edit_screen.dart';
import 'package:mobo_event/features/event/services/event_detailed_services.dart';
import 'package:mobo_event/shared/helper/helper_method.dart';
import 'package:mobo_event/shared/widgets/shimmer_card/shimmer_card.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:timezone/data/latest.dart' as tz;

import '../../../shared/widgets/back_dialog/show_back_dialog.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../provider/event_detailed_provider.dart';
import 'package:timezone/standalone.dart' as tz;

class CalendarScreen extends StatefulWidget {
  final int eventId;
  final DateTime? fromDate;
  final DateTime? toDate;
  const CalendarScreen({
    super.key,
    this.fromDate,
    this.toDate,
    required this.eventId,
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
            bool isInRange(DateTime day) {
              if (rangeStart == null || rangeEnd == null) return false;
              final current = DateTime(day.year, day.month, day.day);
              final start = DateTime(
                rangeStart!.year,
                rangeStart!.month,
                rangeStart!.day,
              );
              final end = DateTime(
                rangeEnd!.year,
                rangeEnd!.month,
                rangeEnd!.day,
              );
              return !current.isBefore(start) && !current.isAfter(end);
            }

            bool isSameRangeStart(DateTime day) =>
                rangeStart != null && isSameDay(day, rangeStart);

            bool isSameRangeEnd(DateTime day) =>
                rangeEnd != null && isSameDay(day, rangeEnd);

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F3F5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () {
                                setPopupState(() {
                                  final prev = DateTime(
                                    focusedDay.year,
                                    focusedDay.month - 1,
                                  );

                                  if (prev.year > firstDay.year ||
                                      (prev.year == firstDay.year &&
                                          prev.month >= firstDay.month)) {
                                    focusedDay = prev;
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F3F5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                DateFormat("MMMM yyyy").format(focusedDay),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F3F5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () {
                                ;
                                setPopupState(() {
                                  final next = DateTime(
                                    focusedDay.year,
                                    focusedDay.month + 1,
                                  );

                                  if (!next.isAfter(lastDay)) {
                                    focusedDay = next;
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (rangeStart != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            /// FROM DATE
                            Column(
                              children: [
                                Text(
                                  "FROM",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  rangeStart == null
                                      ? "--"
                                      : DateFormat(
                                          "MMM dd",
                                        ).format(rangeStart!),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(width: 15),

                            Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),

                            const SizedBox(width: 15),

                            /// TO DATE
                            Column(
                              children: [
                                Text(
                                  "TO",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  rangeEnd == null
                                      ? "--"
                                      : DateFormat("MMM dd").format(rangeEnd!),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F3F5),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                            "SUN",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "MON",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "TUE",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "WED",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "THU",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "FRI",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "SAT",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 320,
                      child: TableCalendar(
                        headerVisible: false,
                        firstDay: firstDay,
                        lastDay: lastDay,
                        focusedDay: focusedDay.isAfter(lastDay)
                            ? lastDay
                            : focusedDay.isBefore(firstDay)
                            ? firstDay
                            : focusedDay,
                        daysOfWeekVisible: false,
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
                        calendarStyle: CalendarStyle(
                          outsideDaysVisible: false,
                          isTodayHighlighted: false,

                          rangeHighlightColor: primaryColor.withOpacity(0.15),

                          rangeStartDecoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),

                          rangeEndDecoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),

                          selectedDecoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),

                          selectedTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),

                          withinRangeTextStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),

                          defaultTextStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, _) {
                            final disabled =
                                day.isBefore(firstDay) && day.isAfter(lastDay);
                            final inRange = isInRange(day);
                            final start = isSameRangeStart(day);
                            final end = isSameRangeEnd(day);

                            return Container(
                              margin: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: inRange && !start && !end
                                    ? primaryColor.withOpacity(0.12)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: start || end
                                    ? Border.all(color: primaryColor, width: 2)
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "${day.day}",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: disabled
                                      ? Colors.grey.shade400
                                      : Colors.black,
                                ),
                              ),
                            );
                          },
                          todayBuilder: (context, day, _) {
                            final start = isSameRangeStart(day);
                            final end = isSameRangeEnd(day);
                            final inRange = isInRange(day);

                            return Container(
                              margin: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: start || end
                                    ? Colors.transparent
                                    : inRange
                                    ? primaryColor.withOpacity(0.12)
                                    : const Color(0xFFF6DCDC),
                                shape: BoxShape.circle,
                                border: start || end
                                    ? Border.all(color: primaryColor, width: 2)
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "${day.day}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
                          selectedBuilder: (context, day, _) {
                            final start = isSameRangeStart(day);
                            final end = isSameRangeEnd(day);

                            return Container(
                              margin: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primaryColor,
                                  width: 2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "${day.day}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.all(12),
                              side: BorderSide(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(12),
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              if (rangeStart != null && rangeEnd != null) {
                                Navigator.pop(
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
                                );
                              }
                            },
                            child: const Text("Apply"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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

  _loadInitialData(int id) async {
    try {
      final selectedEvent = await services.fetchEventSlotDetails(id);
      tz.initializeTimeZones();

      if (selectedEvent.isEmpty) {
        _events = {};
        setState(() {
          initialLoading = false;
        });
        return;
      }

      setState(() {
        _events.clear();

        for (var slot in selectedEvent) {
          var location = tz.getLocation(slot.dateTz);

          final utcStart = slot.startDatetime.toUtc();
          final utcEnd = slot.endDatetime.toUtc();

          final from = tz.TZDateTime.from(utcStart, location);
          final to = tz.TZDateTime.from(utcEnd, location);

          final dayKey = DateTime(from.year, from.month, from.day);

          final event = slot;

          _events.putIfAbsent(dayKey, () => []);

          _events[dayKey]!.add(event);
        }

        initialLoading = false;
      });
    } catch (e) {
      final message = cleanedError(e.toString());
      CustomSnackbar.showError(context, message);
      setState(() {
        initialLoading = false;
      });
    }
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

  void _addEventDialog() {
    DateTimeRange? selectedRange;
    TimeOfDay? fromTime;
    TimeOfDay? toTime;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: StatefulBuilder(
          builder: (context, setStateDialog) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withAlpha(30),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(16),
                        topLeft: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Add Event Slot",
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            size: 18,
                          ),
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(6),
                            minimumSize: const Size(32, 32),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedCalendar02,
                              size: 17,
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Date Range",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () async {
                            final range = await _showRangeCalendarPopup(
                              initialRange: selectedRange,
                            );

                            if (range != null) {
                              setStateDialog(() => selectedRange = range);
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              selectedRange == null
                                  ? "Select From–To Date"
                                  : "${selectedRange!.start.day}/${selectedRange!.start.month}/${selectedRange!.start.year}"
                                        " → "
                                        "${selectedRange!.end.day}/${selectedRange!.end.month}/${selectedRange!.end.year}",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Row(
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedClock01,
                              size: 17,
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Time Range",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                    builder: (context, child) {
                                      final baseTheme = Theme.of(context);

                                      return Theme(
                                        data: baseTheme.copyWith(
                                          colorScheme: baseTheme.colorScheme
                                              .copyWith(
                                                primary: primaryColor,
                                                onPrimary: Colors.white,
                                                surface: Colors.white,
                                                onSurface: Colors.black87,
                                              ),
                                          timePickerTheme: TimePickerThemeData(
                                            backgroundColor: Colors.white,
                                            hourMinuteTextColor: Colors.white,
                                            hourMinuteColor: primaryColor,
                                            dialHandColor: primaryColor,
                                            dialBackgroundColor: primaryColor
                                                .withOpacity(0.1),
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );

                                  if (time != null) {
                                    setStateDialog(() => fromTime = time);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: backgroundColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    fromTime == null
                                        ? "From"
                                        : fromTime!.format(context),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: fromTime ?? TimeOfDay.now(),
                                    builder: (context, child) {
                                      final baseTheme = Theme.of(context);
                                      return Theme(
                                        data: baseTheme.copyWith(
                                          colorScheme: baseTheme.colorScheme
                                              .copyWith(
                                                primary: primaryColor,
                                                onPrimary: Colors.white,
                                                surface: Colors.white,
                                                onSurface: Colors.black87,
                                              ),
                                          timePickerTheme: TimePickerThemeData(
                                            backgroundColor: Colors.white,
                                            hourMinuteTextColor: Colors.white,
                                            hourMinuteColor: primaryColor,
                                            dialHandColor: primaryColor,
                                            dialBackgroundColor: primaryColor
                                                .withOpacity(0.1),
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (time != null) {
                                    setStateDialog(() => toTime = time);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: backgroundColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    toTime == null
                                        ? "To"
                                        : toTime!.format(context),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.all(12),
                                  side: BorderSide(
                                    color: primaryColor,
                                    width: 1,
                                  ),
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(color: primaryColor),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.all(12),
                                  backgroundColor: primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () async {
                                  if (selectedRange == null ||
                                      fromTime == null ||
                                      toTime == null) {
                                    Navigator.pop(context);
                                    CustomSnackbar.showWarning(
                                      context,
                                      "Please select all the required field",
                                    );

                                    return;
                                  }

                                  final detailProvider =
                                      Provider.of<EventDetailedProvider>(
                                        context,
                                        listen: false,
                                      );

                                  DateTime current = selectedRange!.start;
                                  DateTime todate = selectedRange!.end;
                                  List<Map<String, dynamic>> slots = [];

                                  while (!current.isAfter(selectedRange!.end)) {
                                    final fromDateTime = DateTime(
                                      current.year,
                                      current.month,
                                      current.day,
                                      fromTime!.hour,
                                      fromTime!.minute,
                                    );

                                    final toDateTime = DateTime(
                                      current.year,
                                      current.month,
                                      current.day,
                                      toTime!.hour,
                                      toTime!.minute,
                                    );

                                    slots.add({
                                      "start_datetime": DateFormat(
                                        "yyyy-MM-dd HH:mm:ss",
                                      ).format(fromDateTime),
                                      "end_datetime": DateFormat(
                                        "yyyy-MM-dd HH:mm:ss",
                                      ).format(toDateTime),
                                      "date": DateFormat(
                                        "yyyy-MM-dd",
                                      ).format(current),
                                      "start_hour": timeToDouble(fromTime!),
                                      "end_hour": timeToDouble(toTime!),
                                      "event_id": widget.eventId,
                                      "color": 0,
                                    });

                                    current = current.add(
                                      const Duration(days: 1),
                                    );
                                  }

                                  try {
                                    loadingDialog(
                                      context,
                                      "Creating Event Slot",
                                      "Please wait while we Create Event slot",
                                      LoadingAnimationWidget.fourRotatingDots(
                                        color: primaryColor,
                                        size: 30,
                                      ),
                                    );

                                    await services.createEventSlots(slots);
                                    await detailProvider.fetchEventDetails(
                                      widget.eventId,
                                    );
                                    hideLoadingDialog(context);

                                    CustomSnackbar.showSuccess(
                                      context,
                                      "Created Successfully",
                                    );

                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EventEditScreen(),
                                      ),
                                    );
                                  } catch (e) {
                                    final message = cleanedError(e.toString());
                                    hideLoadingDialog(context);
                                    Navigator.pop(context);

                                    CustomSnackbar.showError(context, message);
                                  }
                                },

                                child: const Text("Save"),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        bool confirm = await showBackDialog(
          context,
          title: 'Discard event slot',
          subtitle:
              "You have unsaved Event slot data that will be lost if you leave this page.Are you sure you want to discard this page?",
          leftButtonName: "Stay",
          rightButtonName: "Go to Edit",
          function: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => EventEditScreen()),
            );
          },
        );
      },

      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Event Calender",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: GestureDetector(
            onTap: () async {
              bool confirm = await showBackDialog(
                context,
                title: 'Discard event slot',
                subtitle:
                    "You have unsaved Event slot data that will be lost if you leave this page.Are you sure you want to discard this page?",
                leftButtonName: "Stay",
                rightButtonName: "Leave",
                function: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => EventEditScreen()),
                  );
                },
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: primaryColor,
          onPressed: _addEventDialog,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: initialLoading
            ? SingleChildScrollView(
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
              )
            : Column(
                children: [
                  SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 6),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),

                            child: Row(
                              children: [
                                /// LEFT BUTTON
                                Container(
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF3F3F5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.chevron_left),
                                    onPressed: () {
                                      setState(() {
                                        _focusedDay = DateTime(
                                          _focusedDay.year,
                                          _focusedDay.month - 1,
                                        );
                                      });
                                    },
                                  ),
                                ),

                                const SizedBox(width: 10),

                                /// MONTH CONTAINER
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF3F3F5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      DateFormat(
                                        "MMMM yyyy",
                                      ).format(_focusedDay),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                /// RIGHT BUTTON
                                Container(
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF3F3F5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed: () {
                                      setState(() {
                                        _focusedDay = DateTime(
                                          _focusedDay.year,
                                          _focusedDay.month + 1,
                                        );
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Color(0xFFF3F3F5),
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Text(
                                  "SUN",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  "MON",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  "TUE",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  "WED",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  "THU",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  "FRI",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  "SAT",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          TableCalendar<EventSlotModel>(
                            headerVisible: false,

                            firstDay: DateTime(2020),
                            lastDay: DateTime(2030),
                            focusedDay: _focusedDay,

                            selectedDayPredicate: (day) =>
                                isSameDay(_selectedDay, day),

                            eventLoader: _getEventsForDay,

                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            daysOfWeekVisible: false,

                            calendarStyle: const CalendarStyle(
                              outsideDaysVisible: false,
                              isTodayHighlighted: false,
                              markerDecoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),

                              markerSize: 6,
                            ),

                            calendarBuilders: CalendarBuilders(
                              defaultBuilder: (context, day, focusedDay) {
                                final events = _getEventsForDay(day);
                                final hasSlot = events.isNotEmpty;
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
                                            ? Colors.black
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                );
                              },

                              /// Today
                              todayBuilder: (context, day, focusedDay) {
                                return Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF6DCDC),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "${day.day}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },

                              /// Selected day
                              selectedBuilder: (context, day, focusedDay) {
                                final isActive = _isDayActive(day);

                                return Container(
                                  height: 40,
                                  width: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.blue,
                                      width: 2,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "${day.day}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isActive
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const HugeIcon(
                                icon: HugeIcons.strokeRoundedCalendar02,
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Text(
                                  event.displayName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.more_vert,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                onSelected: (value) async {
                                  if (value == 'delete') {
                                    try {
                                      loadingDialog(
                                        context,
                                        "Updating Event",
                                        "Please wait while we Updating Event",
                                        LoadingAnimationWidget.fourRotatingDots(
                                          color: primaryColor,
                                          size: 30,
                                        ),
                                      );

                                      final result = await services.deleteSlot(
                                        event.id,
                                      );
                                      if (result) {
                                        _loadInitialData(widget.eventId);
                                        final provider =
                                            Provider.of<EventDetailedProvider>(
                                              context,
                                              listen: false,
                                            );

                                        await provider.fetchEventDetails(
                                          widget.eventId,
                                        );

                                        hideLoadingDialog(context);
                                        CustomSnackbar.showSuccess(
                                          context,
                                          "slot is Deleted",
                                        );
                                        return;
                                      }
                                      CustomSnackbar.showError(
                                        context,
                                        "some error occured",
                                      );
                                    } catch (e) {
                                      final message = cleanedError(
                                        e.toString(),
                                      );
                                      Navigator.pop(context);
                                      CustomSnackbar.showError(
                                        context,
                                        message,
                                      );
                                    }
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 10),
                                        Text('Delete'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

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
