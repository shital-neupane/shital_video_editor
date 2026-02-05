import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shital_video_editor/routes/app_pages.dart';
import 'package:shital_video_editor/shared/core/themes.dart';
import 'package:shital_video_editor/shared/translations/messages.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(ShitalVE());
}

class ShitalVE extends StatefulWidget {
  const ShitalVE({
    super.key,
    this.initialVideo,
  });

  final String? initialVideo;

  @override
  State<ShitalVE> createState() => _ShitalVEState();
}

class _ShitalVEState extends State<ShitalVE> {
  bool loaded = false;

  @override
  void initState() {
    if (widget.initialVideo != null) {
      debugPrint(
          "SEARCH INITIAL VIDEO was not null in main on init runni save");
      _saveInitialVideoToPrefs();
    } else {
      Navigator.pop(context);
    }

    super.initState();
  }

  Future<void> _saveInitialVideoToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('initialVideo', widget.initialVideo!);
    setState(() {
      loaded = true;
    });
    print("SEARCH ADDED INITIAL VIDEO TO PREF");
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    return loaded
        ? GetMaterialApp(
            translations: Messages(),
            locale: const Locale('en'),
            fallbackLocale: const Locale('en', 'US'),
            getPages: AppPages.routes,
            initialRoute: AppPages.INITIAL,
            themeMode: ThemeMode.dark,
            theme: appThemeData,
            darkTheme: appThemeDataDark,
            debugShowCheckedModeBanner: false,
          )
        : CircularProgressIndicator();
  }
}
