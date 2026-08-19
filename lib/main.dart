import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'ui/theme/kimi_theme.dart';
import 'ui/screens/home_screen.dart';
import 'services/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: KimiColors.lacquer,
  ));
  runApp(const KimiProxyApp());
}

class KimiProxyApp extends StatelessWidget {
  const KimiProxyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: MaterialApp(
        title: 'Kimi Proxy',
        debugShowCheckedModeBanner: false,
        theme: KimiTheme.dark,
        home: const HomeScreen(),
      ),
    );
  }
}
