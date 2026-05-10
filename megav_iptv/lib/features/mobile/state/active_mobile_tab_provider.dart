import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Index of the currently active tab in the mobile bottom tab bar.
///
/// Drives [MTabBar] selection state. 0 = Home, 1 = TV, 2 = Search,
/// 3 = Guide, 4 = Profile (Req 5.2 / 5.3).
final activeMobileTabProvider = StateProvider<int>((ref) => 0);
