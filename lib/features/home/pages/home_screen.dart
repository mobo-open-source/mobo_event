import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/features/profile/providers/profile_provider.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/shimmer_card/shimmer_card.dart';
import '../../event/provider/event_detailed_provider.dart';
import '../../event/widget/add_floating_event.dart';
import '../../registration/page/registration_page.dart';
import '../providers/home_provider.dart';
import '../widgets/event_short_card.dart';
import '../widgets/search_event.dart';
import '../widgets/shimmer_status_bar.dart';
import '../widgets/status_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  final searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  bool isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initialLoading();
    });
  }

  Future<void> initialLoading() async {
    try {
      setState(() => isInitialLoading = true);

      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      await homeProvider.fetchVersion();
      final eventProvider = Provider.of<EventDetailedProvider>(
        context,
        listen: false,
      );

      homeProvider.setActiveFilters([]);

      await Future.wait([
        homeProvider.gettingStages(),
        eventProvider.loadFields(),
        eventProvider.loadFieldOfTicket(),
        homeProvider.loadEvents(),
      ]);
    } catch (e) {
      CustomSnackbar.showError(context, "Error while loading");
    } finally {
      if (mounted) {
        setState(() => isInitialLoading = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    try {
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      await homeProvider.gettingStages();
      await homeProvider.loadEvents();
      CustomSnackbar.showInfo(context, "Refreshed successfully");
    } catch (e) {
      CustomSnackbar.showError(context, "Refresh failed");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<HomeProvider, ProfileProvider>(
      builder: (context, provider, profileProvider, child) {
        if (isInitialLoading || provider.loading) {
          return Scaffold(
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FullCardShimmer(height: 50, radius: 5),
                ),

                SizedBox(height: 10),

                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: 5,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, __) => const StatusTabShimmer(),
                  ),
                ),

                const SizedBox(height: 20),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ListView.builder(
                      itemCount: 6,
                      itemBuilder: (_, __) => const FullCardShimmer(),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final isLoading = provider.isEventLoading || profileProvider.isLoading;

        return Scaffold(
          body: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 7),
                  SearchEvent(
                    controller: searchController,
                    focusNode: searchFocusNode,
                  ),

                  if (provider.activeFilters.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              "${provider.activeFilters.length} Active",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: provider.stageList.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          return StatusTab(
                            title: provider.stageList[index].name,
                            isActive: selectedIndex == index,
                            onTap: () {
                              setState(() {
                                selectedIndex = index;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// Event List
                  Expanded(
                    child: isLoading
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: ListView.builder(
                              itemCount: 5,
                              itemBuilder: (_, __) => const FullCardShimmer(),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _onRefresh,
                            child: _buildEventList(provider),
                          ),
                  ),

                  const SizedBox(height: 70),
                ],
              ),

              Positioned(
                top: MediaQuery.of(context).size.height * 0.7,
                right: 20,
                child: floatingActionButtonAddingEvent(context),
              ),

              /// QR Button
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegistrationPage(),
                        ),
                      );
                    },
                    child: Container(
                      height: 70,
                      width: 70,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventList(HomeProvider provider) {
    if (provider.stageList.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 200),
          Center(
            child: Lottie.asset('assets/lotties/empty ghost.json', width: 220),
          ),
          const Center(
            child: Text("Stages are not found. Please create stages"),
          ),
        ],
      );
    }

    final filteredList = provider.eventList
        .where((e) => e.stageId == provider.stageList[selectedIndex].id)
        .toList();

    if (filteredList.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Lottie.asset('assets/lotties/empty ghost.json', width: 220),
          ),
          const Center(child: Text("No event in this stage")),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        return EventShortCard(eventShortDetails: filteredList[index]);
      },
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }
}
