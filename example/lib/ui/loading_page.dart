import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sqlite3_async_example/ui/home_page.dart';

import '../persistence/storage_utils.dart';

class LoadingPage extends StatelessWidget {
  static const String route = "/";

  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FutureBuilder<void>(
                future: StorageUtils.init(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.none ||
                      snapshot.connectionState == ConnectionState.waiting) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox.fromSize(
                          size: const Size(16, 16),
                          child: const CircularProgressIndicator(),
                        ),
                      ],
                    );
                  }

                  SchedulerBinding.instance.addPostFrameCallback((_) {
                    Navigator.pushReplacementNamed(context, MyHomePage.route);
                  });
                  return Container();
                }),
          ],
        ),
      ),
    );
  }
}
