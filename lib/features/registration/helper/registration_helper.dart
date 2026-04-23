import 'package:flutter/material.dart';


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
      return Colors.orange;
    case 'confirmed_registration':
      return Colors.green;
    case 'canceled_registration':
      return Colors.red;
    case 'need_manual_confirmation':
      return Colors.orange;

    case 'not_ongoing_event':
      return Colors.orange;

    default:
      return Colors.grey;
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
      return Colors.orange;

    case 'open':
      return Colors.blue;

    case 'done':
      return Colors.green;

    case 'cancel':
      return Colors.red;

    default:
      return Colors.grey;
  }
}
