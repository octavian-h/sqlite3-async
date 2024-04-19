import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:sqlite3_async/sqlite3_async.dart';

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
        HomePage.route: (context) =>
            const HomePage(title: 'Flutter Demo Home Page'),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  static const String route = "/home";

  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final myController = TextEditingController();
  final formKey = GlobalKey<FormState>();
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextFormField(
                      controller: myController,
                      decoration: const InputDecoration(labelText: "Item"),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter some text";
                        }
                        return null;
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ElevatedButton(
                        onPressed: insertItem,
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
      ),
    );
  }

  void insertItem() async {
    if (formKey.currentState!.validate()) {
      await StorageUtils.addItem(myController.text);
      var readItems = await StorageUtils.readItems();
      setState(() {
        items = readItems;
      });
    }
  }
}

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
                    Navigator.pushReplacementNamed(context, HomePage.route);
                  });
                  return Container();
                }),
          ],
        ),
      ),
    );
  }
}

class StorageUtils {
  static AsyncDatabase? _itemsDb;

  static Future<void> init() async {
    var databaseDir = await path_provider.getApplicationSupportDirectory();
    if (!await databaseDir.exists()) {
      await databaseDir.create(recursive: true);
    }
    var dbPath = path.join(databaseDir.path, "items.db");
    _itemsDb = await AsyncDatabase.open(dbPath);
    await _itemsDb!.execute("DROP TABLE IF EXISTS items");
    await _itemsDb!.execute("CREATE TABLE items("
        "id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "name TEXT NOT NULL)");
  }

  static Future<void> addItem(String name) {
    return _itemsDb!.execute("INSERT INTO items (name) VALUES (?)", [name]);
  }

  static Future<List<String>> readItems() async {
    return (await _itemsDb!.select("SELECT * FROM items"))
        .map((e) => e["name"].toString())
        .toList();
  }
}
