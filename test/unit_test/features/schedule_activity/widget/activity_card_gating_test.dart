import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/services/event_access_rights.dart';
import 'package:mobo_event/features/schedule_activity/model/activities_model.dart';
import 'package:mobo_event/features/schedule_activity/widget/activity_card.dart';
import 'package:provider/provider.dart';

/// Answers the permission API from a per-model 'cwu' table.
AccessRights _rights(Map<String, String> role, {int userId = 7}) {
  return AccessRights(
    call: (params) async {
      final op = params['method'] == 'has_access'
          ? (params['args'] as List)[1] as String
          : (params['args'] as List)[0] as String;
      final letters = role[params['model']] ?? '';
      return switch (op) {
        'create' => letters.contains('c'),
        'write' => letters.contains('w'),
        'unlink' => letters.contains('u'),
        _ => true,
      };
    },
    version: () async => '19.0',
    userId: userId,
  );
}

const _desk = {EventModels.event: '', EventModels.activity: 'cwu'};
const _user = {EventModels.event: 'cw', EventModels.activity: 'cwu'};
const _noActivity = {EventModels.event: 'cw', EventModels.activity: ''};

ActivitiesModel _activity({required int assignee}) => ActivitiesModel(
  id: 1,
  name: 'Call the venue',
  duedate: '2026-10-01',
  activityType: [1, 'Call'],
  userId: [assignee, 'Someone'],
  state: 'planned',
);

Future<void> _pump(
  WidgetTester tester,
  AccessRights rights,
  ActivitiesModel activity,
) async {
  await rights.load();
  await tester.pumpWidget(
    ChangeNotifierProvider<AccessRights>.value(
      value: rights,
      child: MaterialApp(
        home: Scaffold(body: ActivityCard(activiy: activity)),
      ),
    ),
  );
}

void main() {
  testWidgets('a user who can write the event gets both actions on anyone\'s '
      'activity', (tester) async {
    await _pump(tester, _rights(_user), _activity(assignee: 9));

    expect(find.text('Mark as Done'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('a desk user gets both actions on their own activity', (
    tester,
  ) async {
    await _pump(tester, _rights(_desk, userId: 7), _activity(assignee: 7));

    expect(find.text('Mark as Done'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('a desk user gets no actions on someone else\'s activity', (
    tester,
  ) async {
    await _pump(tester, _rights(_desk, userId: 7), _activity(assignee: 9));

    expect(find.text('Mark as Done'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    // The card itself still shows what is planned.
    expect(find.text('Call'), findsOneWidget);
  });

  testWidgets('without any activity access there is nothing to press', (
    tester,
  ) async {
    await _pump(tester, _rights(_noActivity), _activity(assignee: 7));

    expect(find.text('Mark as Done'), findsNothing);
    expect(find.text('Delete'), findsNothing);
  });
}
