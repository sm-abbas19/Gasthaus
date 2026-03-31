import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/auth/auth_provider.dart';
import 'features/cart/cart_provider.dart';
import 'features/menu/menu_provider.dart';
import 'features/orders/orders_provider.dart';
import 'features/ai/ai_chat_provider.dart';

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
        // OrdersProvider is registered globally so it can be accessed
        // from the OrdersScreen tab inside the shell without re-fetching
        // every time the tab is switched.
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        // AiChatProvider is global so the chat session persists when the
        // user switches tabs and comes back — messages stay visible.
        ChangeNotifierProvider(create: (_) => AiChatProvider()),
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
