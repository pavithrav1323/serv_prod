// lib/utils/logout.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:serv_app/Pagesusers/login_page.dart';
import 'package:serv_app/html_stub.dart'
  if (dart.library.html) 'package:serv_app/html_web.dart' as html;

Future<void> logout(BuildContext context) async {
  try {
    try {
      html.window.localStorage.remove('token');
      html.window.localStorage.remove('role');
      html.window.localStorage.remove('name');
      html.window.localStorage.remove('empId');
      html.window.localStorage.remove('empid');
      html.window.localStorage.remove('userDocId');
      html.window.localStorage.remove('employeeProfile');
    } catch (_) {}

    final sp = await SharedPreferences.getInstance();
    await sp.remove('token');
    await sp.remove('role');
    await sp.remove('name');
    await sp.remove('empId');
    await sp.remove('empid');
    await sp.remove('userDocId');
    await sp.remove('employeeProfile');
  } catch (_) {}

  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (r) => false,
    );
  }
}