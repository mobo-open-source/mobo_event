import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

///status helper function
String statusString(String status) {
  if (status == "already_registered") {
    return "Ticket Already Scanned";
  } else if (status == "confirmed_registration") {
    return "Ticket Registration Confirmed";
  } else if (status == "canceled_registration") {
    return "Ticket  Registration Cancelled";
  } else if (status == 'need_manual_confirmation') {
    return "This QR code is for another event. Do you want to confirm?";
  } else if (status == 'unconfirmed_registration') {
    return "Unconfirmed Registration";
  } else if (status == 'not_ongoing_event') {
    return "This Ticket is not for an ongoing Event";
  }

  return status;
}

///status helper function for color
Color getColor(String state) {
  switch (state.toLowerCase()) {
    case 'already_registered':
      return StatusColors.orange;
    case 'confirmed_registration':
      return StatusColors.green;
    case 'canceled_registration':
      return StatusColors.red;
    case 'need_manual_confirmation':
      return StatusColors.orange;

    case 'not_ongoing_event':
      return StatusColors.orange;

    default:
      return StatusColors.grey;
  }
}

///state
String getState(String state) {
  switch (state) {
    case 'draft':
      return 'Unconfirmed';
    case 'open':
      return 'Registered';
    case 'done':
      return 'Attended';
    case 'cancel':
      return 'Canceled';
    default:
      return state;
  }
}

Color getStateColor(String state) {
  switch (state) {
    case 'draft':
      return StatusColors.orange;

    case 'open':
      return StatusColors.blue;

    case 'done':
      return StatusColors.green;

    case 'cancel':
      return StatusColors.red;

    default:
      return StatusColors.grey;
  }
}
