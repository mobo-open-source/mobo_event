import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/features/event/helper/event_status.dart';

void main() {
  group('orDefault', () {
    test('keeps a real status', () {
      expect(EventStatus.orDefault('blocked'), 'blocked');
      expect(EventStatus.orDefault('cancel'), 'cancel');
    });

    test('an event with none reads as In Progress', () {
      expect(EventStatus.orDefault(''), 'normal');
      expect(EventStatus.orDefault(null), 'normal');
    });
  });

  group('onStageChange', () {
    String change({
      String current = 'done',
      int to = 2,
      int? loadedStage = 1,
      String loaded = 'done',
    }) => EventStatus.onStageChange(
      current: current,
      newStageId: to,
      loadedStageId: loadedStage,
      loadedState: loaded,
    );

    test('another stage resets the status to In Progress', () {
      expect(change(current: 'done'), 'normal');
      expect(change(current: 'blocked', loaded: 'blocked'), 'normal');
    });

    test('Cancelled survives a stage move (Odoo 19+)', () {
      expect(change(current: 'cancel', loaded: 'cancel'), 'cancel');
    });

    test('going back to the loaded stage gives the loaded status back', () {
      // done → stage 2 (normal) → stage 1 again.
      expect(change(current: 'normal', to: 1, loaded: 'done'), 'done');
    });

    test('a later move to a third stage resets an explicit pick too', () {
      // done → stage 2, picked blocked → stage 3.
      expect(change(current: 'blocked', to: 3, loaded: 'done'), 'normal');
    });
  });

  group('writeVals', () {
    Map<String, dynamic> vals({
      required String current,
      required String? loaded,
      bool stageMoved = false,
    }) => EventStatus.writeVals(
      current: current,
      loaded: loaded,
      stageMoved: stageMoved,
    );

    test('nothing changed writes nothing', () {
      expect(vals(current: 'done', loaded: 'done'), isEmpty);
    });

    test('a status change alone is sent without any stage', () {
      expect(vals(current: 'blocked', loaded: 'done'), {
        'kanban_state': 'blocked',
      });
    });

    test('a stage move always states the status, even an unchanged one', () {
      // Without it Odoo 17/18 reset it, and 19+ recompute it.
      expect(vals(current: 'done', loaded: 'done', stageMoved: true), {
        'kanban_state': 'done',
      });
      expect(vals(current: 'normal', loaded: 'normal', stageMoved: true), {
        'kanban_state': 'normal',
      });
    });

    test('a loaded event with no status counts as In Progress', () {
      expect(vals(current: 'normal', loaded: ''), isEmpty);
      expect(vals(current: 'normal', loaded: null), isEmpty);
      expect(vals(current: 'done', loaded: ''), {'kanban_state': 'done'});
    });
  });
}
