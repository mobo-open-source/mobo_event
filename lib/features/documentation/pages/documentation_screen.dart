import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/features/documentation/services/documentation_services.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';
import '../../../core/const/app_colors.dart';
import '../../../shared/widgets/shimmer_card/shimmer_card.dart';
import '../../event/provider/event_detailed_provider.dart';

class DocumentationScreen extends StatefulWidget {
  const DocumentationScreen({super.key});

  @override
  State<DocumentationScreen> createState() => _DocumentationScreenState();
}

class _DocumentationScreenState extends State<DocumentationScreen> {
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

  bool imageChanged = false;
  bool notesChanged = false;
  bool badgeChanged = false;
  bool ticketChange = false;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    notesController.addListener(() {
      if (_initialized) notesChanged = true;
    });

    ticketController.addListener(() {
      if (_initialized) {
        ticketChange = true;
      }
    });
  }

  Future<Map<String, dynamic>> fetchDocumentInfo() async {
    final provider = Provider.of<EventDetailedProvider>(context, listen: false);

    final model = provider.eventModel;
    /// Return default values if model is null
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
        _initialized = true;
      });
    } catch (e) {
      setState(() => isLoading = false);
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
        imageChanged = true;
      });
    }
  }

  /// Remove background image
  void removeBackground() {
    setState(() {
      pickedFile = null;
      fileBytes = null;
      imageChanged = true;
    });
  }

  @override
  void dispose() {
    ticketController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Notes & Document Information",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                _rowField(
                  label: "Badge Dimension",
                  child: DropdownButtonFormField<String>(
                    dropdownColor: Colors.white,
                    isExpanded: true,
                    value: questionTypeMap.containsKey(selectedLabel)
                        ? selectedLabel
                        : questionTypeMap.keys.first,
                    decoration: _inputDecoration("Select size"),
                    items: questionTypeMap.keys.map((label) {
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
                        badgeChanged = true;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  "Badge Background",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),
                if (fileBytes == null) _uploadButton() else _imagePreview(),

                const SizedBox(height: 14),
                _textCard("Ticket Instruction", ticketController, 3),
                const SizedBox(height: 14),
                _textCard("Notes", notesController, 4),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      setState(() => isSaving = true);

                      try {
                        final payload =
                            DocumentationServices.buildUpdatePayload(
                              badge: badgeChanged
                                  ? questionTypeMap[selectedLabel]
                                  : null,
                              notes: notesChanged ? notesController.text : null,
                              ticketInstruction: ticketChange
                                  ? ticketController.text
                                  : null,

                              backgroundBase64:
                                  imageChanged && fileBytes != null
                                  ? base64Encode(fileBytes!)
                                  : null,
                              imageChanged: imageChanged,
                            );

                        final provider = Provider.of<EventDetailedProvider>(
                          context,
                          listen: false,
                        );

                        await DocumentationServices.update(
                          provider.eventModel!.id,
                          payload,
                        );

                        if (mounted) {
                          provider.reset();
                          provider.fetchEventDetails(provider.eventModel!.id);
                          setState(() => isSaving = false);
                          CustomSnackbar.showSuccess(
                            context,
                            "Updated Successfully",
                          );
                        }
                      } catch (e) {
                        setState(() {
                          isSaving = false;
                        });
                        CustomSnackbar.showError(context, "some error occured");
                      }
                    },
              child: isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save, size: 20),
                        SizedBox(width: 10),

                        const Text("Save"),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _uploadButton() {
    return InkWell(
      onTap: pickBackground,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey, width: 0.5),
          borderRadius: BorderRadius.circular(5),

          color: backgroundColor,
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

  Widget _textCard(String title, TextEditingController controller, int lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: lines,
          decoration: _inputDecoration("Enter $title"),
        ),
      ],
    );
  }

  Widget _rowField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
      isDense: true,
      filled: true,
      fillColor: backgroundColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: Colors.grey, width: 0.5),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: primaryColor, width: 1),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),

      border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
    );
  }
}
