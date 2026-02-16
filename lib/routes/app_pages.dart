// ignore_for_file: constant_identifier_names

import 'package:shital_video_editor/pages/editor/editor_page.dart';
import 'package:shital_video_editor/pages/export/export_binding.dart';
import 'package:shital_video_editor/pages/export/export_page.dart';
import 'package:shital_video_editor/pages/logs_viewer/logs_viewer_page.dart';
import 'package:shital_video_editor/pages/video_picker/video_picker_page.dart';
import 'package:get/route_manager.dart';

part 'app_routes.dart';

class AppPages {
  static const INITIAL = Routes.VIDEO_PICKER;

  static final routes = [
    GetPage(
      name: Routes.VIDEO_PICKER,
      page: () => VideoPickerPage(),
    ),
    GetPage(
      name: Routes.EDITOR,
      page: () => EditorPage(),
    ),
    GetPage(
      name: Routes.EXPORT,
      page: () => ExportPage(),
      binding: ExportBinding(),
    ),
    GetPage(
      name: Routes.LOGS_VIEWER,
      page: () => const LogsViewerPage(),
    )
  ];
}
