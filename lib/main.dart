import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'features/aft/logic/data/mdl_csv.dart';
import 'features/aft/logic/data/hrp_csv.dart';
import 'features/aft/logic/data/sdc_csv.dart';
import 'features/aft/logic/data/plk_csv.dart';
import 'features/aft/logic/data/run2mi_csv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock the entire app to portrait so rotating the device does not change layout.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Auth Emulator disabled: using real Firebase backend.
  // To re-enable for local testing, restore useAuthEmulator() in debug builds.
  // Load MDL, HRP, and SDC scoring tables (male/female, age-banded) from embedded CSVs
  preloadMdlCsvOnce(mdlCsv);
  preloadHrpCsvOnce(hrpCsv);
  preloadSdcCsvOnce(sdcCsv);
  preloadPlkCsvOnce(plkCsv);
  preloadRun2miCsvOnce(run2miCsv);
  runApp(const ProviderScope(child: App()));
}
