import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/auth/auth_provider.dart';
import 'features/cart/cart_provider.dart';
import 'features/menu/menu_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  final authProvider = AuthProvider();
  await authProvider.restoreSession();

  runApp(GasthausApp(authProvider: authProvider));
}

class GasthausApp extends StatelessWidget {
  final AuthProvider authProvider;

  const GasthausApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
      ],
      child: Builder(
        builder: (context) {
          final router = createRouter(
            context.read<AuthProvider>(),
          );
          return MaterialApp.router(
            title: 'Gasthaus',
            theme: AppTheme.theme,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
