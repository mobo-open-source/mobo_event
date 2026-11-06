import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/core/services/event_access_rights.dart';
import 'package:mobo_event/features/registration/page/add_attendees.dart';
import 'package:mobo_event/features/registration/provider/registration_provider.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';

import '../../../shared/helper/helper_method.dart';
import '../../../core/theme/app_theme.dart';

Widget floatingActionButtonAddingAttendees(BuildContext context, int? eventId) {
  // Adding an attendee is a create on `event.registration`.
  if (!context.watch<AccessRights>().canCreateAttendee) {
    return const SizedBox.shrink();
  }
  return _AddAttendeeButton(eventId: eventId);
}

class _AddAttendeeButton extends StatefulWidget {
  final int? eventId;

  const _AddAttendeeButton({required this.eventId});

  @override
  State<_AddAttendeeButton> createState() => _AddAttendeeButtonState();
}

class _AddAttendeeButtonState extends State<_AddAttendeeButton> {
  /// True while the new attendee's defaults are being fetched. The button spins
  /// and ignores another tap: with no blocking dialog over the screen, that is
  /// what stops a second tap loading them again and pushing a second page.
  bool _loading = false;

  Future<void> _open() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final provider = Provider.of<RegistrationProvider>(
        context,
        listen: false,
      );

      provider.resetRegistration();

      // The form reads what this fetches when it opens, so it is in before the
      // page is pushed.
      await provider.onchange(widget.eventId);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddAttendees(eventId: widget.eventId ?? 0),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(context, cleanedError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _open,
      child: Container(
        height: 55,
        width: 55,
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [AppShadows.cardShadow],
        ),
        child: _loading
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              )
            : const Padding(
                padding: EdgeInsets.all(10.0),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedAddTeam,
                  color: Colors.white,
                  strokeWidth: 1,
                ),
              ),
      ),
    );
  }
}
