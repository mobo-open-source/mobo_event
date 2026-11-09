import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/helper/helper_method.dart';
import '../../../shared/widgets/forms/mobo_select_field.dart';
import '../../home/providers/home_provider.dart';

/// The event's status (`kanban_state`) for the create and edit forms: a
/// dropdown whose closed field shows the status as a coloured pill (the same
/// colours as the status badge on the details card) over a plain list.
///
/// Odoo 17 and 18 have In Progress / Ready / Blocked only; Cancelled arrived
/// in 19 (writing it earlier is rejected), hence the compat gate. A status
/// always exists, so the field can't be cleared.
class EventStatusField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const EventStatusField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasCancelled = context
        .watch<HomeProvider>()
        .compat
        .hasCancelledKanbanState;

    return MoboSingleSelectField<String>(
      selected: value,
      hintText: 'Select status',
      panelTitle: 'Select Status',
      allowClear: false,
      options: [
        for (final state in [
          'normal',
          'done',
          'blocked',
          if (hasCancelled) 'cancel',
        ])
          MoboSelectOption(
            value: state,
            label: getKanbanLabel(state),
            badgeColor: getKanbanColor(state),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
