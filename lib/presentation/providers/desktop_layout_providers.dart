import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/presentation/widgets/common/desktop_layout.dart';

/// Shared primary (pane 2) width for every shell tab's master-detail split.
///
/// One value so resizing on 聊天, 外观, 设置, etc. keeps the same divider.
final primaryPaneWidthProvider =
    StateProvider<double>((ref) => DesktopLayout.primaryPaneDefaultWidth);
