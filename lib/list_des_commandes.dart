import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:longrich_supabase_stock/utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nouvelle_commande.dart';

class PurchasesListPage extends StatefulWidget {
  const PurchasesListPage({super.key});
  @override
  State<PurchasesListPage> createState() => _PurchasesListPageState();
}

class _PurchasesListPageState extends State<PurchasesListPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _purchases = [];
  Map<String, List<Map<String, dynamic>>> _itemsCache = {}; // cache produits
  StreamSubscription? _subPurchases;
  StreamSubscription? _subItems;
  bool _loading = true;
  final NumberFormat _currencyFormat = NumberFormat("#,##0.00", "fr_FR");

  @override
  void initState() {
    super.initState();
    _loadPurchases(showLoader: true);
    _subscribeRealtime();
  }

  Future<void> _loadPurchases({bool showLoader = false}) async {
    if (showLoader) setState(() => _loading = true);
    try {
      final res = await supabase
          .from('purchases_with_total')
          .select()
          .order('created_at', ascending: false);

      if (res != null) {
        setState(() {
          _purchases = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      print("Erreur lors du chargement des achats: $e");
    } finally {
      if (showLoader) setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    _subPurchases = supabase
        .from('purchases')
        .stream(primaryKey: ['id'])
        .listen((_) => _loadPurchases(showLoader: false));

    _subItems = supabase
        .from('purchase_items')
        .stream(primaryKey: ['id'])
        .listen((_) => _itemsCache.clear()); // reset cache si modif
  }

  @override
  void dispose() {
    _subPurchases?.cancel();
    _subItems?.cancel();
    super.dispose();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.parse(dateStr).toLocal();
    return DateFormat('EEEE dd MMM yyyy, HH:mm', 'fr_FR').format(dt);
  }

  Future<List<Map<String, dynamic>>> _loadItems(String purchaseId) async {
    if (_itemsCache.containsKey(purchaseId)) {
      return _itemsCache[purchaseId]!;
    }
    final res = await supabase
        .from('purchase_items')
        .select('product_name, quantity_total, quantity_received, quantity_missing')
        .eq('purchase_id', purchaseId);

    if (res != null) {
      _itemsCache[purchaseId] = List<Map<String, dynamic>>.from(res);
      return _itemsCache[purchaseId]!;
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Liste des achats")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _purchases.isEmpty
          ? const Center(child: Text("Aucun achat pour l'instant"))
          : ListView.builder(
        itemCount: _purchases.length,
        itemBuilder: (context, index) {
          final p = _purchases[index];
          final total =
          _currencyFormat.format((p['total_amount'] ?? 0));
          final totalPv =
          _currencyFormat.format((p['total_pv'] ?? 0));
          final buyer = p['buyer_name'] ?? '';
          final pm = p['payment_method'] ?? '';
          final created = _formatDate(p['created_at']);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: ExpansionTile(
              title: Text(buyer),
              subtitle: Text("$pm — $created"),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Total: $total GNF"),
                  Text("PV: $totalPv"),
                ],
              ),
              children: [
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadItems(p['id']),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      );
                    }
                    final items = snapshot.data!;
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text("Aucun produit"),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: items.map((it) {
                        final qtyTotal = it['quantity_total'] ?? 0;
                        final qtyReceived = it['quantity_received'] ?? 0;
                        final qtyMissing = it['quantity_missing'] ?? 0;

                        return Padding(
                          padding: const EdgeInsets.only(
                              left: 16.0, top: 6, bottom: 6),
                          child: Text(
                            "${it['product_name']} — "
                                "Commandé: $qtyTotal | "
                                "Reçu: $qtyReceived | "
                                "Manquant: $qtyMissing",
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          final itemsRes = await supabase
                              .from('purchase_items')
                              .select()
                              .eq('purchase_id', p['id']);
                          if (itemsRes != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NewPurchasePage(
                                  purchase: p,
                                  purchaseItems:
                                  List<Map<String, dynamic>>.from(
                                      itemsRes),
                                ),
                              ),
                            ).then((_) =>
                                _loadPurchases(showLoader: true));
                          }
                        } else if (value == 'delete') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Confirmer la suppression"),
                              content: const Text(
                                  "Voulez-vous vraiment supprimer cet achat ?"),
                              actions: [
                                TextButton(
                                  child: const Text("Annuler"),
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                ),
                                TextButton(
                                  child: const Text("Supprimer"),
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await supabase
                                .from('purchases')
                                .delete()
                                .eq('id', p['id']);
                          }
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                            value: 'edit', child: Text("Modifier")),
                        PopupMenuItem(
                            value: 'delete', child: Text("Supprimer")),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
