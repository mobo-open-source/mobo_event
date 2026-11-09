import 'package:flutter/material.dart';
import 'dailog_box.dart';



void loadingDialog(
    BuildContext context,
    String title,
    String subTitle,
    Widget icon,

    ){
  final isDark = Theme.of(context).brightness == Brightness.dark;
  dialogBox(context,title,icon,
      Text(subTitle,

        style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54
        ),
        textAlign: TextAlign.center,
      ));
}




void hideLoadingDialog(BuildContext context) {
  if (Navigator.of(context, rootNavigator: true).canPop()) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}