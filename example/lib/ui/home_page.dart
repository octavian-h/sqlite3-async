import 'package:flutter/material.dart';
import 'package:sqlite3_async_example/persistence/storage_utils.dart';

class MyHomePage extends StatefulWidget {
  static const String route = "/home";

  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final myController = TextEditingController();
  List<String> items = [];

  @override
  void dispose() {
    myController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Form(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: myController,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: ElevatedButton(
                      onPressed: () async {
                        await StorageUtils.addItem(myController.text);
                        var readItems = await StorageUtils.readItems();
                        setState(() {
                          items = readItems;
                        });
                      },
                      child: const Text("Submit"),
                    ),
                  ),
                ],
              ),
            ),
            Text("Items: ${items.toString()}"),
          ],
        ),
      ),
    );
  }
}
