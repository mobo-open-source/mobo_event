import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../../core/const/app_colors.dart';
import '../../../shared/widgets/back_dialog/show_back_dialog.dart';
import '../provider/event_detailed_provider.dart';
import '../widget/create_form.dart';
import '../widget/event_form.dart';

class EventAddScreen extends StatefulWidget {
  const EventAddScreen({super.key});

  @override
  State<EventAddScreen> createState() => _EventAddScreenState();
}

class _EventAddScreenState extends State<EventAddScreen> {
  final _formKey = GlobalKey<CreateFormState>();

  /// Leaves straight away when nothing was entered; otherwise asks first,
  /// since the data would be lost.
  Future<void> _onBack() async {
    final provider = Provider.of<EventDetailedProvider>(
      context,
      listen: false,
    );
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
    provider.clearDummyTicket();
    Navigator.pop(context);
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
        appBar: AppBar(
          backgroundColor: isDark ? Colors.grey[900] : backgroundColor,
          leading: GestureDetector(
            // maybePop runs the PopScope prompt, same as system back.
            onTap: () => Navigator.maybePop(context),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          title: Text(
            "Create an event",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        backgroundColor: isDark ? Colors.grey[900] : backgroundColor,

        // Side insets keep the form clear of a display cutout when the phone
        // is on its side; they are zero upright. (The bottom is the form's
        // own, since its pinned button sits there.)
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [Expanded(child: CreateForm(key: _formKey))],
          ),
        ),
      ),
    );
  }
}
