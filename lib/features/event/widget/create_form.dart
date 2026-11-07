import 'dart:convert';
import 'published_toggle.dart';
import 'create_slots_button.dart';
import '../../../shared/widgets/toggles/mobo_checkbox.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show mapEquals;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/app/home_scaffold.dart';
import 'package:mobo_event/features/event/services/event_detailed_services.dart';
import 'package:mobo_event/features/event/widget/field.dart';
import 'package:mobo_event/features/event/widget/ticket_line_widget.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/standalone.dart' as tz;

import '../../../core/const/app_colors.dart';
import '../../../shared/helper/helper_method.dart';
import '../../../shared/widgets/back_dialog/show_back_dialog.dart';
import '../../../shared/widgets/dialogs/pinned_footer_layout.dart';
import '../../../shared/widgets/forms/dashed_border_box.dart';
import '../../../shared/widgets/forms/field_label.dart';
import '../../../shared/widgets/forms/mobo_select_field.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../home/providers/home_provider.dart';
import '../../review/services/review_service.dart';
import '../helper/time_zone.dart';
import '../model/fetch_model.dart';
import '../provider/event_detailed_provider.dart';
import 'event_calender.dart';
import 'event_status_field.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pinned_action_bar.dart';
import '../../../core/utils/screen_layout.dart';

class CreateForm extends StatefulWidget {
  const CreateForm({super.key});

  @override
  State<CreateForm> createState() => CreateFormState();
}

class CreateFormState extends State<CreateForm> {
  @override
  void initState() {
    super.initState();

    final provider = Provider.of<EventDetailedProvider>(context, listen: false);
    eventNameController.addListener(() => setState(() {}));
    _loadAllTags();

    // A new event starts on the first stage by sequence — what Odoo's own
    // `_get_default_stage_id` gives it — and only a different pick is sent.
    final firstStage = Provider.of<HomeProvider>(
      context,
      listen: false,
    ).orderedStages.firstOrNull;
    if (firstStage != null) {
      _defaultStage = FetchModel(id: firstStage.id, name: firstStage.name);
      selectedStage = _defaultStage;
    }

    final data = provider.sampleEvent;

    if (data == null) {
      _initialValues = _currentValues();
      return;
    }

    setState(() {
      selectedOrganiser = FetchModel(
        id: data.value.organizerId.id,
        name: data.value.organizerId.displayName,
      );
      responsible = FetchModel(
        id: data.value.userId.id,
        name: data.value.userId.displayName,
      );
      selectedLocation = FetchModel(
        id: data.value.addressId.id,
        name: data.value.addressId.displayName,
      );
      selectedCompany = FetchModel(
        id: data.value.companyId.id,
        name: data.value.companyId.displayName,
      );
      selectedTimezone = data.value.dateTz;
      websitePublished = data.value.websitePublished;
      fromDate = data.value.dateBegin;
      toDate = data.value.dateEnd;
      if (fromDate != null) {
        fromDateController.text = _format(fromDate!);
      }
      if (toDate != null) {
        toDateController.text = _format(toDate!);
      }
      _initialValues = _currentValues();
    });
  }

  /// What the form held once its defaults were filled in. Leaving only asks
  /// for confirmation when the current values differ from it.
  Map<String, Object?>? _initialValues;
  Uint8List? _initialImage;

  /// Everything the user can set, reduced to something `==` can compare.
  Map<String, Object?> _currentValues() => {
    'name': eventNameController.text.trim(),
    'organizer': selectedOrganiser?.id,
    'responsible': responsible?.id,
    'location': selectedLocation?.id,
    'company': selectedCompany?.id,
    'stage': selectedStage?.id,
    'kanbanState': kanbanState,
    'template': selectedTemplate?.id,
    'website': selectedWebsite?.id,
    'tags': (selectedTags.map((t) => t.id).toList()..sort()).join(','),
    'timezone': selectedTimezone,
    'from': fromDate,
    'to': toDate,
    'multipleSlot': multipleSlot,
    'limitRegistration': limitRegistration,
    'seatLimit': seatLimit.text.trim(),
    'websiteSubMenu': websiteSubMenu,
    'boothRegister': boothRegister,
    'showcaseTrack': showcaseTrack,
    'allowTrackProposal': allowTrackProposal,
    'showcaseExhibitory': showcaseExhibitory,
    'websitePublished': websitePublished,
    'visibility': selectedLabel,
    'onlineUrl': onlineUrl.text.trim(),
    'tickets': Provider.of<EventDetailedProvider>(
      context,
      listen: false,
    ).dummyTicketList.length,
  };

  /// True once anything differs from the freshly opened form — what the
  /// screen's back button checks before warning about lost data.
  bool get hasChanges =>
      _initialValues != null &&
      (!mapEquals(_currentValues(), _initialValues) ||
          !identical(fileBytes, _initialImage));

  final eventNameController = TextEditingController();
  final visibility = TextEditingController();
  final onlineUrl = TextEditingController();
  final fromDateController = TextEditingController();
  final toDateController = TextEditingController();
  final seatLimit = TextEditingController();
  DateTime? fromDate;
  DateTime? toDate;
  bool multipleSlot = false;

  /// True while "Create Slots" is creating the event it needs. That runs
  /// without a blocking dialog, so this is what stops a second tap (on it, or
  /// on Create Event) from creating the event twice.
  bool _creatingForSlots = false;
  bool limitRegistration = false;
  bool websiteSubMenu = false;
  bool boothRegister = false;
  bool showcaseTrack = false;
  bool allowTrackProposal = false;
  bool showcaseExhibitory = false;
  bool websitePublished = false;
  bool isLoading = true;
  bool templateLoading = false;
  String? selectedTimezone;
  String selectedLabel = "Public";
  final Map<String, String> visibilityTypes = {
    "Public": "public",
    "Via a Link": "link",
    "Logged Users": "logged_users",
  };

  List<String> timeZones = [];
  String? selectedZone;
  final service = EventDetailedServices();
  PlatformFile? pickedFile;
  Uint8List? fileBytes;
  FetchModel? selectedOrganiser;
  FetchModel? responsible;
  FetchModel? selectedLocation;
  FetchModel? selectedCompany;
  FetchModel? selectedStage;

  /// The stage the server would assign on its own; [selectedStage] starts here.
  FetchModel? _defaultStage;

  /// The event's status (`kanban_state`); a new event is In Progress.
  String kanbanState = 'normal';
  FetchModel? selectedTemplate;
  FetchModel? selectedWebsite;
  List<FetchModel> selectedTags = [];

  /// Every event tag, loaded once for the tag multi-select.
  List<FetchModel> allTags = [];

  Future<void> _loadAllTags() async {
    try {
      final tags = await service.getTypeHeadSearchListTags(model: 'event.tag');
      if (!mounted) return;
      setState(() => allTags = tags);
    } catch (_) {
      // The field still lists the tags already chosen; there is just
      // nothing new to offer.
    }
  }

  /// Server search behind a many2one picker: the [model] records matching
  /// the panel's search text, as select options.
  Future<List<MoboSelectOption<FetchModel>>> _searchOptions(
    String model,
    String query, {
    List domain = const [],
  }) async {
    final records = await service.getTypeHeadSearchList(
      model: model,
      search: query,
      domain: domain,
      limit: 20,
    );
    return records
        .map((m) => MoboSelectOption(value: m, label: m.name ?? ''))
        .toList();
  }

  String toOdooDateTime(DateTime dt) {
    final utc = dt.toUtc();
    return "${utc.year.toString().padLeft(4, '0')}-"
        "${utc.month.toString().padLeft(2, '0')}-"
        "${utc.day.toString().padLeft(2, '0')} "
        "${utc.hour.toString().padLeft(2, '0')}:"
        "${utc.minute.toString().padLeft(2, '0')}:"
        "${utc.second.toString().padLeft(2, '0')}";
  }

  /// date_tz can come back empty (e.g. a user with no tz); fall back to UTC
  /// like Odoo's slot calendar does instead of throwing.
  tz.Location _eventLocation(String name) {
    try {
      return tz.getLocation(name);
    } catch (_) {
      return tz.getLocation('UTC');
    }
  }

  bool get isFormValid =>
      eventNameController.text.trim().isNotEmpty &&
      selectedTimezone != null &&
      fromDate != null &&
      toDate != null;

  /// Mirrors event.event's server-side checks so the user gets a readable
  /// message instead of a raw ValidationError.
  String? _validationError() {
    if (!isFormValid) return "Please ensure all required fields are filled.";
    // _check_closing_date (Odoo 17 through 20).
    if (toDate!.isBefore(fromDate!)) {
      return "The end date cannot be earlier than the start date.";
    }
    if (limitRegistration && (int.tryParse(seatLimit.text.trim()) ?? 0) <= 0) {
      return "Enter a registration limit greater than 0.";
    }
    return null;
  }

  /// event.event create vals — shared by "Create Event" and the
  /// create-then-add-slots path so both send the same record.
  Map<String, dynamic> _buildPayload(EventDetailedProvider provider) {
    return {
      'name': eventNameController.text.trim(),
      'organizer_id': selectedOrganiser?.id ?? false,
      'user_id': responsible?.id ?? false,
      'address_id': selectedLocation?.id ?? false,
      'company_id': selectedCompany?.id ?? false,
      'tag_ids': [
        [6, 0, selectedTags.map((e) => e.id).toList()],
      ],
      if (provider.dummyTicketList.isNotEmpty)
        'event_ticket_ids': provider.buildEventTicketCommands(
          provider.dummyTicketList,
        ),
      'is_multi_slots': multipleSlot,
      'date_tz': selectedTimezone ?? false,
      'date_begin': toOdooDateTime(fromDate!),
      'date_end': toOdooDateTime(toDate!),
      'website_menu': websiteSubMenu,
      'booth_menu': boothRegister,
      'website_track': showcaseTrack,
      'website_track_proposal': allowTrackProposal,
      'exhibitor_menu': showcaseExhibitory,
      // Dropped by buildSafePayload on a server without website_event.
      'website_published': websitePublished,
      'seats_limited': limitRegistration,
      'seats_max': limitRegistration
          ? (int.tryParse(seatLimit.text.trim()) ?? 0)
          : 0,
      'website_visibility': visibilityTypes[selectedLabel],
      // event_url only applies to online events (no address), as in Odoo's form.
      'event_url': selectedLocation == null ? onlineUrl.text.trim() : false,
      'event_type_id': selectedTemplate?.id ?? false,
      // Left out while it is still the default, so the server keeps the
      // choice (and a stale local stage list can't fail the create).
      if (selectedStage != null && selectedStage != _defaultStage)
        'stage_id': selectedStage!.id,
      // Left out while it is the default. A create states it outright, so a
      // stage pick can't reset it (that only happens on write).
      if (kanbanState != 'normal') 'kanban_state': kanbanState,
      if (selectedWebsite != null) 'website_id': selectedWebsite!.id,
      'image_1024': fileBytes != null ? base64Encode(fileBytes!) : false,
    };
  }

  /// Date/time field — same filled recipe as [Field], read-only with a
  /// leading calendar icon (matches mobo_fleet's `_widgetVehiclesDatePicker`).
  Widget _dateField(TextEditingController controller, VoidCallback onTap) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            width: double.infinity,
            // 1px less than the 14×12 inset, to make room for the outline.
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 11),
            decoration: BoxDecoration(
              color: AppTheme.inputFill(isDark),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppTheme.restingBorderColor(isDark)),
            ),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  size: 20,
                  color: isDark ? Colors.white : Colors.grey[700],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    controller.text,
                    style: AppTheme.fieldValueStyle(isDark),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> pickDateTime(bool isFrom) async {
    final base = isFrom ? fromDate : toDate;
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: base ?? now,

      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    surface: AppTheme.darkSurface,
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black87,
                  ),
            datePickerTheme: DatePickerThemeData(
              headerBackgroundColor: primaryColor,
              headerForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: base != null
          ? TimeOfDay.fromDateTime(base)
          : TimeOfDay.now(),

      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    surface: AppTheme.darkSurface,
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    onSurface: Colors.black,
                  ),
            timePickerTheme: AppTheme.timePickerTheme(isDark),
            textSelectionTheme: AppTheme.timePickerTextSelection,
          ),
          child: child!,
        );
      },
    );
    if (time == null) return;

    final full = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isFrom) {
        fromDate = full;
        fromDateController.text = _format(full);
      } else {
        toDate = full;
        toDateController.text = _format(full);
      }
    });
  }

  String _format(DateTime dt) {
    final local = dt.toLocal();

    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final ap = local.hour >= 12 ? "PM" : "AM";

    return "${local.day}/${local.month}/${local.year}  $h:$m $ap";
  }

  Future<void> pickBackground() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        pickedFile = result.files.first;
        fileBytes = pickedFile!.bytes;
      });
    }
  }

  void removeBackground() {
    setState(() {
      pickedFile = null;
      fileBytes = null;
    });
  }

  Widget _uploadButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: pickBackground,
      child: DashedBorderBox(
        borderRadius: 5,
        color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: isDark ? Colors.grey[850] : fillColor,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedFileUpload,
                  color: isDark ? Colors.white : Colors.black,
                ),
                const SizedBox(width: 8),
                Text(
                  "Upload Image",
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imagePreview() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // The edit icon the other Mobo apps use, in their grey.
            IconButton(
              onPressed: pickBackground,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedPencilEdit02,
                color: AppTheme.secondaryLabelColor(
                  Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
            IconButton(
              onPressed: removeBackground,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                color: primaryColor,
              ),
            ),
          ],
        ),

        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            fileBytes!,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ],
    );
  }

  /// Slots need an event id, so the event is created first — same as Odoo,
  /// where the slot calendar only opens from a saved event. While it runs the
  /// Create Slots button spins and ignores taps; the calendar replaces this
  /// screen when the event exists.
  Future<void> _createEventForSlots() async {
    final error = _validationError();
    if (error != null) {
      CustomSnackbar.showWarning(context, error);
      return;
    }

    bool confirm = await showBackDialog(
      context,
      title: 'Add Slots',
      subtitle:
          "The event will be created before you can add slots. Do you want to continue?",
      leftButtonName: "Cancel",
      rightButtonName: "Create",
      function: () {
        Navigator.pop(context, true);
      },
    );
    if (!confirm || !mounted) return;

    final provider = Provider.of<EventDetailedProvider>(context, listen: false);
    // No dialog here: the Create Slots button spins instead, and the calendar
    // opens when it is done.
    setState(() => _creatingForSlots = true);
    try {
      final payloadFiltered = await provider.buildSafePayload(
        _buildPayload(provider),
      );
      final id = await service.createEvent(vals: payloadFiltered);
      if (id == null) {
        throw Exception("Some server Issue please check your server");
      }

      provider.clearDummyTicket();
      await provider.fetchEventDetails(id);
      ReviewService().trackSignificantEvent();

      tz.initializeTimeZones();
      final event = provider.eventModel!;
      final location = _eventLocation(event.timezone);
      final from = tz.TZDateTime.from(event.start.toUtc(), location);
      final to = tz.TZDateTime.from(event.end.toUtc(), location);

      if (!mounted) return;
      CustomSnackbar.showSuccess(context, "Successfully Created Event");
      // The event now exists, so the create screen is replaced — leaving it
      // underneath would let the user create the same event a second time.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CalendarScreen(eventId: event.id, fromDate: from, toDate: to),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _creatingForSlots = false);
      CustomSnackbar.showError(context, cleanedError(e.toString()));
    }
  }

  Widget _check(String t, bool v, Function(bool) on) =>
      MoboCheckboxTile(
        title: t,
        value: v,
        onChanged: on,
        checkboxAtEnd: true,
        padding: formToggleRowPadding,
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // A phone on its side is 700-900dp wide: cap the form so its fields
    // aren't stretched across all of it, and trim the footer so the fields
    // keep the little height there is. Upright, both are no-ops.
    final maxWidth = context.isLandscape ? 600.0 : double.infinity;
    final compact = context.isShortScreen;
    return Consumer<EventDetailedProvider>(
      builder: (context, provider, child) {
        final fields = Padding(
          padding: const EdgeInsets.all(20),

          child: ConstrainedContent(
            maxWidth: maxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _card("Event Information", [
                  _label("Event Name", isRequired: true),
                  Field(
                    controller: eventNameController,
                    hint: "Enter your event name",
                  ),

                  _label("Time zone", isRequired: true),
                  MoboSingleSelectField<String>(
                    selected: selectedTimezone,
                    // Still names a zone the list lacks, as the old picker did.
                    selectedLabel: selectedTimezone,
                    options: odooTimezones
                        .map(
                          (zone) => MoboSelectOption(value: zone, label: zone),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => selectedTimezone = v),
                    searchable: true,
                    allowClear: false,
                    hintText: 'Select time zone',
                    panelTitle: 'Select Time Zone',
                  ),
                  _label("From Date & Time"),
                  _dateField(fromDateController, () async {
                    await pickDateTime(true);
                  }),

                  _label("To Date & Time"),
                  _dateField(toDateController, () async {
                    await pickDateTime(false);
                  }),

                  if (provider.eventFields.containsKey('image_1024')) ...[
                    _label("Event Image"),
                    if (fileBytes == null) _uploadButton() else _imagePreview(),
                  ],

                  if (provider.eventFields.containsKey('is_multi_slots')) ...[
                    // The toggle and its "+ Create Slots" are one group, so
                    // the form's 10px gap doesn't open between them: the
                    // button sits right under the row, as "+ Create Question"
                    // does under the question picker's options.
                    FormToggleGroup(
                      children: [
                        _check(
                          "Multiple Slot",
                          multipleSlot,
                          (v) => setState(() => multipleSlot = v),
                        ),
                        if (multipleSlot)
                          CreateSlotsButton(
                            isLoading: _creatingForSlots,
                            onPressed: _createEventForSlots,
                          ),
                      ],
                    ),
                  ],

                  _check("Limit registration", limitRegistration, (v) {
                    setState(() {
                      limitRegistration = v;
                    });
                  }),

                  if (limitRegistration) ...[
                    _label("Registration Limit"),
                    Field(
                      controller: seatLimit,
                      hint: "Enter maximum seats",
                      keyboard: TextInputType.number,
                    ),
                  ],
                ]),

                _card("Event Organisation", [
                  _label("Organizer"),
                  MoboSingleSelectField<FetchModel>(
                    selected: selectedOrganiser,
                    selectedLabel: selectedOrganiser?.name,
                    hintText: 'Select organizer',
                    panelTitle: 'Select Organizer',
                    search: (q) => _searchOptions(
                      "res.partner",
                      q,
                      domain: [
                        '|',
                        ['company_id', '=', false],
                        ['company_id', 'parent_of', ''],
                      ],
                    ),
                    onChanged: (m) => setState(() => selectedOrganiser = m),
                  ),
                  _label("Responsible"),
                  MoboSingleSelectField<FetchModel>(
                    selected: responsible,
                    selectedLabel: responsible?.name,
                    hintText: 'Select responsible',
                    panelTitle: 'Select Responsible',
                    search: (q) => _searchOptions(
                      "res.users",
                      q,
                      domain: [
                        ['share', '=', false],
                      ],
                    ),
                    onChanged: (m) => setState(() => responsible = m),
                  ),

                  _label("Location"),
                  MoboSingleSelectField<FetchModel>(
                    selected: selectedLocation,
                    selectedLabel: selectedLocation?.name,
                    hintText: 'Select location',
                    panelTitle: 'Select Location',
                    search: (q) => _searchOptions(
                      "res.partner",
                      q,
                      domain: [
                        '|',
                        ['company_id', '=', false],
                        ['company_id', 'parent_of', ''],
                      ],
                    ),
                    onChanged: (m) => setState(() => selectedLocation = m),
                  ),

                  _label("Company"),
                  MoboSingleSelectField<FetchModel>(
                    selected: selectedCompany,
                    selectedLabel: selectedCompany?.name,
                    // An event without a company is visible to all of them.
                    hintText: 'Visible to all',
                    panelTitle: 'Select Company',
                    search: (q) => _searchOptions("res.company", q),
                    onChanged: (m) => setState(() => selectedCompany = m),
                  ),

                  // The event's kanban column. A short fixed list, so it opens
                  // as a plain list; an event always has a stage, so it can't
                  // be cleared.
                  if (provider.eventFields.containsKey('stage_id')) ...[
                    _label("Stage"),
                    MoboSingleSelectField<FetchModel>(
                      selected: selectedStage,
                      selectedLabel: selectedStage?.name,
                      hintText: 'Select stage',
                      panelTitle: 'Select Stage',
                      allowClear: false,
                      options: [
                        for (final stage
                            in context.watch<HomeProvider>().orderedStages)
                          MoboSelectOption(
                            value: FetchModel(id: stage.id, name: stage.name),
                            label: stage.name,
                          ),
                      ],
                      onChanged: (m) => setState(() => selectedStage = m),
                    ),
                  ],

                  if (provider.eventFields.containsKey('kanban_state')) ...[
                    _label("Status"),
                    EventStatusField(
                      value: kanbanState,
                      onChanged: (v) => setState(() => kanbanState = v),
                    ),
                  ],
                ]),
                _card("Template", [
                  _label("Event Template"),
                  MoboSingleSelectField<FetchModel>(
                    selected: selectedTemplate,
                    selectedLabel: selectedTemplate?.name,
                    hintText: 'Select template',
                    panelTitle: 'Select Template',
                    search: (q) => _searchOptions("event.type", q),
                    onChanged: (value) async {
                      // Clearing drops the template only; the defaults it
                      // filled in stay, as before.
                      if (value == null) {
                        setState(() => selectedTemplate = null);
                        return;
                      }
                      setState(() => selectedTemplate = value);

                      try {
                        templateLoading = true;

                        final result = await service.eventTemplate(
                          selectedTemplate!.id,
                        );

                        setState(() {
                          websiteSubMenu = result.websiteMenu;
                          boothRegister = result.boothMenu;
                          showcaseTrack = result.websiteTrack;
                          allowTrackProposal = result.websiteTrackProposal;
                          showcaseExhibitory = result.exhibitorMenu;
                          limitRegistration = result.hasSeatsLimitation;
                          seatLimit.text = result.seatsMax.toString();
                          templateLoading = false;
                        });
                      } catch (e) {
                        setState(() {
                          templateLoading = false;
                        });
                        final message = cleanedError(e.toString());
                        CustomSnackbar.showError(context, message);
                      }
                    },
                  ),
                ]),

                _card("Website Information", [
                  if (provider.eventFields.containsKey('website_menu')) ...[
                    _check("Website Sub menu", websiteSubMenu, (v) {
                      setState(() {
                        websiteSubMenu = v;

                        boothRegister = v;
                        showcaseTrack = v;
                        allowTrackProposal = v;
                        showcaseExhibitory = v;
                      });
                    }),
                  ],

                  if (provider.eventFields.containsKey('booth_menu')) ...[
                    _check(
                      "Booth register",
                      boothRegister,
                      (v) => setState(() => boothRegister = v),
                    ),
                  ],

                  if (provider.eventFields.containsKey('website_track')) ...[
                    _check("Show case Track", showcaseTrack, (v) {
                      setState(() {
                        showcaseTrack = v;
                        allowTrackProposal = v;
                      });
                    }),
                  ],

                  if (provider.eventFields.containsKey(
                    'website_track_proposal',
                  )) ...[
                    _check(
                      "Allow track proposal",
                      allowTrackProposal,
                      (v) => setState(() => allowTrackProposal = v),
                    ),
                  ],

                  if (provider.eventFields.containsKey('exhibitor_menu')) ...[
                    _check(
                      "Show case Exhibitory",
                      showcaseExhibitory,
                      (v) => setState(() => showcaseExhibitory = v),
                    ),
                  ],

                  _label("Website"),
                  MoboSingleSelectField<FetchModel>(
                    selected: selectedWebsite,
                    selectedLabel: selectedWebsite?.name,
                    hintText: 'Select website',
                    panelTitle: 'Select Website',
                    // Websites are listed per company, so one is needed first.
                    // Still enabled while a website is set, so one left over
                    // from a cleared company can be cleared too.
                    enabled: selectedCompany != null || selectedWebsite != null,
                    search: (q) async {
                      final companyId = selectedCompany?.id;
                      if (companyId == null) return [];
                      return _searchOptions(
                        "website",
                        q,
                        domain: [
                          '|',
                          ['company_id', '=', false],
                          ['company_id', '=', companyId],
                        ],
                      );
                    },
                    onChanged: (m) => setState(() => selectedWebsite = m),
                  ),

                  if (provider.eventFields.containsKey('website_published'))
                    PublishedToggle(
                      value: websitePublished,
                      onChanged: (v) => setState(() => websitePublished = v),
                    ),
                ]),
                _card("Event Tags", [
                  MoboMultiSelectField<FetchModel>(
                    // The chosen tags always show, even before (or without)
                    // the full list.
                    options: {...allTags, ...selectedTags}
                        .map(
                          (t) =>
                              MoboSelectOption(value: t, label: t.name ?? ''),
                        )
                        .toList(),
                    selected: selectedTags,
                    onChanged: (tags) => setState(() => selectedTags = tags),
                    hintText: 'Select tags',
                    panelTitle: 'Select Tags',
                  ),
                ]),
                _card("Links", [
                  _label("Visibility"),
                  MoboSingleSelectField<String>(
                    selected: selectedLabel,
                    options: visibilityTypes.keys
                        .map(
                          (label) =>
                              MoboSelectOption(value: label, label: label),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => selectedLabel = v);
                    },
                    allowClear: false,
                    hintText: 'Select visibility',
                  ),
                  if (selectedLocation == null) ...[
                    _label("Online Event Url"),
                    Field(
                      controller: onlineUrl,
                      hint: "https://",
                      keyboard: TextInputType.url,
                    ),
                  ],
                ]),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(isDark),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [AppShadows.cardShadow],
                  ),
                  // Nothing staged: no fixed height, so the panel is as tall as
                  // the header and the empty state and leaves no slack under
                  // the "Add Ticket" button (a fixed 300 clipped it, a fixed
                  // 400 left a gap). Once tickets are staged the list scrolls
                  // inside a 400 panel.
                  height: provider.dummyTicketList.isEmpty ? null : 400,
                  child: TicketLineWidget(eventId: 2, dummyTicket: true),
                ),
              ],
            ),
          ),
        );

        // The fields scroll; the submit button stays pinned below them (and
        // above the keyboard when it is open), so it never scrolls out of
        // reach. Only when the window is left too short for even that — a
        // phone on its side with the keyboard up — does the button scroll
        // along with the fields (PinnedFooterLayout).
        return PinnedFooterLayout(
          expandBody: true,
          scrollAllBelow: 200,
          body: fields,
          footer: PinnedActionBar(
            padding: EdgeInsets.fromLTRB(
              20,
              compact ? 8 : 12,
              20,
              compact ? 8 : 16,
            ),
            child: ConstrainedContent(
              maxWidth: maxWidth,
              // §5 — a fixed 48 (a touch less on a short window), as billing's
              // Create Invoice button, rather than padding that made it ~56.
              child: SizedBox(
                width: double.infinity,
                height: compact ? 44 : 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    disabledBackgroundColor: AppTheme.disabledButtonFillOn(isDark),
                    disabledForegroundColor: AppTheme.disabledButtonText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: isFormValid && !_creatingForSlots
                      ? () async {
                          final error = _validationError();
                          if (error != null) {
                            CustomSnackbar.showWarning(context, error);
                            return;
                          }
                          try {
                            loadingDialog(
                              context,
                              "Creating Event",
                              "Please wait while we create the event",
                              LoadingAnimationWidget.fourRotatingDots(
                                color: primaryColor,
                                size: 30,
                              ),
                            );

                            final provider =
                                Provider.of<EventDetailedProvider>(
                                  context,
                                  listen: false,
                                );
                            final payload = _buildPayload(provider);

                            final payloadFiltered = await provider
                                .buildSafePayload(payload);

                            await service.createEvent(vals: payloadFiltered);

                            provider.clearDummyTicket();

                            hideLoadingDialog(context);
                            CustomSnackbar.showSuccess(
                              context,
                              "Successfully Created Event",
                            );
                            ReviewService().trackSignificantEvent();
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HomeScaffold(),
                              ),
                              (route) => false,
                            );
                          } catch (e) {
                            hideLoadingDialog(context);
                            CustomSnackbar.showError(
                              context,
                              cleanedError(e.toString()),
                            );
                          }
                        }
                      : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedCalendarAdd01,
                        color: isFormValid
                            ? Colors.white
                            : AppTheme.disabledButtonText,
                        size: 25,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Create Event",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// §6 — field label: 14/w500 grey, matching mobo_fleet's form-field labels.
  /// §6 — field label. `isRequired` appends a red bold " *" via [FieldLabel]
  /// instead of baking the asterisk into the string (it needs its own colour).
  Widget _label(String t, {bool isRequired = false}) =>
      FieldLabel(t, isRequired: isRequired, bottomGap: AppTheme.labelGap);

  /// Form-section card — mirrors mobo_fleet's `vehicleInfoCard`: title,
  /// divider, padded children, radius 12, hairline border + card shadow.
  Widget _card(String h, List<Widget> c) => Builder(
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        // 16 between cards, and 16 of padding inside them (see formCardBody):
        // the rhythm of mobo Billing's create-invoice form.
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface(isDark),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppTheme.cardBorder(isDark), width: 0.5),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            formCardHeader(h, isDark),
            formCardBody(c),
          ],
        ),
      );
    },
  );
}
