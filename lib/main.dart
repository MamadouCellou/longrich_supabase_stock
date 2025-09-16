import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'nouvelle_commande.dart';
import 'list_des_commandes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Charger le fichier .env

  /*try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("⚠️ .env non trouvé : $e");
  }*/
  // Initialiser les locales pour intl
  await initializeDateFormatting('fr_FR', null);


  // Initialiser Supabase
  await Supabase.initialize(
    url: "https://daiddasdeyvgltehlupx.supabase.co",
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRhaWRkYXNkZXl2Z2x0ZWhsdXB4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc5Nzg5MjQsImV4cCI6MjA3MzU1NDkyNH0.EOjmxpkyti4sx8XOwhUmR-Yp8f1RpnvK9BMl8Qy9cKk",
    // debug mode pour logs détaillés
    debug: true,
  );

  /*await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    // debug mode pour logs détaillés
    debug: true,
  );*/

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion de Stock Longrich',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (_) => const HomePage(),
        '/new_purchase': (_) => const NewPurchasePage(),
        '/purchases_list': (_) => const PurchasesListPage(),
      },
    );
  }
}

// Page d'accueil avec navigation
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gestion Stock Longrich")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text("Nouvel Achat"),
              onPressed: () => Navigator.pushNamed(context, '/new_purchase'),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.list),
              label: const Text("Liste des Achats"),
              onPressed: () => Navigator.pushNamed(context, '/purchases_list'),
            ),
          ],
        ),
      ),
    );
  }
}
