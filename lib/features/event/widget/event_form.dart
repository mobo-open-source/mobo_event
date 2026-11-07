import 'dart:convert';
import 'published_toggle.dart';
import 'create_slots_button.dart';
import '../../../shared/widgets/toggles/mobo_checkbox.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/features/event/model/fetch_model.dart';
import 'package:mobo_event/features/event/pages/event_details_screen.dart';
import 'package:mobo_event/features/event/model/event_detailed_model.dart';
import 'package:mobo_event/features/event/services/event_detailed_services.dart';
import 'package:mobo_event/features/event/widget/field.dart';
import 'package:mobo_event/features/scheduler/provider/mail_scheduler_provider.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
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
import '../../../shared/widgets/shimmer_card/shimmer_card.dart';
import '../../home/providers/home_provider.dart';
import '../helper/time_zone.dart';
import '../provider/event_detailed_provider.dart';
import 'event_calender.dart';
import 'event_status_field.dart';
import '../helper/event_status.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pinned_action_bar.dart';
import '../../../core/utils/screen_layout.dart';

class EventForm extends StatefulWidget {
  const EventForm({super.key});

  @override
  State<EventForm> createState() => EventFormState();
}

class EventFormState extends State<EventForm> {
  final _formKey = GlobalKey<FormState>();
  final eventName = TextEditingController();
  final visibility = TextEditingController();
  final onlineUrl = TextEditingController();
  final fromDateController = TextEditingController();
  final toDateController = TextEditingController();
  final seatLimit = TextEditingController();
  Uint8List? fileBytes;
  PlatformFile? pickedFile;
  String? selectedTimezone;

  FetchModel? selectedOrganiser;
  FetchModel? selectedResPerson;
  FetchModel? selectedLocation;
  FetchModel? selectedCompany;
  FetchModel? selectedStage;

  /// The event's status (`kanban_state`): normal / done / blocked / cancel.
  String kanbanState = 'normal';
  FetchModel? selectedTemplate;
  FetchModel? selectedWebsite;
  List<FetchModel> selectedTags = [];

  /// Every event tag, loaded once for the tag multi-select.
  List<FetchModel> allTags = [];
  final services = EventDetailedServices();

  DateTime? fromDate;
  DateTime? toDate;

  bool multipleSlot = false;
  bool limitRegistration = false;

  bool websiteSubMenu = false;
  bool? boothRegister;
  bool? showcaseTrack;
  bool? allowTrackProposal;
  bool? showcaseExhibitory;

  /// `website_published`, and Odoo 20's `publish_on` (a scheduled publish,
  /// which locks the switch). Both come from the loaded event.
  bool websitePublished = false;
  DateTime? publishOn;
  bool isLoading = true;
  bool templateLoading = false;
  int slot = 0;

  /// True while the form is being saved ahead of the slot calendar; the Create
  /// Slots button spins and a second tap does nothing.
  bool _savingForSlots = false;

  bool get isFormValid =>
      eventName.text.trim().isNotEmpty &&
      (selectedTimezone ?? '').isNotEmpty &&
      fromDate != null &&
      toDate != null;

  /// What the form held once the event loaded. Update stays disabled until
  /// the current values differ from it.
  Map<String, Object?>? _initialValues;
  Uint8List? _initialImage;

  /// Every value Update writes, reduced to something `==` can compare.
  Map<String, Object?> _currentValues() => {
    'name': eventName.text.trim(),
    'organizer': selectedOrganiser?.id,
    'responsible': selectedResPerson?.id,
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
  };

  /// A new image is a new byte list, so identity is enough to spot a
  /// replaced or removed one without comparing the bytes.
  bool get hasChanges =>
      _initialValues != null &&
      (!mapEquals(_currentValues(), _initialValues) ||
          !identical(fileBytes, _initialImage));

  bool get canSubmit => isFormValid && hasChanges && !templateLoading;

  /// The publish write, only when the switch moved off what [loaded] holds —
  /// a save that leaves it alone must not touch publishing at all (the server
  /// checks the right to publish on any write that carries the field).
  Map<String, dynamic> _publishVals(EventDetailedModel? loaded) => {
    if (websitePublished != (loaded?.websitePublished ?? false))
      'website_published': websitePublished,
  };

  /// The status write — see [EventStatus.writeVals].
  Map<String, dynamic> _statusVals(EventDetailedModel? loaded) =>
      EventStatus.writeVals(
        current: kanbanState,
        loaded: loaded?.kanbanState,
        stageMoved:
            selectedStage != null && selectedStage!.id != loaded?.stageId,
      );

  /// Picking another stage shows the status the server will reset to — see
  /// [EventStatus.onStageChange].
  void _onStageChanged(FetchModel? stage) {
    setState(() {
      if (stage != null && stage.id != selectedStage?.id) {
        kanbanState = EventStatus.onStageChange(
          current: kanbanState,
          newStageId: stage.id,
          loadedStageId: _initialValues?['stage'] as int?,
          loadedState: _initialValues?['kanbanState'] as String? ?? kanbanState,
        );
      }
      selectedStage = stage;
    });
  }

  String selectedLabel = "Public";

  final Map<String, String> visibilityTypes = {
    "Public": "public",
    "Via a Link": "link",
    "Logged Users": "logged_users",
  };
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
    _loadAllTags();
    // Update compares these with what was loaded, so typing has to refresh it.
    seatLimit.addListener(() => setState(() {}));
    onlineUrl.addListener(() => setState(() {}));
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

  Future<List<FetchModel>> _loadTagsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];

    return services.getTypeHeadSearchListTags(
      model: "event.tag",
      domain: [
        ['id', 'in', ids],
      ],
    );
  }

  Future<void> _loadAllTags() async {
    try {
      final tags = await services.getTypeHeadSearchListTags(model: 'event.tag');
      if (!mounted) return;
      setState(() => allTags = tags);
    } catch (_) {
      // The field still lists the event's own tags; there is just nothing
      // new to offer.
    }
  }

  /// Server search behind a many2one picker: the [model] records matching
  /// the panel's search text, as select options.
  Future<List<MoboSelectOption<FetchModel>>> _searchOptions(
    String model,
    String query, {
    List domain = const [],
  }) async {
    final records = await services.getTypeHeadSearchList(
      model: model,
      search: query,
      domain: domain,
      limit: 20,
    );
    return records
        .map((m) => MoboSelectOption(value: m, label: m.name ?? ''))
        .toList();
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

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    try {
      final provider = Provider.of<EventDetailedProvider>(
        context,
        listen: false,
      );

      final update = provider.eventModel;
      if (update == null) return;

      await provider.fetchEventDetails(provider.eventModel!.id);
      final data = provider.eventModel;
      if (data == null) return;

      final loadedTags = data.tagIds != null && data.tagIds!.isNotEmpty
          ? await _loadTagsByIds(data.tagIds!.cast<int>())
          : <FetchModel>[];

      eventName.addListener(() => setState(() {}));

      isLoading = false;
      setState(() {
        eventName.text = data.name;
        if (data.organizerId != 0)
          selectedOrganiser = FetchModel(
            id: data.organizerId,
            name: data.organizerName,
          );
        if (data.userId != null)
          selectedResPerson = FetchModel(id: data.userId!, name: data.username);
        if (data.addressIds!.isNotEmpty)
          selectedLocation = FetchModel(
            id: data.addressIds![0],
            name: data.addressIds![1],
          );
        if (data.templateId != 0)
          selectedTemplate = FetchModel(
            id: data.templateId!,
            name: data.template,
          );
        if (data.stageId != 0) {
          selectedStage = FetchModel(id: data.stageId, name: data.stage);
        }
        kanbanState = EventStatus.orDefault(data.kanbanState);

        selectedTimezone = data.timezone;
        multipleSlot = data.isMultiSlots;
        limitRegistration = data.seatsLimited;
        websiteSubMenu = data.websiteMenu;
        boothRegister = data.boothMenu;
        showcaseTrack = data.websiteTrack;
        allowTrackProposal = data.websiteTrackProposal;
        showcaseExhibitory = data.exhibitoryMenu;
        websitePublished = data.websitePublished ?? false;
        publishOn = data.publishOn;
        fromDate = data.start;
        toDate = data.end;
        seatLimit.text = data.maxSeats.toString();
        onlineUrl.text = data.onlineUrl!.trim().isNotEmpty
            ? data.onlineUrl!
            : '';
        if (data.company!.isNotEmpty)
          selectedCompany = FetchModel(
            id: data.company![0],
            name: data.company![1],
          );

        if (data.website!.isNotEmpty) {
          selectedWebsite = FetchModel(
            id: data.website![0],
            name: data.website![1],
          );
        }
        if (data.image != null) fileBytes = data.image;
        slot = data.slotCount;
        selectedTags = loadedTags;
        selectedLabel = visibilityTypes.entries
            .firstWhere(
              (e) => e.value == data.visibility,
              orElse: () => visibilityTypes.entries.first,
            )
            .key;

        if (fromDate != null) {
          fromDateController.text = _format(fromDate!);
        }
        if (toDate != null) {
          toDateController.text = _format(toDate!);
        }
        _initialValues = _currentValues();
        _initialImage = fileBytes;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    eventName.dispose();
    visibility.dispose();
    onlineUrl.dispose();
    seatLimit.dispose();
    fromDateController.dispose();
    toDateController.dispose();
    super.dispose();
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
            child: Form(
              key: _formKey,
              // Only the first load swaps in the shimmer. Template defaults
              // load in place — replacing the form would jump it back to the
              // top mid-edit — and just hold Update off until they land.
              child: isLoading
                  ? ListView(
                      shrinkWrap: true,

                      children: const [
                        FullCardShimmer(height: 100),
                        SizedBox(height: 10),
                        FullCardShimmer(height: 300),
                        SizedBox(height: 10),
                        FullCardShimmer(height: 400),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _card("Event Information", [
                          _label("Event Name", isRequired: true),

                          Field(
                            controller: eventName,
                            hint: "Enter your event name",
                          ),

                          if (provider.eventFields.containsKey(
                            'image_1024',
                          )) ...[
                            _label("Event Image"),
                            if (fileBytes == null)
                              _uploadButton()
                            else
                              _imagePreview(),
                          ],

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
                            onChanged: (m) =>
                                setState(() => selectedOrganiser = m),
                          ),

                          _label("Responsible"),
                          MoboSingleSelectField<FetchModel>(
                            selected: selectedResPerson,
                            selectedLabel: selectedResPerson?.name,
                            hintText: 'Select responsible',
                            panelTitle: 'Select Responsible',
                            search: (q) => _searchOptions(
                              "res.users",
                              q,
                              domain: [
                                ['share', '=', false],
                              ],
                            ),
                            onChanged: (m) =>
                                setState(() => selectedResPerson = m),
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
                            onChanged: (m) =>
                                setState(() => selectedLocation = m),
                          ),

                          _label("Company"),
                          MoboSingleSelectField<FetchModel>(
                            selected: selectedCompany,
                            selectedLabel: selectedCompany?.name,
                            // An event without a company is visible to all of
                            // them.
                            hintText: 'Visible to all',
                            panelTitle: 'Select Company',
                            search: (q) => _searchOptions("res.company", q),
                            onChanged: (m) =>
                                setState(() => selectedCompany = m),
                          ),

                          // The event's kanban column. A short fixed list, so
                          // it opens as a plain list; an event always has a
                          // stage, so it can't be cleared.
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
                                    in context
                                        .watch<HomeProvider>()
                                        .orderedStages)
                                  MoboSelectOption(
                                    value: FetchModel(
                                      id: stage.id,
                                      name: stage.name,
                                    ),
                                    label: stage.name,
                                  ),
                              ],
                              onChanged: _onStageChanged,
                            ),
                          ],

                          if (provider.eventFields.containsKey(
                            'kanban_state',
                          )) ...[
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
                              // Clearing drops the template only; the defaults
                              // it filled in stay, as before.
                              if (value == null) {
                                setState(() => selectedTemplate = null);
                                return;
                              }
                              setState(() => selectedTemplate = value);

                              try {
                                templateLoading = true;

                                final result = await services.eventTemplate(
                                  selectedTemplate!.id,
                                );

                                setState(() {
                                  websiteSubMenu = result.websiteMenu;
                                  boothRegister = result.boothMenu;
                                  showcaseTrack = result.websiteTrack;
                                  allowTrackProposal =
                                      result.websiteTrackProposal;
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
                        _card("Schedule", [
                          _label("Time zone", isRequired: true),
                          MoboSingleSelectField<String>(
                            selected: selectedTimezone,
                            // Still names a zone the list lacks, as the old
                            // picker did.
                            selectedLabel: selectedTimezone,
                            options: odooTimezones
                                .map(
                                  (zone) => MoboSelectOption(
                                    value: zone,
                                    label: zone,
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => selectedTimezone = v),
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

                          if (provider.eventFields.containsKey('is_multi_slots')) ...[
                            // The toggle and its Create Slots button are one group, so no form
                            // gap opens between them (same as the create-event form).
                            FormToggleGroup(
                              children: [
                                _check(
                                  "Multiple Slot",
                                  multipleSlot,
                                  (v) => setState(() => multipleSlot = v),
                                ),
                                if (multipleSlot)
                                  CreateSlotsButton(
                                    count: slot,
                                    isLoading: _savingForSlots,
                                    onPressed: _saveForSlots,
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
                        _card("Website Information", [
                          if (provider.eventFields.containsKey(
                            'website_menu',
                          )) ...[
                            _check("Website Sub menu", websiteSubMenu, (v) {
                              setState(() {
                                websiteSubMenu = v;

                                if (boothRegister != null) boothRegister = v;
                                if (showcaseTrack != null) showcaseTrack = v;
                                if (allowTrackProposal != null)
                                  allowTrackProposal = v;
                                if (showcaseExhibitory != null)
                                  showcaseExhibitory = v;
                              });
                            }),
                          ],

                          if (provider.eventFields.containsKey(
                            'booth_menu',
                          )) ...[
                            if (boothRegister != null)
                              _check(
                                "Booth register",
                                boothRegister!,
                                (v) => setState(() => boothRegister = v),
                              ),
                          ],

                          if (provider.eventFields.containsKey(
                            'website_track',
                          )) ...[
                            if (showcaseTrack != null)
                              _check("Show case Track", showcaseTrack!, (v) {
                                setState(() {
                                  showcaseTrack = v;
                                  allowTrackProposal = v;
                                });
                              }),
                          ],

                          if (provider.eventFields.containsKey(
                            'website_track_proposal',
                          )) ...[
                            if (allowTrackProposal != null)
                              _check(
                                "Allow track proposal",
                                allowTrackProposal!,
                                (v) => setState(() => allowTrackProposal = v),
                              ),
                          ],

                          if (provider.eventFields.containsKey(
                            'exhibitor_menu',
                          )) ...[
                            if (showcaseExhibitory != null)
                              _check(
                                "Show case Exhibitory",
                                showcaseExhibitory!,
                                (v) => setState(() => showcaseExhibitory = v),
                              ),
                          ],

                          _label("Website"),
                          MoboSingleSelectField<FetchModel>(
                            selected: selectedWebsite,
                            selectedLabel: selectedWebsite?.name,
                            hintText: 'Select website',
                            panelTitle: 'Select Website',
                            // Websites are listed per company, so one is
                            // needed first.
                            // Still enabled while a website is set, so one left
                            // over from a cleared company can be cleared too.
                            enabled:
                                selectedCompany != null ||
                                selectedWebsite != null,
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
                            onChanged: (m) =>
                                setState(() => selectedWebsite = m),
                          ),

                          if (provider.eventFields.containsKey(
                            'website_published',
                          ))
                            PublishedToggle(
                              value: websitePublished,
                              scheduledOn: publishOn,
                              onChanged: (v) =>
                                  setState(() => websitePublished = v),
                            ),
                        ]),
                        _card("Event Tags", [
                          MoboMultiSelectField<FetchModel>(
                            // The chosen tags always show, even before (or
                            // without) the full list.
                            options: {...allTags, ...selectedTags}
                                .map(
                                  (t) => MoboSelectOption(
                                    value: t,
                                    label: t.name ?? '',
                                  ),
                                )
                                .toList(),
                            selected: selectedTags,
                            onChanged: (tags) =>
                                setState(() => selectedTags = tags),
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
                                  (label) => MoboSelectOption(
                                    value: label,
                                    label: label,
                                  ),
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
                      ],
                    ),
            ),
          ),
        );

        // The fields scroll; the submit button stays pinned below them (and
        // above the keyboard when it is open), so it never scrolls out of
        // reach. Only when the window is left too short for even that — a
        // phone on its side with the keyboard up — does the button scroll
        // along with the fields (PinnedFooterLayout).
        if (isLoading) return SingleChildScrollView(child: fields);
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
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    disabledBackgroundColor: AppTheme.disabledButtonFillOn(isDark),
                    disabledForegroundColor: AppTheme.disabledButtonText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: compact ? 12 : 15,
                    ),
                  ),
                  onPressed: canSubmit
                      ? () async {
                          if (!_formKey.currentState!.validate()) return;

                          try {
                            loadingDialog(
                              context,
                              "Updating Event",
                              "Please wait while we Updating Event",
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

                            Map<String, dynamic> payload = {
                              'name': eventName.text.trim(),
                              'organizer_id': selectedOrganiser != null
                                  ? selectedOrganiser!.id
                                  : false,
                              'user_id': selectedResPerson != null
                                  ? selectedResPerson!.id
                                  : false,
                              'address_id': selectedLocation != null
                                  ? selectedLocation!.id
                                  : false,
                              'company_id': selectedCompany != null
                                  ? selectedCompany!.id
                                  : false,
                              'tag_ids': [
                                [
                                  6,
                                  0,
                                  selectedTags.map((e) => e.id).toList(),
                                ],
                              ],
                              'is_multi_slots': multipleSlot,
                              'date_begin': toOdooDateTime(fromDate!),
                              'date_end': toOdooDateTime(toDate!),
                              'website_menu': websiteSubMenu,
                              'booth_menu': boothRegister ?? false,
                              'website_track': showcaseTrack ?? false,
                              'website_track_proposal':
                                  allowTrackProposal ?? false,
                              'exhibitor_menu': showcaseExhibitory ?? false,
                              ..._publishVals(provider.eventModel),
                              ..._statusVals(provider.eventModel),
                              'date_tz': selectedTimezone ?? false,
                              'seats_limited': limitRegistration,
                              'seats_max': seatLimit.text,
                              'website_visibility':
                                  visibilityTypes[selectedLabel],
                              'event_url': onlineUrl.text,
                              'image_1024': fileBytes != null
                                  ? base64Encode(fileBytes!)
                                  : false,
                              if (selectedWebsite == null)
                                'website_id': false
                              else if (selectedWebsite!.id !=
                                  (provider.eventModel?.website?.isNotEmpty ==
                                          true
                                      ? provider.eventModel!.website![0]
                                      : null))
                                'website_id': selectedWebsite!.id,
                              // Only when the stage actually changed:
                              // Odoo 17 and 18 reset the event's kanban
                              // state (blocked / ready) on any write that
                              // carries stage_id, even the same one.
                              if (selectedStage != null &&
                                  selectedStage!.id !=
                                      provider.eventModel?.stageId)
                                'stage_id': selectedStage!.id,
                              if (selectedTemplate?.id != null &&
                                  provider.eventModel?.templateId !=
                                      selectedTemplate!.id)
                                'event_type_id': selectedTemplate!.id
                              else if (selectedTemplate?.id == null &&
                                  provider.eventModel?.templateId != 0)
                                'event_type_id': false,
                            };

                            final payloadFiltered = await provider
                                .buildSafePayload(payload);

                            await services.editEventDetails(
                              eventId: provider.eventModel!.id,
                              vals: payloadFiltered,
                            );
                            await provider.fetchEventDetails(
                              provider.eventModel!.id,
                            );
                            Provider.of<MailSchedulerProvider>(
                              context,
                              listen: false,
                            ).reset();

                            final homeProvider = Provider.of<HomeProvider>(
                              context,
                              listen: false,
                            );
                            await homeProvider.gettingStages();
                            hideLoadingDialog(context);
                            CustomSnackbar.showSuccess(
                              context,
                              "Successfully updated",
                            );

                            EventDetailsScreen.openFresh(
                              context,
                              provider.eventModel!.id,
                            );
                          } catch (e) {
                            hideLoadingDialog(context);
                            final message = cleanedError(e.toString());
                            CustomSnackbar.showError(context, message);
                          }
                        }
                      : null,
                  child: Text(
                    "Update Event",
                    style: TextStyle(fontWeight: FontWeight.bold),
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

  /// Slots need a saved event, so what is on the form is saved first, then the
  /// slot calendar replaces this screen. While that runs the Create Slots
  /// button spins and ignores taps — no blocking dialog over the form.
  Future<void> _saveForSlots() async {
    if (_savingForSlots) return;
    // Checked before the confirmation opens, so an invalid form is reported
    // straight away instead of after the user has agreed to save it.
    if (!isFormValid) {
      CustomSnackbar.showWarning(
        context,
        "Please ensure all required fields are filled.",
      );
      return;
    }
    if (toDate!.isBefore(fromDate!)) {
      CustomSnackbar.showWarning(
        context,
        "The end date cannot be earlier than the start date.",
      );
      return;
    }
    try {
      bool confirm = await showBackDialog(
        context,
        title: 'Add Slots',
        subtitle:
            "Your changes will be saved before you can add slots. Do you want to continue?",
        leftButtonName: "Cancel",
        rightButtonName: "Save",
        function: () {
          Navigator.pop(context, true);
        },
      );

      if (confirm) {
        setState(() => _savingForSlots = true);

        tz.initializeTimeZones();

        final provider =
            Provider.of<EventDetailedProvider>(
              context,
              listen: false,
            );
        Map<String, dynamic> payload = {
          'name': eventName.text.trim(),
          'organizer_id':
              selectedOrganiser != null
              ? selectedOrganiser!.id
              : false,
          'user_id': selectedResPerson != null
              ? selectedResPerson!.id
              : false,
          'address_id': selectedLocation != null
              ? selectedLocation!.id
              : false,
          'company_id': selectedCompany != null
              ? selectedCompany!.id
              : false,
          'date_tz': selectedTimezone ?? false,
          'tag_ids': [
            [
              6,
              0,
              selectedTags
                  .map((e) => e.id)
                  .toList(),
            ],
          ],
          'is_multi_slots': multipleSlot,
          'date_begin': toOdooDateTime(fromDate!),
          'date_end': toOdooDateTime(toDate!),
          'website_menu': websiteSubMenu,
          'booth_menu': boothRegister,
          'website_track': showcaseTrack,
          'website_track_proposal':
              allowTrackProposal,
          'exhibitor_menu': showcaseExhibitory,
          ..._publishVals(provider.eventModel),
          'seats_limited': limitRegistration,
          'seats_max': seatLimit.text,
          if (selectedWebsite == null)
            'website_id': false
          else if (selectedWebsite!.id !=
              (provider
                          .eventModel
                          ?.website
                          ?.isNotEmpty ==
                      true
                  ? provider
                        .eventModel!
                        .website![0]
                  : null))
            'website_id': selectedWebsite!.id,
          'website_visibility':
              visibilityTypes[selectedLabel],
          'event_url': onlineUrl.text,
          'image_1024': fileBytes != null
              ? base64Encode(fileBytes!)
              : false,
          if (selectedTemplate?.id != null &&
              provider.eventModel?.templateId !=
                  selectedTemplate!.id)
            'event_type_id': selectedTemplate!.id
          else if (selectedTemplate?.id == null &&
              provider.eventModel?.templateId !=
                  0)
            'event_type_id': false,
        };

        final payloadFiltered = await provider
            .buildSafePayload(payload);

        await services.editEventDetails(
          eventId: provider.eventModel!.id,
          vals: payloadFiltered,
        );

        await provider.fetchEventDetails(
          provider.eventModel!.id,
        );

        tz.Location location;
        try {
          location = tz.getLocation(
            provider.eventModel!.timezone,
          );
        } catch (_) {
          location = tz.getLocation('UTC');
        }

        final utcStart = provider
            .eventModel!
            .start
            .toUtc();
        final utcEnd = provider.eventModel!.end
            .toUtc();

        final from = tz.TZDateTime.from(
          utcStart,
          location,
        );
        final to = tz.TZDateTime.from(
          utcEnd,
          location,
        );

        if (!mounted) return;
        // Replaces this screen: the calendar's
        // back button returns to a fresh Edit
        // screen, so keeping this one below
        // would stack two edit screens.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CalendarScreen(
              eventId: provider.eventModel!.id,
              fromDate: from,
              toDate: to,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingForSlots = false);
      CustomSnackbar.showError(
        context,
        cleanedError(e.toString()),
      );
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
}
