import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'features/aft/logic/data/mdl_csv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Load MDL scoring tables (male/female, age-banded) from embedded CSV
  preloadMdlCsvOnce(mdlCsv);
  runApp(const ProviderScope(child: App()));
}
