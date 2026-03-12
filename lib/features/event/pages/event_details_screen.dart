import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/app/home_scaffold.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/features/questions/providers/questions_provider.dart';
import 'package:mobo_event/features/scheduler/provider/mail_scheduler_provider.dart';
import 'package:mobo_event/shared/helper/helper_method.dart';
import 'package:mobo_event/shared/widgets/shimmer_card/shimmer_card.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/widgets/back_dialog/show_back_dialog.dart';
import '../../home/providers/home_provider.dart';
import '../../registration/page/registration_page.dart';
import '../provider/event_detailed_provider.dart';
import '../widget/event_add_line.dart';
import '../widget/event_main_card.dart';

class EventDetailsScreen extends StatefulWidget {
  final int id;
  const EventDetailsScreen({super.key, required this.id});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initialLoading();
    });
  }

  Future<void> initialLoading() async {
    try {
      final detailProvider = Provider.of<EventDetailedProvider>(
        context,
        listen: false,
      );
      detailProvider.reset();
      await detailProvider.loadFields();

      await Provider.of<HomeProvider>(context, listen: false).gettingStages();
      await detailProvider.fetchEventDetails(widget.id);
      Provider.of<MailSchedulerProvider>(context, listen: false).reset();
      Provider.of<MailSchedulerProvider>(
        context,
        listen: false,
      ).fetchScheduledMail(widget.id);
      await Provider.of<QuestionsProvider>(
        context,
        listen: false,
      ).fetchQuestions(widget.id);

      Provider.of<QuestionsProvider>(context, listen: false).reset();
    } catch (e) {
      CustomSnackbar.showError(context, cleanedError(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        bool confirm = await showBackDialog(
          context,
          title: 'Go to Home Screen',
          subtitle: "Are you sure go to the home screen?",
          leftButtonName: "Stay",
          rightButtonName: "Leave",
          function: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => HomeScaffold()),
              (route) => false,
            );
          },
        );
      },

      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : backgroundColor,

        appBar: AppBar(
          backgroundColor: isDark ? Colors.grey[900] : backgroundColor,
          leading: GestureDetector(
            onTap: () async {
              bool confirm = await showBackDialog(
                context,
                title: 'Go to Home Screen',
                subtitle: "Are you sure go to the home screen?",
                leftButtonName: "Stay",
                rightButtonName: "Leave",
                function: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => HomeScaffold()),
                    (route) => false,
                  );
                },
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          title: Text(
            "Event Details",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        body: Consumer<EventDetailedProvider>(
          builder: (context, provider, child) {
            return RefreshIndicator(
              onRefresh: () async {
                await initialLoading();
              },

              child: provider.isLoading
                  ? ListView(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 20,
                      ),
                      children: const [
                        FullCardShimmer(height: 300),
                        SizedBox(height: 20),
                        FullCardShimmer(height: 400),
                        SizedBox(height: 80),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 20),
                      children: [
                        provider.eventModel!.seatTaken != 0
                            ? Padding(
                                padding: const EdgeInsets.only(
                                  left: 20,
                                  right: 20,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.05,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(4, 4),
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.05,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(-4, -4),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 13,
                                          horizontal: 10,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            HugeIcon(
                                              icon: HugeIcons
                                                  .strokeRoundedUserMultiple,
                                              color: Colors.black,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              provider.eventModel!.attended
                                                  .toString(),
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Spacer(),
                                    SizedBox(width: 10),
                                    FilledButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),

                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                RegistrationPage(id: widget.id),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 15,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.qr_code_2,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              "Scan to Register",
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : SizedBox.shrink(),
                        provider.eventModel == null
                            ? SizedBox(
                                height: 200,
                                child: Center(child: Text("No Event Found")),
                              )
                            : EventMainCard(event: provider.eventModel!),

                        EventAddLine(eventId: widget.id),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Future<void> openDynamicLink(String link) async {
    final Uri url = Uri.parse(link);

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $link');
    }
  }
}
