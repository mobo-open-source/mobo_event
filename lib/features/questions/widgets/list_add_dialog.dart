import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../shared/widgets/toggles/mobo_checkbox.dart';
import 'package:mobo_event/features/questions/services/question_service.dart';
import 'package:mobo_event/features/questions/widgets/create_question.dart';
import 'package:mobo_event/shared/helper/helper_method.dart';
import 'package:provider/provider.dart';
import '../../../core/const/app_colors.dart';
import '../../../core/services/event_access_rights.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';
import '../../../shared/widgets/shimmer_card/shimmer_card.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../providers/questions_provider.dart';

class ListAddDialog extends StatefulWidget {
  final List<int> ids;
  final int eventId;
  const ListAddDialog({super.key, required this.ids, required this.eventId});

  @override
  State<ListAddDialog> createState() => _ListAddDialogState();
}

class _ListAddDialogState extends State<ListAddDialog> {
  late List<int> selectedIds = [];

  /// True while Save is adding the picked questions: the button spins and
  /// ignores another tap.
  bool _saving = false;

  final services = QuestionService();

  @override
  void initState() {
    super.initState();

    // The Questions tab fetches this list before it opens the dialog, so it
    // normally has it already and opens on it — no skeleton. Only a list that
    // is missing or failed is fetched here, behind the skeleton / error state.
    Future.microtask(() {
      if (!mounted) return;
      final provider = context.read<QuestionsProvider>();
      if (provider.remainLoading || provider.remainError != null) _load();
    });
  }

  /// A failure is kept on the provider ([QuestionsProvider.remainError]) and
  /// shown here with a Retry; the rethrow has nothing in this dialog to catch
  /// it, so it is dropped rather than left unhandled.
  void _load() {
    if (!mounted) return;
    context
        .read<QuestionsProvider>()
        .fetchRemainingQuestions(widget.ids)
        .catchError((_) {});
  }

  bool get isFormValid => selectedIds.isNotEmpty;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // A phone in landscape is only ~300-400dp tall: the portrait recipe
    // (75% of the height, roomy header/footer) would leave the list a sliver,
    // so short windows get the whole height and tighter chrome.
    final compact = context.isShortScreen;
    return Dialog(
      backgroundColor: AppTheme.surface(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: compact
          ? const EdgeInsets.symmetric(horizontal: 18, vertical: 8)
          : const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: compact
              ? double.infinity
              : MediaQuery.of(context).size.height * 0.75,
        ),
        child: Consumer<QuestionsProvider>(
          builder: (context, provider, child) {
            // Creating a new question is a create on `event.question` as well
            // as the link onto the event.
            final canCreate = context.watch<AccessRights>().canCreateQuestion;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: compact
                      ? const EdgeInsets.fromLTRB(16, 4, 8, 4)
                      : const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Expanded, so on a narrow screen the title gives way
                      // with an ellipsis rather than pushing the buttons out.
                      Expanded(
                        child: Text(
                          "Add Question",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textPrimaryOn(isDark),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: compact ? VisualDensity.compact : null,
                        icon: Icon(
                          Icons.close,
                          color: isDark ? Colors.white : Colors.black87,
                        ),

                        // Nothing changed, so the fetched list stays valid for
                        // the next time the dialog opens.
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Same header → divider → content break as the question
                // detail dialog, instead of the header's own bottom padding
                // and the list's own top padding stacking into one loose,
                // undivided gap.
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? Colors.grey[800] : const Color(0xFFE0E0E0),
                ),

                Flexible(
                  fit: FlexFit.loose,
                  child: Padding(
                    // No bottom padding while "+ Create Question" follows: it
                    // sits directly under the last option, as the next row
                    // would, instead of a gap's width below it.
                    padding: EdgeInsets.fromLTRB(
                      15,
                      compact ? 8 : 12,
                      15,
                      canCreate ? 0 : (compact ? 8 : 15),
                    ),
                    child: provider.remainLoading
                        ? const _PickerSkeleton()
                        : provider.remainError != null
                        // Not a skeleton that never goes away, nor a blank
                        // dialog: say what went wrong and offer another go.
                        ? _PickerMessage(
                            title: "Couldn't load questions",
                            message: provider.remainError!,
                            actionLabel: 'Retry',
                            onAction: _load,
                          )
                        : provider.remainingQuestionList.isEmpty
                        ? _PickerMessage(
                            title: 'No questions to add',
                            message:
                                context.watch<AccessRights>().canCreateQuestion
                                ? 'Every reusable question is already on this '
                                      'event. Use Create Question to make a new '
                                      'one.'
                                : 'Every reusable question is already on this '
                                      'event.',
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: provider.remainingQuestionList.length,
                            itemBuilder: (_, index) {
                              final q = provider.remainingQuestionList[index];
                              final isChecked = selectedIds.contains(q.id);

                              return MoboCheckboxTile(
                                title: q.title,
                                value: isChecked,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 10,
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    if (val) {
                                      selectedIds.add(q.id);
                                    } else {
                                      selectedIds.remove(q.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ),

                // "+ Create Question" directly under the options, where the next
                // option would go. Pinned between the list and Save, so it stays
                // in view when the list is long enough to scroll.
                if (canCreate) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    // 15 + the button's own 4 puts the plus level with the
                    // checkboxes above it (the list's 15 + each row's 4).
                    child: Padding(
                      padding: const EdgeInsets.only(left: 15, right: 16),
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            builder: (_) => CreateQuestion(
                              eventId: widget.eventId,
                              previousIds: widget.ids,
                            ),
                          );
                        },
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedAdd01,
                          size: 18,
                          color: primaryColor,
                        ),
                        label: const Text("Create Question", maxLines: 1),
                      ),
                    ),
                  ),
                  // The room the list's bottom padding used to give Save.
                  SizedBox(height: compact ? 4 : 8),
                ],

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Save has the row to itself.
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              // The grey of the Create Event button's disabled
                              // state, not a faded brand red.
                              disabledBackgroundColor:
                                  AppTheme.disabledButtonFillOn(isDark),
                              disabledForegroundColor:
                                  AppTheme.disabledButtonText,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                            ),
                            onPressed: isFormValid
                                ? () async {
                                    if (_saving) return;
                                    setState(() => _saving = true);
                                    try {
                                      await services.addQuestions(
                                        selectedIds,
                                        widget.eventId,
                                      );
                                      provider.reset();

                                      await Provider.of<QuestionsProvider>(
                                        context,
                                        listen: false,
                                      ).fetchQuestions(widget.eventId);

                                      if (!mounted) return;
                                      Navigator.pop(context);
                                      CustomSnackbar.showSuccess(
                                        context,
                                        "Successfully added",
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      Navigator.pop(context);
                                      CustomSnackbar.showError(
                                        context,
                                        cleanedError(e.toString()),
                                      );
                                    }
                                  }
                                : null,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    "Save",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 10 : 16),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The picker's loading state: five bars the height of its checkbox rows.
/// (A skeleton of 100-tall cards made the dialog balloon while loading and
/// then collapse to a few short rows.)
class _PickerSkeleton extends StatelessWidget {
  const _PickerSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Column(
        children: [
          FullCardShimmer(height: 40, radius: 12),
          FullCardShimmer(height: 40, radius: 12),
          FullCardShimmer(height: 40, radius: 12),
          FullCardShimmer(height: 40, radius: 12),
          FullCardShimmer(height: 40, radius: 12),
        ],
      ),
    );
  }
}

/// A title and a line under it, with an optional action: the picker's error
/// and empty states.
class _PickerMessage extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _PickerMessage({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryOn(isDark),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.secondaryLabelColor(isDark),
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: const BorderSide(color: primaryColor, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
