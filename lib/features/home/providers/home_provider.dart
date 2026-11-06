import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:mobo_event/core/models/event_stage.dart';
import 'package:mobo_event/core/services/event_access_rights.dart';
import 'package:mobo_event/core/services/odoo_session_manager.dart';
import 'package:mobo_event/core/utils/odoo_compat.dart';
import 'package:mobo_event/features/home/model/event_group.dart';
import 'package:mobo_event/features/home/model/event_short.dart';

import '../services/home_services.dart';

/// Home screen's event listing — either a single filtered list (List view)
/// or all stages side by side (Kanban view, drag-to-change-stage).
enum HomeViewMode { list, kanban }

class HomeProvider extends ChangeNotifier {
  final HomeServices services;

  /// What the signed-in account may create, edit and delete. Loaded with the
  /// stages and reset with the rest of this provider on account switch/logout
  /// (see [clearProvider]), so one account's rights never carry over to the
  /// next.
  final AccessRights access;

  HomeProvider({required this.services, AccessRights? access})
    : access = access ?? AccessRights.instance {
    // Widgets read the rights through this provider, so a refresh of them
    // (app resume, account switch) has to rebuild whatever is watching it.
    this.access.addListener(notifyListeners);
  }

  @override
  void dispose() {
    access.removeListener(notifyListeners);
    super.dispose();
  }

  HomeViewMode viewMode = HomeViewMode.list;

  void setViewMode(HomeViewMode mode) {
    if (viewMode == mode) return;
    viewMode = mode;
    notifyListeners();
  }

  List<EventStage> stageList = [];
  List<EventShort> eventList = [];

  /// Stages in Odoo's own order (`sequence, name`, then id) — the order the
  /// kanban columns and the event forms' stage picker both show. Sorted here
  /// rather than trusting [stageList]'s order, which is the server's after a
  /// load but not after a local add or reorder.
  List<EventStage> get orderedStages => [...stageList]
    ..sort((a, b) {
      final bySequence = a.sequence.compareTo(b.sequence);
      if (bySequence != 0) return bySequence;
      final byName = a.name.compareTo(b.name);
      return byName != 0 ? byName : a.id.compareTo(b.id);
    });

  /// Whether the account may manage the kanban board's stages at all — the
  /// server grants that to Event administrators only. Each individual action
  /// (add, rename, reorder, delete) asks [access] for its own permission.
  bool get canManageStages => access.canManageStages;

  String version = '';

  /// Version gates for the connected server, for widgets that decide what to
  /// show while building. Ask this instead of testing [version] as a string:
  /// `version.contains('19')` is false on Odoo 20 and 29.
  OdooCompat get compat => OdooCompat.of(version);

  ///getting version
  fetchVersion() async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      final oodoVersion = session!.version;
      version = oodoVersion!;
      notifyListeners();
    } catch (_) {}
  }

  bool isStageLoading = false;
  bool isEventLoading = false;
  bool loading = false;
  List<String> activeFilters = [];

  /// How the events are grouped (the filter sheet's Group By tab), or null for
  /// the plain list and the stage board. The List view shows the groups as
  /// collapsible tiles, the Kanban board as columns (see [moveEventToGroup]);
  /// grouped by [EventGroupBy.stage] the board is just its usual stage columns.
  EventGroupBy? groupBy;

  /// Whether a Group By is applied — the List view then shows groups rather
  /// than pages of events.
  bool get isGrouped => groupBy != null;

  /// default values in filters
  List<String> eventType = ['Published', 'Archived', 'Upcoming/Running'];
  List<String> fullFilters = ['My events', 'Online'];

  void setLoading(bool value) {
    loading = value;
    notifyListeners();
  }

  void clearProvider() {
    stageList = [];
    eventList = [];
    groupBy = null;
    access.reset();
    isStageLoading = true;
    isEventLoading = true;
    notifyListeners();
  }

  void setActiveFilters(List<String> filters) {
    activeFilters = List.from(filters);
    notifyListeners();
  }

  void setGroupBy(EventGroupBy? value) {
    if (groupBy == value) return;
    groupBy = value;
    notifyListeners();
  }

  /// [eventList] split into the groups of the grouped List view and board.
  /// Every event is in a group — grouping replaces paging: each group holds
  /// all its events, and the List view reveals them a page at a time.
  List<EventGroup> get groupedEvents {
    final by = groupBy;
    if (by == null) return const [];
    return groupEvents(eventList, by, stages: orderedStages);
  }

  /// List view's pagination — a display window over the already fully
  /// loaded [eventList], not a server-paged fetch: Kanban needs every event
  /// in [eventList] at once to distribute cards across stage columns, so
  /// the List view can't limit/offset the RPC itself without starving it.
  int currentPage = 1;
  final int pageSize = 20;

  int get totalRecords => eventList.length;
  int get totalPages =>
      totalRecords == 0 ? 1 : (totalRecords / pageSize).ceil();
  bool get canGoPrevious => currentPage > 1;
  bool get canGoNext => currentPage < totalPages;
  int get startCount =>
      totalRecords == 0 ? 0 : ((currentPage - 1) * pageSize) + 1;
  int get endCount {
    final end = currentPage * pageSize;
    return end > totalRecords ? totalRecords : end;
  }

  String get paginationText =>
      totalRecords == 0 ? '0/0' : '$startCount-$endCount / $totalRecords';

  List<EventShort> get pagedEventList {
    if (eventList.isEmpty) return const [];
    final start = (currentPage - 1) * pageSize;
    if (start >= eventList.length) return const [];
    final end = (start + pageSize).clamp(0, eventList.length);
    return eventList.sublist(start, end);
  }

  void nextPage() {
    if (!canGoNext) return;
    currentPage++;
    notifyListeners();
  }

  void previousPage() {
    if (!canGoPrevious) return;
    currentPage--;
    notifyListeners();
  }

  /// Last search string a fetch ran with — Kanban reads this (it has no
  /// search field of its own) to know whether a query is currently narrowing
  /// [eventList], alongside [activeFilters].
  String searchText = '';

  /// Bumped by every [loadEvents] call; a fetch whose number is no longer the
  /// latest has been superseded (the user typed/filtered again) and drops its
  /// result instead of overwriting the newer one.
  int _loadEventsRequest = 0;

  ///getting events
  Future loadEvents({String search = ''}) async {
    final request = ++_loadEventsRequest;
    try {
      isEventLoading = true;
      searchText = search;
      notifyListeners();

      final events = await services.gettingEventsShort(
        search: search,
        filter: activeFilters,
      );
      if (request != _loadEventsRequest) return;
      eventList = events;
      currentPage = 1;
    } catch (_) {
      if (request != _loadEventsRequest) return;
      rethrow;
    } finally {
      // A superseded fetch leaves the loading state to the newer one.
      if (request == _loadEventsRequest) {
        isEventLoading = false;
        notifyListeners();
      }
    }
  }

  /// Moves [eventId] to [stageId] (kanban drag). Updates the local list
  /// straight away so the card doesn't snap back while the request is in
  /// flight, and rolls back if the server rejects it.
  Future<void> moveEventToStage(int eventId, int stageId) async {
    final index = eventList.indexWhere((e) => e.id == eventId);
    if (index == -1) return;

    final previous = eventList[index];
    if (previous.stageId == stageId) return;

    final stage = stageList.firstWhere((s) => s.id == stageId);
    eventList[index] = previous.copyWith(stageId: stageId, stage: stage.name);
    notifyListeners();

    try {
      final ok = await services.updateEventStage(
        eventId: eventId,
        stageId: stageId,
      );
      if (!ok) throw Exception('Stage update rejected');
    } catch (_) {
      eventList[index] = previous;
      notifyListeners();
      rethrow;
    }
  }

  /// Moves [eventId] to [target], a column of the grouped board (or a tile of
  /// the grouped list): writes the field the grouping is on. Like
  /// [moveEventToStage], the local list changes straight away so the card
  /// doesn't snap back while the request is in flight, and rolls back if the
  /// server rejects it.
  ///
  /// A month can't be written, so grouping by Start Date moves nothing.
  Future<void> moveEventToGroup(int eventId, EventGroup target) async {
    final by = groupBy;
    if (by == null || !by.isDraggable) return;
    if (by == EventGroupBy.stage) {
      return moveEventToStage(eventId, target.recordId);
    }

    final index = eventList.indexWhere((e) => e.id == eventId);
    if (index == -1) return;
    final previous = eventList[index];
    if (target.events.any((e) => e.id == eventId)) return;

    eventList[index] = _inGroup(previous, by, target);
    notifyListeners();

    try {
      final ok = await services.updateEventRelation(
        eventId: eventId,
        field: by.field!,
        id: target.recordId,
      );
      if (!ok) throw Exception('Event update rejected');
    } catch (_) {
      // A reload while the request was out can have moved it.
      final at = eventList.indexWhere((e) => e.id == eventId);
      if (at != -1) eventList[at] = previous;
      notifyListeners();
      rethrow;
    }
  }

  /// [event] as it reads once it belongs to [target]. What the list only gets
  /// from the server — the responsible's photo, a venue's address — is taken
  /// from another event already in [target], which has the same value, so the
  /// card doesn't show the old group's until the next refresh.
  EventShort _inGroup(EventShort event, EventGroupBy by, EventGroup target) {
    final peer = target.events.isEmpty ? null : target.events.first;
    final none = target.recordId == 0;
    switch (by) {
      case EventGroupBy.responsible:
        return event.copyWith(
          userId: target.recordId,
          userName: none ? '' : target.label,
          // Empty bytes clear the photo (null would keep the old one).
          image: none ? Uint8List(0) : peer?.image ?? Uint8List(0),
        );
      case EventGroupBy.template:
        return event.copyWith(
          templateId: target.recordId,
          templateName: none ? '' : target.label,
        );
      case EventGroupBy.venue:
        return event.copyWith(
          venueId: target.recordId,
          venueName: none ? '' : target.label,
          location: none ? '' : peer?.location ?? target.label,
        );
      case EventGroupBy.stage:
      case EventGroupBy.startDate:
        return event;
    }
  }

  /// Renames a stage (kanban column header's "⋮" action).
  Future<void> renameStage(int stageId, String name) async {
    final index = stageList.indexWhere((s) => s.id == stageId);
    if (index == -1) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == stageList[index].name) return;

    await services.renameStage(stageId: stageId, name: trimmed);
    final stage = stageList[index];
    stageList[index] = EventStage(
      id: stage.id,
      name: trimmed,
      displayName: trimmed,
      description: stage.description,
      sequence: stage.sequence,
      fold: stage.fold,
      pipeEnd: stage.pipeEnd,
      createUid: stage.createUid,
      createDate: stage.createDate,
      writeUid: stage.writeUid,
      writeDate: stage.writeDate,
    );
    notifyListeners();
  }

  /// Reorders stage columns (kanban column drag). [displayedOrder] is the
  /// exact sequence-sorted list the board is showing, so [oldIndex]/
  /// [newIndex] line up with what the user actually dragged. Reassigns
  /// sequence 10, 20, 30… across that new order and writes back only the
  /// stages whose sequence actually changed.
  Future<void> reorderStages(
    List<EventStage> displayedOrder,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex) return;
    final reordered = [...displayedOrder];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    final previous = stageList;
    final updated = <EventStage>[];
    final toPersist = <EventStage>[];
    for (var i = 0; i < reordered.length; i++) {
      final stage = reordered[i];
      final sequence = (i + 1) * 10;
      if (sequence == stage.sequence) {
        updated.add(stage);
      } else {
        final withNewSequence = _withSequence(stage, sequence);
        updated.add(withNewSequence);
        toPersist.add(withNewSequence);
      }
    }

    stageList = updated;
    notifyListeners();

    try {
      for (final stage in toPersist) {
        await services.updateStageSequence(
          stageId: stage.id,
          sequence: stage.sequence,
        );
      }
    } catch (_) {
      stageList = previous;
      notifyListeners();
      rethrow;
    }
  }

  EventStage _withSequence(EventStage stage, int sequence) => EventStage(
    id: stage.id,
    name: stage.name,
    displayName: stage.displayName,
    description: stage.description,
    sequence: sequence,
    fold: stage.fold,
    pipeEnd: stage.pipeEnd,
    createUid: stage.createUid,
    createDate: stage.createDate,
    writeUid: stage.writeUid,
    writeDate: stage.writeDate,
  );

  /// Deletes a stage (kanban column's "Delete" action). Removed locally
  /// right away; restored if the server rejects it (e.g. events still
  /// reference it) so the column doesn't just silently reappear later.
  Future<void> deleteStage(int stageId) async {
    final index = stageList.indexWhere((s) => s.id == stageId);
    if (index == -1) return;
    final previous = stageList;
    stageList = [...previous]..removeAt(index);
    notifyListeners();

    try {
      final ok = await services.deleteStage(stageId);
      if (!ok) throw Exception('Stage delete rejected');
    } catch (_) {
      stageList = previous;
      notifyListeners();
      rethrow;
    }
  }

  /// Adds a new stage as the last kanban column.
  Future<void> addStage(String name) async {
    final nextSequence = stageList.isEmpty
        ? 1
        : stageList.map((s) => s.sequence).reduce((a, b) => a > b ? a : b) + 1;
    final stage = await services.createStage(name.trim(), nextSequence);
    stageList = [...stageList, stage];
    notifyListeners();
  }

  ///getting stages
  Future<bool> gettingStages() async {
    try {
      isStageLoading = true;
      isEventLoading = true;
      notifyListeners();

      // Fetch stages from server, and ask what the account may do alongside —
      // [AccessRights.load] never throws, so it can't fail the stage load,
      // and it is a no-op while the answers for this account are still good.
      final stagesRequest = services.gettingStage();
      final accessRequest = access.load();
      stageList = await stagesRequest;
      await accessRequest;

      await loadEvents();

      return stageList.isNotEmpty;
    } catch (_) {
      return false;
    } finally {
      isStageLoading = false;
      isEventLoading = false;
      notifyListeners();
    }
  }
}
