import 'odoo_version.dart';

/// Version-dependent field names and write rules for Odoo 16 through 20, and
/// for any newer release (see below).
///
/// Each member records the release that changed it, so supporting a new
/// version means reviewing these rather than hunting through call sites.
/// Call sites must ask this class instead of comparing version strings: an
/// `== '19'` is silently false on 20, and on 29.
///
/// Every getter is a `>=` (or `<`) on the release that introduced the change,
/// so a release newer than [OdooVersion.maxSupported] behaves like the newest
/// one we know. When a new release renames or removes something, add the split
/// here; until then the newest branch is the best available guess.
class OdooCompat {
  /// Major version this instance describes, e.g. `16`.
  final int major;

  const OdooCompat(this.major);

  /// Compat table for a version already in hand, for code that cannot await —
  /// a widget's `build`, most often. [version] may be anything
  /// [OdooVersion.majorOf] accepts (`"20"`, `"20.0"`, `"saas~19.2"`, …).
  ///
  /// An unknown version resolves to [OdooVersion.fallbackMajor], so every gate
  /// answers "not this release yet" rather than opting into behaviour the
  /// server may lack.
  factory OdooCompat.of(dynamic version) =>
      OdooCompat(OdooVersion.majorOf(version) ?? OdooVersion.fallbackMajor);

  /// Compat table for the currently connected server.
  ///
  /// Holds no cache: [OdooVersion.major] reads the live session every call, so
  /// switching or adding an account is picked up immediately.
  static Future<OdooCompat> current() async =>
      OdooCompat(await OdooVersion.major());

  /// Odoo 19 removed `mobile` from `res.partner`, merging it into `phone`.
  bool get hasMobileField => major < 19;

  /// Whether `phone` can be written on the user's own `res.users` record.
  ///
  /// `res.users.write` bypasses access rights only when every key of the write
  /// is in `SELF_WRITEABLE_FIELDS`. Odoo 19 added `phone` to that list — its
  /// Preferences form edits `phone` on `res.users` — while 16/17/18 must write
  /// the number on `res.partner`, which needs `base.group_partner_manager`.
  bool get userPhoneIsSelfWritable => major >= 19;

  /// Odoo 20 replaced the `SELF_WRITEABLE_FIELDS` list with a per-field
  /// `user_writeable=True` flag, and `action_id` (the home action) did not get
  /// it. The others in [userSelfWritableFields] did.
  bool get userActionIsSelfWritable => major < 20;

  /// Fields a user may write on their own `res.users` record on this release.
  ///
  /// Anything outside this set has to be written on `res.partner`, where
  /// `base.group_user` grants read only — see [userPhoneIsSelfWritable].
  Set<String> get userSelfWritableFields => {
    'signature',
    if (userActionIsSelfWritable) 'action_id',
    'company_id',
    'email',
    'name',
    'image_1920',
    'lang',
    'tz',
    if (userPhoneIsSelfWritable) 'phone',
  };

  /// Whether `res.users.has_group` is a per-record method.
  ///
  /// Through Odoo 17 it is `@api.model` and takes the group alone
  /// (`[group]`); from 18 it is called on the user record and needs the id
  /// first (`[[uid], group]`).
  bool get hasGroupPerRecord => major >= 18;

  /// Whether `has_access` exists as the ORM's permission question.
  ///
  /// Odoo 18 introduced `has_access(operation)` (and `check_access`) and
  /// deprecated `check_access_rights`; Odoo 20 removed `check_access_rights`
  /// outright. Through 17 only `check_access_rights(operation,
  /// raise_exception=False)` can be asked.
  bool get hasHasAccess => major >= 18;

  /// Odoo 19 introduced multi-slot events: the `event.slot` model,
  /// `event.event.is_multi_slots`, and `event.registration.event_slot_id`.
  /// Sending any of them to an older server is an unknown-field error.
  bool get hasEventSlots => major >= 19;

  /// Field linking `event.question` to its events.
  ///
  /// Through Odoo 18 a question belonged to a single event (`event_id`, many2one).
  /// Odoo 19 made questions reusable across events, so the link became the
  /// many2many `event_ids`.
  String get questionEventField => major >= 19 ? 'event_ids' : 'event_id';

  /// Odoo 19 added `is_default` and `is_reusable` to `event.question`, and with
  /// them the "pick from existing questions" flow. Older releases create the
  /// question straight onto the event.
  bool get hasReusableQuestions => major >= 19;

  /// Whether the event search view offers "Venue" (`address_id`) in its Group By
  /// menu. Through Odoo 17 the menu is Responsible / Template / Stage / Start
  /// Date only; 18 added Venue. The field itself exists on every release.
  bool get hasVenueGroupBy => major >= 18;

  /// Odoo 19 added a fourth kanban state, `cancel` ("Cancelled"), to
  /// `event.event`. Through 18 the selection is normal / done / blocked, and
  /// writing `cancel` is rejected.
  bool get hasCancelledKanbanState => major >= 19;

  /// Odoo 19 added two mail-scheduler triggers to `event.mail.interval_type`:
  /// `after_event_start` and `before_event_end`. Through 18 only `after_sub`,
  /// `before_event` and `after_event` exist.
  bool get hasEventBoundaryMailTriggers => major >= 19;

  /// Server method behind the "Attended" button on a registration.
  ///
  /// Through Odoo 19 that is `action_set_done`, which just closes the record.
  /// Odoo 20 added multi-entry tickets (`entry_limit`): the button became
  /// `action_attend_event`, which logs a sub-registration while entries remain
  /// and falls back to `action_set_done` on the last one. `action_set_done`
  /// still exists there but skips that bookkeeping.
  String get attendRegistrationMethod =>
      major >= 20 ? 'action_attend_event' : 'action_set_done';

  /// Product field that marks a product as an event ticket.
  ///
  /// Odoo 17 and earlier used `detailed_type == 'event'`; from 18 that field was
  /// removed and `service_tracking == 'event'` took over.
  String get eventProductTrackingField =>
      major >= 18 ? 'service_tracking' : 'detailed_type';

  /// True when the server is outside the range this app was built against.
  /// Calls still go through using the nearest supported behaviour.
  bool get isUntested =>
      major < OdooVersion.minSupported || major > OdooVersion.maxSupported;

  @override
  String toString() => 'OdooCompat(major: $major)';
}
