import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/features/registration/provider/registration_provider.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../../../shared/widgets/shimmer_card/shimmer_card.dart';
import '../widget/attendees_card.dart';
import '../widget/attendees_search_event.dart';
import '../widget/floating_action_button_adding_attendees.dart';
import '../widget/search_filter.dart';

class EventAttendeesPage extends StatefulWidget {
  final int eventId;
  const EventAttendeesPage({super.key, required this.eventId});

  @override
  State<EventAttendeesPage> createState() => _EventAttendeesPageState();
}

class _EventAttendeesPageState extends State<EventAttendeesPage> {
  final searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      initialLoading(widget.eventId);
    });
  }

  Future initialLoading(int eventId) async {
    try {
      final provider = Provider.of<RegistrationProvider>(
        context,
        listen: false,
      );

      provider.clearFilter();
      provider.setActiveFiltersEvents(['Unconfirmed or Registered']);

      await provider.loadAttendeesByEvent(eventId: eventId, reset: true);
    } catch (e) {
      CustomSnackbar.showError(context, "Error While Fetching Attendees");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Attendees",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Theme.of(context).primaryColor,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      floatingActionButton: floatingActionButtonAddingAttendees(
        context,
        widget.eventId,
      ),
      body: Column(
        children: [
          SizedBox(height: 10),
          AttendeeSearchEvent(
            eventId: widget.eventId,
            controller: searchController,
            focusNode: searchFocusNode,
          ),
          SizedBox(height: 15),
          Consumer<RegistrationProvider>(
            builder: (context, provider, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: provider.activeFiltersByEvent.isNotEmpty
                        ? Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    "${provider.activeFiltersByEvent.length} Active",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                              Spacer(),
                            ],
                          )
                        : Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: Text(
                              "No filters applied",
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: PaginationControls(
                      canGoToPreviousPage: provider.canGoPreviousEvent,
                      canGoToNextPage: provider.canGoNextEvent,
                      onPreviousPage: () => provider.previousPageEvent(),
                      onNextPage: () => provider.nextPageEvent(),
                      paginationText: provider.paginationTextEvent,
                      isDark: isDark,
                      theme: Theme.of(context),
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 5),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: Consumer<RegistrationProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoadingEvent) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ListView(
                        children: const [
                          FullCardShimmer(height: 150),
                          FullCardShimmer(height: 150),
                          FullCardShimmer(height: 150),
                          FullCardShimmer(height: 150),
                          FullCardShimmer(height: 150),
                          FullCardShimmer(height: 150),
                        ],
                      ),
                    );
                  } else if (provider.fetchedAttendeesByEvent == null) {
                    return const Center(child: Text("Some error occurred"));
                  } else if (provider.fetchedAttendeesByEvent!.isEmpty) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              children: [
                                SizedBox(height: 50),
                                SizedBox(
                                  height: 180,
                                  child: Lottie.asset(
                                    'assets/lotties/empty ghost.json',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text("No Attendees expected yet!"),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Text(
                                    "wait until Attendees register to your Event or Create their registration manually",

                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: Size(120, 40),

                                        side: BorderSide(
                                          color: Colors.grey.shade400,
                                          width: 0.5,
                                        ),

                                        backgroundColor: Colors.white,

                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () async {
                                        searchController.clear();
                                        provider.clearFilter();
                                        await provider.loadAttendeesByEvent(
                                          eventId: widget.eventId,
                                          reset: true,
                                        );
                                      },
                                      child: Row(
                                        children: [
                                          HugeIcon(
                                            icon: HugeIcons
                                                .strokeRoundedFilterRemove,
                                            size: 15,
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            "Clear Filters",
                                            style: TextStyle(
                                              color: primaryColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 20),

                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: Size(120, 40),

                                        backgroundColor: primaryColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () async {
                                        await provider.loadAttendeesByEvent(
                                          eventId: widget.eventId,
                                          search: searchController.text,
                                          reset: true,
                                        );
                                      },
                                      child: Row(
                                        children: [
                                          HugeIcon(
                                            icon:
                                                HugeIcons.strokeRoundedRefresh,
                                            size: 13,
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            "Retry",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  } else {
                    return ListView.builder(
                      itemCount: provider.fetchedAttendeesByEvent!.length,
                      itemBuilder: (context, index) {
                        return AttendeesCard(
                          id: widget.eventId,
                          attendeeShortModel:
                              provider.fetchedAttendeesByEvent![index],
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onRefresh() async {
    try {
      final provider = Provider.of<RegistrationProvider>(
        context,
        listen: false,
      );
      await provider.loadAttendeesByEvent(reset: true, eventId: widget.eventId);
    } catch (e) {
      CustomSnackbar.showError(context, "Refresh failed");
    }
  }
}
