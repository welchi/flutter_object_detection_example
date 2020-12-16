import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class MyApp extends HookWidget {
  const MyApp({Key key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: true,
      title: 'MyApp',
      theme: ThemeData.from(
        colorScheme: const ColorScheme.light(),
      ),
      darkTheme: ThemeData.from(
        colorScheme: const ColorScheme.dark(),
      ),
      navigatorKey: GlobalKey<NavigatorState>(),
      initialRoute: ObjectDetectionPage.routeName,
      routes: {
        ObjectDetectionPage.routeName: (context) => ObjectDetectionPage(),
      },
    );
  }
}
