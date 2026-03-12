import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/features/event/model/fetch_model.dart';
import 'package:mobo_event/features/event/pages/event_details_screen.dart';
import 'package:mobo_event/features/event/services/event_detailed_services.dart';
import 'package:mobo_event/features/event/widget/field.dart';
import 'package:mobo_event/features/event/widget/time_zone/time_zone.dart';
import 'package:mobo_event/features/scheduler/provider/mail_scheduler_provider.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/standalone.dart' as tz;
import '../../../core/const/app_colors.dart';
import '../../../shared/helper/helper_method.dart';
import '../../../shared/widgets/back_dialog/show_back_dialog.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../../../shared/widgets/shimmer_card/shimmer_card.dart';
import '../../home/providers/home_provider.dart';
import '../helper/time_zone.dart';
import '../provider/event_detailed_provider.dart';
import 'event_calender.dart';

class EventForm extends StatefulWidget {
  const EventForm({super.key});

  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  final _formKey = GlobalKey<FormState>();
  final eventName = TextEditingController();
  final organizer = TextEditingController();
  final responsible = TextEditingController();
  final location = TextEditingController();
  final company = TextEditingController();
  final template = TextEditingController();
  final website = TextEditingController();
  final tags = TextEditingController();
  final visibility = TextEditingController();
  final onlineUrl = TextEditingController();
  final fromDateController = TextEditingController();
  final toDateController = TextEditingController();
  final seatLimit = TextEditingController();
  final SuggestionsController<FetchModel> suggestionsController =
      SuggestionsController<FetchModel>();
  Uint8List? fileBytes;
  PlatformFile? pickedFile;
  String? selectedTimezone;

  FetchModel? selectedOrganiser;
  FetchModel? selectedResPerson;
  FetchModel? selectedLocation;
  FetchModel? selectedCompany;
  FetchModel? selectedTemplate;
  FetchModel? selectedWebsite;
  List<FetchModel> selectedTags = [];
  final FocusNode tagFocusNode = FocusNode();
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
  bool isLoading = true;
  bool templateLoading = false;
  int slot = 0;

  bool get isFormValid => eventName.text.trim().isNotEmpty;

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
    location.addListener(() {
      setState(() {});
    });
    tags.addListener(() {
      setState(() {});
    });
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
    return InkWell(
      onTap: pickBackground,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: fillColor,
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedFileUpload,
                color: Colors.black,
              ),
              SizedBox(width: 8),
              Text("Upload Image", style: TextStyle(color: Colors.black)),
            ],
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
            IconButton(onPressed: pickBackground, icon: Icon(Icons.edit)),
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
        organizer.text = data.organizerName;
        if (data.organizerId != 0)
          selectedOrganiser = FetchModel(
            id: data.organizerId,
            name: data.organizerName,
          );
        responsible.text = data.username ?? "";
        if (data.userId != null)
          selectedResPerson = FetchModel(id: data.userId!, name: data.username);
        location.text = data.location;
        if (data.addressIds!.isNotEmpty)
          selectedLocation = FetchModel(
            id: data.addressIds![0],
            name: data.addressIds![1],
          );
        template.text = data.template;
        if (data.templateId != 0)
          selectedTemplate = FetchModel(
            id: data.templateId!,
            name: data.template,
          );

        selectedTimezone = data.timezone;
        multipleSlot = data.isMultiSlots;
        limitRegistration = data.seatsLimited;
        websiteSubMenu = data.websiteMenu;
        boothRegister = data.boothMenu;
        showcaseTrack = data.websiteTrack;
        allowTrackProposal = data.websiteTrackProposal;
        showcaseExhibitory = data.exhibitoryMenu;
        fromDate = data.start;
        toDate = data.end;
        seatLimit.text = data.maxSeats.toString();
        onlineUrl.text = data.onlineUrl!.trim().isNotEmpty
            ? data.onlineUrl!
            : '';
        if (data.company!.isNotEmpty) company.text = data.company![1];
        if (data.company!.isNotEmpty)
          selectedCompany = FetchModel(
            id: data.company![0],
            name: data.company![1],
          );

        if (data.website!.isNotEmpty) {
          if (data.website!.isNotEmpty) website.text = data.website![1];
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
      });
    } catch (e) {}
  }

  @override
  void dispose() {
    eventName.dispose();
    organizer.dispose();
    responsible.dispose();
    location.dispose();
    company.dispose();
    template.dispose();
    website.dispose();
    tags.dispose();
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
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
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
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
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
    return Consumer<EventDetailedProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: isLoading || templateLoading
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
                        _label("Event Name"),

                        Field(
                          controller: eventName,
                          hint: "Enter your event name",
                        ),

                        if (provider.eventFields.containsKey('image_1024')) ...[
                          _label("Event Image"),
                          if (fileBytes == null)
                            _uploadButton()
                          else
                            _imagePreview(),
                        ],

                        _label("Organizer"),

                        TypeAheadField<FetchModel>(
                          controller: organizer,
                          debounceDuration: const Duration(milliseconds: 300),

                          suggestionsCallback: (value) async {
                            return services.getTypeHeadSearchList(
                              model: "res.partner",
                              search: value,
                              domain: [
                                '|',
                                ['company_id', '=', false],
                                ['company_id', 'parent_of', ''],
                              ],
                            );
                          },
                          emptyBuilder: (context) => Container(
                            width: double.infinity,
                            height: 100,
                            color: Colors.white,
                            padding: const EdgeInsets.all(12),
                            child: Center(
                              child: const Text("No organisation found"),
                            ),
                          ),
                          loadingBuilder: (context) => Container(
                            width: double.infinity,
                            height: 100,
                            color: Colors.white,
                            child: Center(child: CircularProgressIndicator()),
                          ),

                          itemBuilder: (context, s) => Container(
                            color: Colors.white,
                            child: ListTile(title: Text(s.name!)),
                          ),

                          onSelected: (value) {
                            organizer.text = value.name!;
                            selectedOrganiser = value;
                          },

                          builder: (context, controller, focusNode) {
                            return Field(
                              controller: controller,
                              focusNode: focusNode,
                              readOnly: selectedOrganiser != null,
                              hint: "Search organisation",
                              suffixIcon: selectedOrganiser != null
                                  ? IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        setState(() {
                                          organizer.clear();
                                          selectedOrganiser = null;
                                        });
                                      },
                                    )
                                  : null,
                            );
                          },
                        ),

                        _label("Responsible"),
                        TypeAheadField<FetchModel>(
                          controller: responsible,
                          debounceDuration: const Duration(milliseconds: 300),
                          suggestionsCallback: (value) async {
                            return services.getTypeHeadSearchList(
                              model: "res.users",
                              search: value,
                              domain: [
                                ['share', '=', false],
                              ],
                            );
                          },
                          emptyBuilder: (context) => Container(
                            width: double.infinity,
                            height: 100,
                            color: Colors.white,
                            padding: const EdgeInsets.all(12),
                            child: Center(child: const Text("No person found")),
                          ),
                          loadingBuilder: (context) => Container(
                            width: double.infinity,
                            height: 100,
                            color: Colors.white,
                            child: Center(child: CircularProgressIndicator()),
                          ),

                          itemBuilder: (context, s) => Container(
                            color: Colors.white,
                            child: ListTile(title: Text(s.name!)),
                          ),

                          onSelected: (value) {
                            responsible.text = value.name!;
                            selectedResPerson = value;
                          },

                          builder: (context, controller, focusNode) {
                            return Field(
                              controller: controller,
                              focusNode: focusNode,
                              readOnly: selectedResPerson != null,
                              hint: "Search Responsible person",
                              suffixIcon: selectedResPerson != null
                                  ? IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        setState(() {
                                          responsible.clear();
                                          selectedResPerson = null;
                                        });
                                      },
                                    )
                                  : null,
                            );
                          },
                        ),

                        _label("Location"),
                        TypeAheadField<FetchModel>(
                          controller: location,
                          debounceDuration: const Duration(milliseconds: 300),
                          suggestionsCallback: (value) async {
                            return services.getTypeHeadSearchList(
                              model: "res.partner",
                              search: value,
                              domain: [
                                '|',
                                ['company_id', '=', false],
                                ['company_id', 'parent_of', ''],
                              ],
                            );
                          },
                          emptyBuilder: (context) => Container(
                            width: double.infinity,
                            height: 100,
                            color: Colors.white,
                            padding: const EdgeInsets.all(12),
                            child: Center(
                              child: const Text("No location found"),
                            ),
                          ),
                          loadingBuilder: (context) => Container(
                            width: double.infinity,
                            height: 100,
                            color: Colors.white,
                            child: Center(child: CircularProgressIndicator()),
                          ),

                          itemBuilder: (context, s) => Container(
                            color: Colors.white,
                            child: ListTile(title: Text(s.name!)),
                          ),

                          onSelected: (value) {
                            location.text = value.name!;
                            selectedLocation = value;
                          },

                          builder: (context, controller, focusNode) {
                            return Field(
                              controller: controller,
                              focusNode: focusNode,
                              readOnly: selectedLocation != null,
                              hint: "Search Location",
                              suffixIcon: selectedLocation != null
                                  ? IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        setState(() {
                                          location.clear();
                                          selectedLocation = null;
                                        });
                                      },
                                    )
                                  : null,
                            );
                          },
                        ),

                        _label("Company"),
                        TypeAheadField<FetchModel>(
                          controller: company,
                          debounceDuration: const Duration(milliseconds: 300),
                          suggestionsCallback: (value) async {
                            return services.getTypeHeadSearchList(
                              model: "res.company",
                              search: value,
                            );
                          },
                          emptyBuilder: (context) => Container(
                            width: double.infinity,
                            height: 100,
                            color: Colors.white,
                            padding: const EdgeInsets.all(12),
                            child: Center(
                              child: const Text("No Company found"),
                            ),
                          ),
                          loadingBuilder: (context) => Container(
                            width: double.infinity,
                            height: 100,
                            color: Colors.white,
                            child: Center(child: CircularProgressIndicator()),
                          ),

                          itemBuilder: (context, s) => Container(
                            color: Colors.white,
                            child: ListTile(title: Text(s.name!)),
                          ),

                          onSelected: (value) {
                            company.text = value.name!;
                            selectedCompany = value;
                          },

                          builder: (context, controller, focusNode) {
                            return Field(
                              controller: controller,
                              focusNode: focusNode,
                              hint: "Visible to all",
                              readOnly: selectedCompany != null,
                              suffixIcon: selectedCompany != null
                                  ? IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        setState(() {
                                          company.clear();
                                          selectedCompany = null;
                                        });
                                      },
                                    )
                                  : null,
                            );
                          },
                        ),
                      ]),
                      _card("Template", [
                        _label("Event Template"),
                        TypeAheadField<FetchModel>(
                          controller: template,
                          debounceDuration: const Duration(milliseconds: 300),
                          suggestionsCallback: (value) async {
                            return services.getTypeHeadSearchList(
                              model: "event.type",
                              search: value,
                            );
                          },
                          emptyBuilder: (context) => Container(
                            width: double.infinity,
                            height: 100,
                            color: Colors.white,
                            padding: const EdgeInsets.all(12),
                            child: Center(
                              child: const Text("No Template found"),
                            ),
                          ),
                          loadingBuilder: (context) => Container(
                            width: double.infinity,
                            height: 100,
                            color: Colors.white,
                            child: Center(child: CircularProgressIndicator()),
                          ),

                          itemBuilder: (context, s) => Container(
                            color: Colors.white,
                            child: ListTile(title: Text(s.name!)),
                          ),

                          onSelected: (value) async {
                            template.text = value.name!;
                            selectedTemplate = value;

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

                          builder: (context, controller, focusNode) {
                            return Field(
                              controller: controller,
                              focusNode: focusNode,
                              readOnly: selectedTemplate != null,
                              hint: "Select your template",
                              suffixIcon: selectedTemplate != null
                                  ? IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        setState(() {
                                          template.clear();
                                          selectedTemplate = null;
                                        });
                                      },
                                    )
                                  : null,
                            );
                          },
                        ),
                      ]),
                      _card("Schedule", [
                        _label("Time zone *"),
                        SearchableTimezoneDropdown(
                          timezones: odooTimezones,
                          value: selectedTimezone,
                          onChanged: (value) {
                            setState(() {
                              selectedTimezone = value;
                            });
                          },
                        ),
                        _label("From Date & Time"),
                        _dateField(fromDateController, () async {
                          await pickDateTime(true);
                        }),

                        _label("To Date & Time"),
                        _dateField(toDateController, () async {
                          await pickDateTime(false);
                        }),

                        if (provider.eventFields.containsKey(
                          'is_multi_slots',
                        )) ...[
                          _check(
                            "Multiple Slot",
                            multipleSlot,
                            (v) => setState(() => multipleSlot = v),
                          ),

                          if (multipleSlot) ...[
                            InkWell(
                              onTap: () async {

                                try {
                                  bool confirm = await showBackDialog(
                                    context,
                                    title: 'Slot Page',
                                    subtitle:
                                        "Please save the event before adding slots. Are you sure you want to go to the slot page?",
                                    leftButtonName: "Cancel",
                                    rightButtonName: "Save",
                                    function: () {
                                      Navigator.pop(context, true);
                                    },
                                  );

                                  if (confirm) {
                                    if (isFormValid) {
                                      loadingDialog(
                                        context,
                                        "Updating Event",
                                        "Please wait while we Updating Event",
                                        LoadingAnimationWidget.fourRotatingDots(
                                          color: primaryColor,
                                          size: 30,
                                        ),
                                      );

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

                                      var location = tz.getLocation(
                                        provider.eventModel!.timezone,
                                      );

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

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CalendarScreen(
                                            eventId: provider.eventModel!.id,
                                            fromDate: from,
                                            toDate: to,
                                          ),
                                        ),
                                      );
                                    } else {
                                      hideLoadingDialog(context);
                                      CustomSnackbar.showWarning(
                                        context,
                                        "Please ensure all required fields are filled.",
                                      );
                                    }
                                  }
                                } catch (e) {
                                  hideLoadingDialog(context);
                                  CustomSnackbar.showError(
                                    context,
                                    cleanedError(e.toString()),
                                  );
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: fillColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text("$slot slots are available"),
                                ),
                              ),
                            ),
                          ],
                        ],

                        _check("Limit registration", limitRegistration, (v) {
                          setState(() {
                            limitRegistration = v;
                          });
                        }),

                        if (limitRegistration) ...[
                          const SizedBox(height: 8),
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

                        if (provider.eventFields.containsKey('booth_menu')) ...[
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
                        TypeAheadField<FetchModel>(
                          controller: website,
                          debounceDuration: const Duration(milliseconds: 300),
                          emptyBuilder: (context) => Container(
                            width: double.infinity,
                            height: 100,
                            color: Colors.white,
                            padding: const EdgeInsets.all(12),
                            child: Center(
                              child: const Text("No Website  found"),
                            ),
                          ),
                          loadingBuilder: (context) => Container(
                            width: double.infinity,
                            height: 100,
                            color: Colors.white,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          suggestionsCallback: (value) async {
                            if (selectedCompany == null) {
                              return [];
                            }

                            final id = selectedCompany!.id;

                            return services.getTypeHeadSearchList(
                              model: "website",
                              search: value,
                              domain: [
                                '|',
                                ['company_id', '=', false],
                                ['company_id', '=', id],
                              ],
                            );
                          },

                          itemBuilder: (context, s) => Container(
                            color: Colors.white,
                            child: ListTile(title: Text(s.name!)),
                          ),

                          onSelected: (value) {
                            website.text = value.name!;
                            selectedWebsite = value;
                          },

                          builder: (context, controller, focusNode) {
                            return Field(
                              controller: controller,
                              focusNode: focusNode,
                              hint: "Select your website",
                              readOnly: selectedWebsite != null,
                              suffixIcon: selectedWebsite != null
                                  ? IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        setState(() {
                                          website.clear();
                                          selectedWebsite = null;
                                        });
                                      },
                                    )
                                  : null,
                            );
                          },
                        ),
                      ]),
                      _card("Event Tags", [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: selectedTags.map((tag) {
                            return Chip(
                              label: Text(tag.name!),
                              deleteIcon: const Icon(Icons.close),
                              onDeleted: () {
                                setState(() {
                                  selectedTags.remove(tag);
                                });
                                suggestionsController.refresh();
                              },
                            );
                          }).toList(),
                        ),
                        TypeAheadField<FetchModel>(
                          controller: tags,
                          focusNode: tagFocusNode,
                          suggestionsController: suggestionsController,
                          constraints: const BoxConstraints(maxHeight: 200),

                          decorationBuilder: (context, child) {
                            return Material(
                              elevation: 1,
                              color: Colors.white,
                              child: child,
                            );
                          },

                          suggestionsCallback: (value) async {
                            return services.getTypeHeadSearchTagList(
                              model: "event.tag",
                              search: value.trim(),
                              domain: selectedTags.isNotEmpty
                                  ? [
                                      [
                                        'id',
                                        'not in',
                                        selectedTags.map((s) => s.id).toList(),
                                      ],
                                    ]
                                  : [],
                            );
                          },

                          onSelected: (suggestion) {
                            setState(() {
                              selectedTags.add(suggestion);
                            });
                            tags.clear();
                            suggestionsController.refresh();
                            tagFocusNode.requestFocus();
                          },
                          listBuilder: (context, children) {
                            return Scrollbar(
                              thickness: 3,
                              radius: const Radius.circular(6),
                              thumbVisibility: true,
                              child: ListView(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                children: children,
                              ),
                            );
                          },

                          itemBuilder: (context, suggestion) {
                            return ListTile(
                              dense: true,
                              title: Text(suggestion.name ?? ""),
                            );
                          },

                          emptyBuilder: (context) => Material(
                            color: Colors.white,
                            child: const SizedBox(
                              height: 80,
                              child: Center(child: Text("No tags found")),
                            ),
                          ),

                          loadingBuilder: (context) => Material(
                            color: Colors.white,
                            child: const SizedBox(
                              height: 80,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          ),

                          builder: (context, controller, focusNode) {
                            return Field(
                              controller: controller,
                              focusNode: focusNode,
                              hint: "Culture, music, tech...",
                            );
                          },
                        ),
                      ]),
                      _card("Links", [
                        _label("Visibility"),
                        DropdownButtonFormField<String>(
                          dropdownColor: Colors.white,
                          isExpanded: true,
                          value: visibilityTypes.containsKey(selectedLabel)
                              ? selectedLabel
                              : visibilityTypes.keys.first,
                          decoration: InputDecoration(
                            hintText: "Select visibility",
                            hintStyle: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: Color(0xFFF1F3F5),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: visibilityTypes.keys.map((label) {
                            return DropdownMenuItem(
                              value: label,
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            setState(() {
                              selectedLabel = v!;
                            });
                          },
                        ),
                        if (selectedLocation == null &&
                            location.text.trim().isEmpty) ...[
                          _label("Online Event Url"),
                          Field(
                            controller: onlineUrl,
                            hint: "https://",
                            keyboard: TextInputType.url,
                          ),
                        ],
                      ]),

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFormValid
                                ? primaryColor
                                : Colors.grey.shade400,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          onPressed: isFormValid
                              ? () async {
                                  if (!_formKey.currentState!.validate())
                                    return;

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
                                          selectedTags
                                              .map((e) => e.id)
                                              .toList(),
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
                                      'exhibitor_menu':
                                          showcaseExhibitory ?? false,
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
                                          (provider
                                                      .eventModel
                                                      ?.website
                                                      ?.isNotEmpty ==
                                                  true
                                              ? provider.eventModel!.website![0]
                                              : null))
                                        'website_id': selectedWebsite!.id,
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

                                    final homeProvider =
                                        Provider.of<HomeProvider>(
                                          context,
                                          listen: false,
                                        );
                                    await homeProvider.gettingStages();
                                    hideLoadingDialog(context);
                                    CustomSnackbar.showSuccess(
                                      context,
                                      "Successfully updated",
                                    );

                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            EventDetailsScreen(
                                              id: provider.eventModel!.id,
                                            ),
                                      ),
                                      (route) => false,
                                    );
                                  } catch (e) {
                                    hideLoadingDialog(context);
                                    final message = cleanedError(e.toString());
                                    CustomSnackbar.showError(context, message);
                                  }
                                }
                              : () {},
                          child: Text(
                            "Update Event",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _label(String t) =>
      Text(t, style: const TextStyle(color: Colors.grey));

  Widget _card(String h, List<Widget> c) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(15),
          child: Text(
            h,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Divider(color: Colors.grey.shade300),
        Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: c
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: e,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    ),
  );

  Widget _check(String t, bool v, Function(bool) on) =>
      CheckboxListTile(value: v, title: Text(t), onChanged: (x) => on(x!));

  Widget _dateField(TextEditingController controller, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Text(controller.text),
        ),
      ),
    );
  }
}
