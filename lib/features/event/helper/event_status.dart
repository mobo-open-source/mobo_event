/// Rules for an event's status (`kanban_state`) in the edit form, shared by
/// every Odoo release the app supports.
///
/// The server resets the status when the stage moves: Odoo 17 and 18 put it
/// back to In Progress on any write carrying `stage_id` without
/// `kanban_state`; 19 and later recompute it from the stage, except
/// Cancelled, which is kept. The form shows that reset straight away and
/// states the status outright when it saves a stage move, so what the user
/// sees is what is stored.
class EventStatus {
  const EventStatus._();

  /// An event with no status reads as In Progress, Odoo's default.
  static String orDefault(String? state) =>
      (state ?? '').isNotEmpty ? state! : 'normal';

  /// What the form shows after the stage is changed to [newStageId]: the
  /// loaded status when it is the loaded stage again (so undoing the move
  /// leaves nothing to save), otherwise what the server would reset it to.
  static String onStageChange({
    required String current,
    required int newStageId,
    required int? loadedStageId,
    required String loadedState,
  }) {
    if (newStageId == loadedStageId) return loadedState;
    return current == 'cancel' ? 'cancel' : 'normal';
  }

  /// The `kanban_state` part of the write. Always sent with a stage move (a
  /// write with `stage_id` alone would reset it); otherwise only when it
  /// differs from the [loaded] status.
  static Map<String, dynamic> writeVals({
    required String current,
    required String? loaded,
    required bool stageMoved,
  }) => {
    if (stageMoved || current != orDefault(loaded)) 'kanban_state': current,
  };
}
