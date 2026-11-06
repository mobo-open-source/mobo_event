import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/features/documentation/services/documentation_services.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';
import '../../../core/const/app_colors.dart';
import '../../../core/services/event_access_rights.dart';
import '../../../core/utils/screen_layout.dart';
import '../../../shared/widgets/dialogs/common_dialog.dart';
import '../../../shared/widgets/shimmer_card/shimmer_card.dart';
import '../../../shared/widgets/forms/dashed_border_box.dart';
import '../../../shared/widgets/forms/field_label.dart';
import '../../../shared/widgets/forms/mobo_select_field.dart';
import '../../event/provider/event_detailed_provider.dart';
import '../../event/widget/field.dart';
import '../../../core/theme/app_theme.dart';

class DocumentationScreen extends StatefulWidget {
  const DocumentationScreen({super.key});

  @override
  State<DocumentationScreen> createState() => _DocumentationScreenState();
}

class _DocumentationScreenState extends State<DocumentationScreen>
    with AutomaticKeepAliveClientMixin {
  /// Keeps this tab mounted while the tab row swipes away from it.
  ///
  /// The tab row now swipes (TabBarView), which can dispose and rebuild a tab
  /// that's scrolled a couple of pages away — this is the one tab with its
  /// own unsaved state (a picked image, an unlocked-but-not-yet-saved edit),
  /// so it opts out of that and stays mounted like the other tabs' already do
  /// (they hold no state of their own; see their own "Nothing is fetched
  /// here" notes).
  @override
  bool get wantKeepAlive => true;

  String selectedLabel = "A4 foldable";

  /// Map of question type labels to their corresponding values in the API
  final Map<String, String> questionTypeMap = {
    "A4 foldable": "A4_french_fold",
    "A6": "A6",
    "4 per sheet": "four_per_sheet",
  };

  final TextEditingController ticketController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  PlatformFile? pickedFile;
  Uint8List? fileBytes;

  bool isLoading = true;
  bool isSaving = false;

  /// Fields start locked even for an account that can edit this tab — the
  /// edit toggle beside the heading is what unlocks them, the same
  /// edit-then-save flow the Profile screen uses.
  bool _isEditingFields = false;

  /// The values as last loaded or saved. A field counts as changed only while
  /// it differs from these, so undoing an edit disables Save again.
  String _savedBadge = '';
  String _savedTicket = '';
  String _savedNotes = '';
  Uint8List? _savedImage;

  bool get badgeChanged => selectedLabel != _savedBadge;
  bool get ticketChange => ticketController.text != _savedTicket;
  bool get notesChanged => notesController.text != _savedNotes;

  /// A picked image is a new byte list, so identity spots a replaced or
  /// removed one without comparing the bytes.
  bool get imageChanged => !identical(fileBytes, _savedImage);

  bool get hasChanges =>
      badgeChanged || ticketChange || notesChanged || imageChanged;

  void _markSaved() {
    _savedBadge = selectedLabel;
    _savedTicket = ticketController.text;
    _savedNotes = notesController.text;
    _savedImage = fileBytes;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    // Save compares these with what was loaded, so typing has to refresh it.
    notesController.addListener(() => setState(() {}));
    ticketController.addListener(() => setState(() {}));
  }

  Future<Map<String, dynamic>> fetchDocumentInfo() async {
    final provider = Provider.of<EventDetailedProvider>(context, listen: false);

    final model = provider.eventModel;

    return {
      "badge_dimension": model?.badgeFormat,
      "ticket_instruction": model?.ticketInstructions ?? "",
      "notes": model?.note ?? "",
      "background": model?.badgeImage,
    };
  }

  /// Load initial data from the server and set state accordingly
  Future<void> _loadInitialData() async {
    try {
      final data = await fetchDocumentInfo();

      setState(() {
        selectedLabel = questionTypeMap.entries
            .firstWhere(
              (e) => e.value == data["badge_dimension"],
              orElse: () => questionTypeMap.entries.first,
            )
            .key;

        ticketController.text = data["ticket_instruction"] ?? "";
        notesController.text = data["notes"] ?? "";

        if (data["background"] != null &&
            data["background"].toString().isNotEmpty) {
          fileBytes = data["background"];
        }

        isLoading = false;
        _markSaved();
      });
    } catch (_) {
      setState(() {
        isLoading = false;
        _markSaved();
      });
    }
  }

  /// Pick background image from device
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

  /// Remove background image
  void removeBackground() {
    setState(() {
      pickedFile = null;
      fileBytes = null;
    });
  }

  /// Asks before dropping the badge image, the way every delete in the app
  /// does; it is only gone from the event once Save is pressed.
  Future<void> _confirmRemoveBackground() async {
    final confirm = await CommonDialog.confirm(
      context,
      title: 'Delete Image',
      message: 'Are you sure you want to delete the badge background image?',
      confirmText: 'Delete',
    );
    if (confirm != true || !mounted) return;
    removeBackground();
  }

  /// Pencil ↔ cancel toggle beside the heading — the only way into
  /// [_isEditingFields]. Hidden entirely for an account without
  /// canEditDocumentation, same as the fields themselves.
  Widget _editToggle(bool isDark, bool canEdit) {
    if (!canEdit) return const SizedBox.shrink();

    return IconButton(
      tooltip: _isEditingFields ? 'Cancel' : 'Edit',
      onPressed: () {
        setState(() {
          if (_isEditingFields) {
            // Cancel: drop back to the last saved values rather than leave
            // the fields half-edited the next time this is opened.
            selectedLabel = _savedBadge;
            ticketController.text = _savedTicket;
            notesController.text = _savedNotes;
            fileBytes = _savedImage;
            pickedFile = null;
          }
          _isEditingFields = !_isEditingFields;
        });
      },
      icon: HugeIcon(
        icon: _isEditingFields
            ? HugeIcons.strokeRoundedCancel01
            : HugeIcons.strokeRoundedPencilEdit02,
        size: 18,
        color: _isEditingFields ? StatusColors.red : AppTheme.primaryColor,
      ),
      style: IconButton.styleFrom(
        backgroundColor: isDark ? Colors.grey[800] : AppTheme.fieldFill,
        padding: const EdgeInsets.all(6),
        minimumSize: const Size(32, 32),
      ),
    );
  }

  @override
  void dispose() {
    ticketController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppTheme.surface(isDark),
      body: isLoading
          ? ListView(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              children: const [
                FullCardShimmer(height: 100),
                SizedBox(height: 10),
                FullCardShimmer(height: 100),
                SizedBox(height: 10),
                FullCardShimmer(height: 100),
              ],
            )
          : _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    // Everything on this tab is saved with one write on `event.event`. Without
    // that right the fields are shown but can't be touched, and there is
    // nothing to save.
    final canEdit = context.watch<AccessRights>().canEditDocumentation;
    // Locked until the pencil is tapped, even for an account that may edit.
    final fieldsEnabled = canEdit && _isEditingFields;

    final landscape = context.isLandscape;
    final title = Row(
      children: [
        Expanded(
          child: Text(
            "Notes & Document Information",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              // Black (white in dark mode) — pink is reserved for the edit
              // toggle beside it, not the heading itself.
              color: AppTheme.labelColor(isDark),
            ),
          ),
        ),
        _editToggle(isDark, canEdit),
      ],
    );

    final saveFooter = fieldsEnabled
        ? Padding(
            // Pinned below the fields, and exactly as wide as them (the same
            // cap and centring in landscape) the way mobo CRM's forms end in
            // a Save that lines up with their fields: a gap above it, no
            // inset at the sides.
            padding: landscape
                ? const EdgeInsets.only(top: 8, bottom: 4)
                : const EdgeInsets.only(top: 12, bottom: 4),
            child: ConstrainedContent(
              maxWidth: landscape ? 600 : double.infinity,
              child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      // Grey while there is nothing to save; brand-coloured while a
                      // save runs, so the spinner keeps its usual backdrop.
                      disabledBackgroundColor: isSaving
                          ? primaryColor
                          : (isDark ? Colors.grey[700] : Colors.grey.shade300),
                      disabledForegroundColor: isDark
                          ? Colors.grey[400]
                          : Colors.grey[500],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: isSaving || !hasChanges
                        ? null
                        : () async {
                            setState(() => isSaving = true);

                            try {
                              final payload =
                                  DocumentationServices.buildUpdatePayload(
                                    badge: badgeChanged
                                        ? questionTypeMap[selectedLabel]
                                        : null,
                                    notes: notesChanged
                                        ? notesController.text
                                        : null,
                                    ticketInstruction: ticketChange
                                        ? ticketController.text
                                        : null,

                                    backgroundBase64:
                                        imageChanged && fileBytes != null
                                        ? base64Encode(fileBytes!)
                                        : null,
                                    imageChanged: imageChanged,
                                  );

                              final provider =
                                  Provider.of<EventDetailedProvider>(
                                    context,
                                    listen: false,
                                  );

                              await DocumentationServices.update(
                                provider.eventModel!.id,
                                payload,
                              );

                              if (mounted) {
                                // Refreshed in place: a full reload dropped the
                                // page to its skeleton and reopened it on the
                                // Tickets tab, away from what was just saved.
                                provider
                                    .refreshEventDetails(
                                      provider.eventModel!.id,
                                    )
                                    .ignore();
                                setState(() {
                                  isSaving = false;
                                  _markSaved();
                                  // Back to the locked view, as Profile does
                                  // once its own Save succeeds.
                                  _isEditingFields = false;
                                });
                                CustomSnackbar.showSuccess(
                                  context,
                                  "Updated Successfully",
                                );
                              }
                            } catch (_) {
                              if (!mounted) return;
                              setState(() {
                                isSaving = false;
                              });
                              CustomSnackbar.showError(
                                context,
                                "some error occured",
                              );
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        // No fixed colours here: the button's foreground colours
                        // grey the label out along with the button.
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save, size: 22),
                              SizedBox(width: 10),
                              Text(
                                "Save",
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
          )
        : null;

    // Save stays pinned below the fields — unless the window (a phone in
    // landscape with the keyboard up) is too short to leave the fields any
    // room beside it, when it scrolls with them instead of being squeezed out.
    return LayoutBuilder(
      builder: (context, constraints) {
        final pinSave = constraints.maxHeight >= (landscape ? 60 : 100) + 96;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // In landscape the heading scrolls away with the fields: the tab's
            // card is only a few dozen dp tall there, and a pinned heading plus
            // the pinned Save below would leave the fields almost no room.
            if (!landscape) title,
            Expanded(
              child: SingleChildScrollView(
                // One scrolling column; capped and centred in landscape rather
                // than stretched across the whole width.
                child: ConstrainedContent(
                  maxWidth: landscape ? 600 : double.infinity,
                  child: SizedBox(
                    width: double.infinity,
                    // The heading (and its edit toggle) stays outside the
                    // AbsorbPointer below, in landscape as well as portrait —
                    // otherwise, once locked, there would be no way to reach
                    // the very button that unlocks the fields.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (landscape) title,
                        const SizedBox(height: 16),
                        AbsorbPointer(
                          absorbing: !fieldsEnabled,
                          child: Opacity(
                            opacity: fieldsEnabled ? 1 : 0.7,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _rowField(
                                  label: "Badge Dimension",
                                  child: MoboSingleSelectField<String>(
                                    selected:
                                        questionTypeMap.containsKey(
                                          selectedLabel,
                                        )
                                        ? selectedLabel
                                        : questionTypeMap.keys.first,
                                    options: questionTypeMap.keys
                                        .map(
                                          (label) => MoboSelectOption(
                                            value: label,
                                            label: label,
                                          ),
                                        )
                                        .toList(),
                                    hintText: 'Select badge dimension',
                                    panelTitle: 'Select Badge Dimension',
                                    allowClear: false,
                                    onChanged: (v) {
                                      if (v == null) return;
                                      setState(() {
                                        selectedLabel = v;
                                      });
                                    },
                                  ),
                                ),

                                const SizedBox(height: 14),

                                const FieldLabel("Badge Background"),
                                const SizedBox(height: 10),
                                if (fileBytes == null)
                                  _uploadButton(isDark)
                                else
                                  _imagePreview(
                                    isDark,
                                    canEdit: fieldsEnabled,
                                  ),

                                const SizedBox(height: 14),
                                _textCard(
                                  "Ticket Instruction",
                                  ticketController,
                                  3,
                                ),
                                const SizedBox(height: 14),
                                _textCard("Notes", notesController, 4),
                              ],
                            ),
                          ),
                        ),
                        if (saveFooter != null && !pinSave) saveFooter,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            if (saveFooter != null && pinSave) saveFooter,
          ],
        );
      },
    );
  }

  Widget _uploadButton(bool isDark) {
    return InkWell(
      onTap: pickBackground,
      borderRadius: BorderRadius.circular(AppRadius.md),
      // The dashed drop-box line the event create form's "Upload Image" box
      // draws, in the same greys — in place of a solid hairline.
      child: DashedBorderBox(
        borderRadius: AppRadius.md,
        color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
        child: Container(
          // Shorter on a short (landscape) window, where 150dp is half of it.
          height: context.isShortScreen ? 96 : 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: AppTheme.inputFill(isDark),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedFileUpload,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                const SizedBox(width: 8),
                Text(
                  "Upload Image",
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The picked image, with the sales app's photo badges over its corners:
  /// replace at the bottom right, delete (after a confirmation) at the top
  /// right. An account that can't edit sees the image alone.
  Widget _imagePreview(bool isDark, {required bool canEdit}) {
    // Both badges are grey — delete no longer red, replace no longer brand
    // red — so neither competes with the picture for attention; their icons
    // say which is which.
    final badgeColor = isDark ? Colors.grey[700]! : Colors.grey[600]!;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Image.memory(
            fileBytes!,
            height: context.isShortScreen ? 110 : 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        if (canEdit) ...[
          Positioned(
            top: 8,
            right: 8,
            child: _imageActionBadge(
              isDark,
              icon: HugeIcons.strokeRoundedDelete02,
              color: badgeColor,
              tooltip: 'Delete image',
              onTap: _confirmRemoveBackground,
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: _imageActionBadge(
              isDark,
              icon: HugeIcons.strokeRoundedImageAdd01,
              color: badgeColor,
              tooltip: 'Change image',
              onTap: pickBackground,
            ),
          ),
        ],
      ],
    );
  }

  /// §16's solid action badge: a 36dp filled circle with a white ring and a
  /// soft shadow, so it stands out on a light or a dark picture alike.
  Widget _imageActionBadge(
    bool isDark, {
    required List<List<dynamic>> icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? Colors.grey[900]! : Colors.white,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: HugeIcon(icon: icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _textCard(String title, TextEditingController controller, int lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(title),
        const SizedBox(height: 8),
        Field(controller: controller, hint: "Enter $title", maxLines: lines),
      ],
    );
  }

  Widget _rowField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [FieldLabel(label), const SizedBox(height: 5), child],
    );
  }
}
