
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/features/registration/provider/registration_provider.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';
import '../../../app/home_scaffold.dart';
import '../../../shared/widgets/back_dialog/show_back_dialog.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../../../shared/widgets/shimmer_card/shimmer_card.dart';
import '../widget/attendees_card.dart';
import '../widget/floating_action_button_adding_attendees.dart';
import '../widget/search_filter.dart';

class AttendeesPage extends StatefulWidget {
  const AttendeesPage({super.key,});
  @override
  State<AttendeesPage> createState() => _AttendeesPageState();
}

class _AttendeesPageState extends State<AttendeesPage> {


  final searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();


  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      initialLoading();
    });

  }


  Future initialLoading()async{
    try{
      final provider =
      Provider.of<RegistrationProvider>(context, listen: false);
      provider.clearFilter();
      provider.setActiveFiltersTotal(['Ongoing Events']);
      await provider.loadAttendees(reset: true);


    }catch(e){
       CustomSnackbar.showError(context, "Error While Fetching Attendees");
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
          subtitle:
          "Are you sure go to the home screen?",
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
          appBar: AppBar(
            title: Text(
              "Attendees",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: GestureDetector(
              onTap: ()async{
                bool confirm = await showBackDialog(
                  context,
                  title: 'Go to Home Screen',
                  subtitle:
                  "Are you sure go to the home screen?",
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
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: isDark ? Colors.white : Theme.of(context).primaryColor,
            elevation: 0,
            centerTitle: false,
            surfaceTintColor: Colors.transparent,
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

          floatingActionButton: floatingActionButtonAddingAttendees(context,null),

          body:Column(
          children: [
            SizedBox(height: 10,),
            SearchFilter(controller: searchController,focusNode: searchFocusNode,),
            SizedBox(height: 15,),
            Consumer<RegistrationProvider>(
                builder: (context, provider, child) {
                  return
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                Expanded(child:provider.activeFiltersByTotal.isNotEmpty?Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal:10,vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(5)
                        ),
                        child: Text("${provider.activeFiltersByTotal.length} Active",style: TextStyle(
                          color: Colors.white
                        ),),
                      ),
                    ),
                    Spacer()
                  ],
                ):Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text("No filters applied",style: TextStyle(
                    fontSize: 12
                  ),),
                )),


               Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: PaginationControls(
                        canGoToPreviousPage: provider.canGoPrevious,
                        canGoToNextPage: provider.canGoNext,
                        onPreviousPage: () =>
                            provider.previousPage(),
                        onNextPage: () =>
                            provider.nextPage(),
                        paginationText: provider.paginationText,
                        isDark:isDark ,
                        theme: Theme.of(context),
                      ),
                    )

              ],
            );}),
         SizedBox(height: 10,),


            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                child: Consumer<RegistrationProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading) {
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
                    }
                    else if (provider.fetchedAttendees == null) {
                      return const Center(child: Text("Some error occurred"));
                    }
                    else if (provider.fetchedAttendees!.isEmpty) {
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
                                  SizedBox(height: 50,),
                                  SizedBox(
                                      height: 180,
                                      child:  Lottie.asset('assets/lotties/empty ghost.json')
                                  ),
                                  const SizedBox(height: 16),
                                  Text("No Attendees expected yet!",),
                                  const SizedBox(height: 10),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
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

                                          side:  BorderSide(
                                            color: Colors.grey.shade400,
                                            width: 0.5,
                                          ),


                                          backgroundColor: Colors.white,

                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(
                                              8,
                                            ),


                                          ),
                                        ),
                                        onPressed: ()  async{
                                          provider.clearFilter();
                                          searchController.clear();
                                         await  provider.loadAttendees(reset: true);
                                        },
                                        child: Row(
                                          children: [
                                            HugeIcon(icon: HugeIcons.strokeRoundedFilterRemove,size: 15,),
                                            SizedBox(width: 10,),
                                            Text(
                                                "Clear Filters",
                                                style: TextStyle(
                                                    color: primaryColor,
                                                    fontWeight: FontWeight.w600
                                                )
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 20),

                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: Size(120, 40),

                                          backgroundColor:
                                          primaryColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        onPressed: ()async{
                                          await provider.loadAttendees(reset: true,search: searchController.text);
                                        },
                                        child: Row(
                                          children: [
                                            HugeIcon(icon:HugeIcons.strokeRoundedRefresh,size: 13,),
                                            SizedBox(width: 10,),
                                            Text(
                                                "Retry",
                                                style: TextStyle(
                                                    color: Colors.white
                                                )
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
                    }
                    else {
                      return ListView.builder(
                        itemCount: provider.fetchedAttendees!.length,
                        itemBuilder: (context, index) {
                          return AttendeesCard(

                            attendeeShortModel:
                            provider.fetchedAttendees![index],
                          );
                        },
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        )
      ),
    );
  }

  Future<void> _onRefresh()async{
    try{
      final provider = Provider.of<RegistrationProvider>(context, listen: false);
      await provider.loadAttendees(reset: true);


    }catch(e){
      CustomSnackbar.showError(context, "Refresh failed");

    }

  }
}
