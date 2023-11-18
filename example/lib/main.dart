import 'package:flutter/material.dart';
import 'package:sqlite3_async_example/ui/home_page.dart';
import 'package:sqlite3_async_example/ui/loading_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: LoadingPage.route,
      routes: {
        LoadingPage.route: (context) => const LoadingPage(),
        MyHomePage.route: (context) =>
            const MyHomePage(title: 'Flutter Demo Home Page'),
      },
    );
  }
}
