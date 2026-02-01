import 'package:flutter/material.dart';

/// 🔐 Global auth state
/// true  = user is logged in
/// false = user is NOT logged in
final ValueNotifier<bool> isLoggedInNotifier = ValueNotifier<bool>(false);
