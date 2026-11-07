import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/app/home_scaffold.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/core/services/event_access_rights.dart';
import 'package:mobo_event/features/questions/providers/questions_provider.dart';
import 'package:mobo_event/features/scheduler/provider/mail_scheduler_provider.dart';
import 'package:mobo_event/shared/helper/helper_method.dart';
import 'package:mobo_event/shared/widgets/errors/universal_error_widget.dart';
import 'package:mobo_event/shared/widgets/shimmer_card/shimmer_card.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../home/providers/home_provider.dart';
import '../../registration/page/event_attendees_page.dart';
import '../../registration/page/registration_page.dart';
import '../provider/event_detailed_provider.dart';
import '../widget/event_add_line.dart';
import '../widget/event_main_card.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/standalone.dart' as tz;
import '../model/event_detailed_model.dart';
import '../widget/event_calender.dart';
import 'event_edit_screen.dart';

/// [HugeIcons.strokeRoundedAddTeam] — the two people — with its trailing "+"
/// path dropped, so the attendee count beside it uses the very same figures
/// as the "Add Attendee" floating button elsewhere in the app, just without
/// the add badge. Not in the hugeicons package as its own icon.
const List<List<dynamic>> _teamIconNoPlus = [
  [
    'path',
    {
      'key': '0',
      'd':
          'M12 7.5C12 9.433 10.433 11 8.5 11C6.567 11 5 9.433 5 7.5C5 5.567 6.567 4 8.5 4C10.433 4 12 5.567 12 7.5Z',
      'stroke': 'currentColor',
      'strokeWidth': '1.5',
    },
  ],
  [
    'path',
    {
      'key': '1',
      'd': 'M13.5 11C15.433 11 17 9.433 17 7.5C17 5.567 15.433 4 13.5 4',
      'stroke': 'currentColor',
      'strokeWidth': '1.5',
      'strokeLinecap': 'round',
    },
  ],
  [
    'path',
    {
      'key': '2',
      'd':
          'M13.1429 20H3.85714C2.83147 20 2 19.2325 2 18.2857C2 15.9188 4.07868 14 6.64286 14H10.3571C11.4023 14 12.3669 14.3188 13.1429 14.8568',
      'stroke': 'currentColor',
      'strokeWidth': '1.5',
      'strokeLinecap': 'round',
      'strokeLinejoin': 'round',
    },
  ],
];

class EventDetailsScreen extends StatefulWidget {
  final int id;

  /// Reloads Home's event list in the background once this screen opens. Set
  /// by [openFresh], whose callers have just created or changed the event, so
  /// the list behind this screen is out of date; a plain open from a Home card
  /// has just read it and leaves it alone.
  final bool refreshHome;

  const EventDetailsScreen({
    super.key,
    required this.id,
    this.refreshHome = false,
  });

  /// Shows a freshly loaded Details screen directly above Home, dropping
  /// whatever event screens (edit, calendar, create) were in between. Every
  /// "done with this event form" path uses it, so back from Details always
  /// lands on Home and no stale or duplicate Details screens pile up.
  static void openFresh(BuildContext context, int id) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => EventDetailsScreen(id: id, refreshHome: true),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  /// Why the event itself could not be loaded, while it is still missing.
  /// Null the rest of the time — a tab that fails to load only gets a message.
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    // The providers notify, which is not allowed while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.refreshHome) {
        // Background only: nothing on this screen waits for Home's list.
        unawaited(context.read<HomeProvider>().loadEvents().catchError((_) {}));
      }
      _load();
    });
  }

  /// The event the providers hold is this screen's event, and it is in.
  bool _isReady(EventDetailedProvider provider) =>
      !provider.isLoading && provider.eventModel?.id == widget.id;

  /// Loads everything this screen shows in one go: the event with its tickets,
  /// the scheduled mails and the questions are all requested at once, and the
  /// screen opens as soon as the event is in while the tabs fill in behind it.
  ///
  /// Home has already loaded the field lists, the stages and the access rights
  /// this screen depends on, so nothing here reloads them.
  Future<void> _load() async {
    final detail = context.read<EventDetailedProvider>();
    final mails = context.read<MailSchedulerProvider>();
    final questions = context.read<QuestionsProvider>();
    final id = widget.id;

    if (_loadError != null) setState(() => _loadError = null);

    // These providers outlive the screen and still hold the last event's
    // rows; empty them so none of those show here.
    detail.reset();
    mails.reset();
    questions.clear();

    // Each request reports its own failure instead of throwing, so one failing
    // never leaves the others unhandled, and the event's is listed first.
    Future<Object?> attempt(Future<void> request) =>
        request.then<Object?>((_) => null, onError: (Object e) => e);

    final failures = await Future.wait<Object?>([
      attempt(detail.fetchEventDetails(id)),
      attempt(mails.fetchScheduledMail(id)),
      attempt(questions.fetchQuestions(id)),
      // Only a cold start finds these missing, and nothing here waits on
      // them or reports them: the edit form asks again if it still needs them.
      if (detail.eventFields.isEmpty)
        attempt(detail.loadFields().catchError((_) {})),
    ]);

    if (!mounted) return;
    unawaited(_warmQuestionPicker(questions));
    final failure = failures.firstWhere((e) => e != null, orElse: () => null);
    if (failure == null) return;
    if (detail.eventModel?.id != id) {
      // No event to show: the error takes the place of the loading skeleton.
      setState(() => _loadError = failure);
    } else {
      CustomSnackbar.showError(context, cleanedError(failure.toString()));
    }
  }

  /// Fetches the reusable questions the Add Question picker offers, now that the
  /// event's own questions are in, so the first tap on Add opens its dialog on
  /// the list instead of waiting for it. Silent: if this fails, the Add button
  /// fetches again and reports it then.
  Future<void> _warmQuestionPicker(QuestionsProvider questions) async {
    try {
      final compat = context.read<HomeProvider>().compat;
      if (!context.read<AccessRights>().canAddQuestion(compat)) return;
      await questions.fetchRemainingQuestions(
        questions.questionList.map((q) => q.id).toList(),
      );
    } catch (_) {}
  }

  /// Home is always the route below (see [EventDetailsScreen.openFresh]);
  /// the fallback only covers Details somehow being the root route.
  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (context) => HomeScaffold()),
      );
    }
  }

  /// Opens the slot calendar on top of this screen. The calendar compares
  /// slot hours against the event's bounds in the event timezone, the same
  /// conversion the edit form does before opening it.
  void _openSlots(EventDetailedModel event) {
    tz.initializeTimeZones();
    tz.Location location;
    try {
      location = tz.getLocation(event.timezone);
    } catch (_) {
      location = tz.getLocation('UTC');
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarScreen(
          eventId: event.id,
          fromDate: tz.TZDateTime.from(event.start.toUtc(), location),
          toDate: tz.TZDateTime.from(event.end.toUtc(), location),
          returnToEdit: false,
        ),
      ),
    );
  }

  /// Edit action; shown only once this event has loaded, since the edit
  /// form reads the event straight from the provider.
  Widget _editAction(bool isDark) {
    return Consumer<EventDetailedProvider>(
      builder: (context, provider, _) {
        final event = provider.eventModel;
        if (provider.isLoading || event == null || event.id != widget.id) {
          return const SizedBox.shrink();
        }
        // The edit form saves with a write on `event.event`; an account the
        // server won't let make one gets the read-only view.
        if (!context.watch<AccessRights>().canEditEvent) {
          return const SizedBox.shrink();
        }
        return IconButton(
          tooltip: 'Edit',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EventEditScreen()),
          ),
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedPencilEdit02,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        );
      },
    );
  }

  /// Slot calendar shortcut with the slot total, mirroring Odoo 19's
  /// "N Slot(s)" button, which shows only when `is_multi_slots` is set (the
  /// count is shown even at 0). Odoo 17/18 have no slots: the field is
  /// absent, parses to false, and the icon never appears.
  Widget _slotsAction() {
    return Consumer<EventDetailedProvider>(
      builder: (context, provider, _) {
        final event = provider.eventModel;
        if (provider.isLoading ||
            event == null ||
            event.id != widget.id ||
            !event.isMultiSlots) {
          return const SizedBox.shrink();
        }
        return IconButton(
          tooltip: 'Slots',
          onPressed: () => _openSlots(event),
          icon: Badge(
            label: Text(
              '${event.slotCount}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
            backgroundColor: primaryColor,
            textColor: Colors.white,
            // Brand-coloured, like the activity calendar on the Home cards.
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar03,
              size: 22,
              color: AppTheme.primaryColor,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goBack();
      },

      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : backgroundColor,

        appBar: AppBar(
          backgroundColor: isDark ? Colors.grey[900] : backgroundColor,
          leading: GestureDetector(
            onTap: _goBack,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          title: Text(
            "Event Details",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            _slotsAction(),
            _editAction(isDark),
            const SizedBox(width: 8),
          ],
        ),

        // Side insets keep the content clear of a display cutout when the
        // phone is on its side; they are zero upright.
        body: SafeArea(
          top: false,
          bottom: false,
          child: Consumer<EventDetailedProvider>(
            builder: (context, provider, child) {
              // The providers can still hold the previous event (or nothing
              // yet) on the first frame, so "loaded" means this event's.
              final ready = _isReady(provider);
              final error = _loadError;
              if (!ready && error != null) {
                return RefreshIndicator(
                  onRefresh: _load,
                  child: _failedView(error),
                );
              }
              if (context.isLandscape) {
                return _landscapeBody(context, provider, isDark, ready);
              }
              return RefreshIndicator(
                onRefresh: _load,

                child: !ready
                    ? ListView(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 20,
                        ),
                        children: const [
                          FullCardShimmer(height: 300),
                          SizedBox(height: 20),
                          FullCardShimmer(height: 400),
                          SizedBox(height: 80),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 20),
                        children: [
                          _attendeeRow(context, provider, isDark),
                          _summaryCard(provider),

                          EventAddLine(eventId: widget.id),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// The event could not be loaded. Fills the body and scrolls, so pulling
  /// down retries just as the button does.
  Widget _failedView(Object error) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: constraints.maxHeight,
            child: UniversalErrorWidget(error: error, onRetry: _load),
          ),
        ],
      ),
    );
  }

  /// Landscape: the event summary on the left, the tabs (tickets,
  /// communication, questions, notes) on the right in a pane of their own, so
  /// the tabs get the full window height instead of a slice of a tall column.
  Widget _landscapeBody(
    BuildContext context,
    EventDetailedProvider provider,
    bool isDark,
    bool ready,
  ) {
    final loading = !ready;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              // The summary can be shorter than the pane; pull-to-refresh
              // still has to work then.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: loading
                  ? const EdgeInsets.fromLTRB(20, 10, 6, 10)
                  : const EdgeInsets.only(bottom: 12),
              children: loading
                  ? const [FullCardShimmer(height: 240)]
                  : [
                      _attendeeRow(context, provider, isDark),
                      _summaryCard(provider),
                    ],
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: loading
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(6, 10, 20, 10),
                  children: const [FullCardShimmer(height: 300)],
                )
              : EventAddLine(eventId: widget.id, fillHeight: true),
        ),
      ],
    );
  }

  /// Attendee count and the scan-to-register shortcut; nothing while no seat
  /// is taken.
  Widget _attendeeRow(
    BuildContext context,
    EventDetailedProvider provider,
    bool isDark,
  ) {
    if (provider.eventModel!.seatTaken == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    EventAttendeesPage(eventId: widget.id, initialFilter: 'Taken'),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                // grey[850] in dark mode: the surface colour there is all but
                // the page's own, so the chip read as an unfilled outline. The
                // same grey as the other dark-mode cards.
                color: isDark ? Colors.grey[850] : AppTheme.surface(isDark),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [AppShadows.cardShadow],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 13,
                  horizontal: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(
                      icon: _teamIconNoPlus,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    SizedBox(width: 10),
                    Text(
                      provider.eventModel!.attended.toString(),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Registering by scan marks the attendee
          // present — a write on `event.registration`.
          if (context.watch<AccessRights>().canMarkAttended)
            // Takes the rest of the row and right-aligns the button in it, so
            // a narrow pane squeezes the label instead of overflowing, and a
            // wide one leaves the button at its natural size.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),

                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RegistrationPage(id: widget.id),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.qr_code_2, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              "Scan to Register",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryCard(EventDetailedProvider provider) {
    return provider.eventModel == null
        ? SizedBox(height: 200, child: Center(child: Text("No Event Found")))
        : EventMainCard(event: provider.eventModel!);
  }

  Future<void> openDynamicLink(String link) async {
    final Uri url = Uri.parse(link);

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $link');
    }
  }
}
