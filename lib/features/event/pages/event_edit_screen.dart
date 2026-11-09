import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/features/event/pages/event_details_screen.dart';
import 'package:mobo_event/features/event/widget/event_form.dart';
import 'package:provider/provider.dart';

import '../../../core/const/app_colors.dart';
import '../../../shared/widgets/back_dialog/show_back_dialog.dart';
import '../provider/event_detailed_provider.dart';
import '../widget/event_form.dart' show EventFormState;

class EventEditScreen extends StatefulWidget {
  const EventEditScreen({super.key});

  @override
  State<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends State<EventEditScreen> {
  final _formKey = GlobalKey<EventFormState>();

  /// Leaves straight away when nothing was edited; otherwise asks first,
  /// since the changes would be lost.
  Future<void> _onBack() async {
    if (_formKey.currentState?.hasChanges ?? false) {
      final leave = await showBackDialog(
        context,
        title: 'Discard event',
        subtitle:
            "You have unsaved Event data that will be lost if you leave this page. Are you sure you want to discard this Event?",
        leftButtonName: "Stay",
        rightButtonName: "Leave",
        function: () => Navigator.pop(context, true),
      );
      if (!leave || !mounted) return;
    }
    _leave(context);
  }

  /// Edit is reached from Details, but also from the calendar after creating
  /// an event (no Details below), so leaving always rebuilds Details above
  /// Home instead of popping.
  void _leave(BuildContext context) {
    final detailProvider = Provider.of<EventDetailedProvider>(
      context,
      listen: false,
    );
    EventDetailsScreen.openFresh(context, detailProvider.eventModel!.id);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBack();
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : backgroundColor,

        appBar: AppBar(
          backgroundColor: isDark ? Colors.grey[900] : backgroundColor,
          leading: GestureDetector(
            onTap: _onBack,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          title: Text(
            "Edit an event",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Side insets keep the form clear of a display cutout when the phone
        // is on its side; they are zero upright. (The bottom is the form's
        // own, since its pinned button sits there.)
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [Expanded(child: EventForm(key: _formKey))],
          ),
        ),
      ),
    );
  }
}
