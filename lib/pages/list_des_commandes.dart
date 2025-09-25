import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:longrich_supabase_stock/utils/utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nouvelle_commande.dart';
import '../models/purchase.dart';
import '../models/purchase_item.dart';

class PurchasesListPage extends StatefulWidget {
  const PurchasesListPage({super.key});
  @override
  State<PurchasesListPage> createState() => _PurchasesListPageState();
}

class _PurchasesListPageState extends State<PurchasesListPage> {
  final supabase = Supabase.instance.client;

  List<Purchase> _purchases = [];
  Map<String, List<PurchaseItem>> _itemsCache = {};

  StreamSubscription? _subPurchases;
  StreamSubscription? _subItems;

  bool _loading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  int _page = 0;
  final int _limit = 5;

  final NumberFormat _currencyFormat = NumberFormat("#,##0.00", "fr_FR");

  @override
  void initState() {
    super.initState();
    _loadPurchases(showLoader: true, reset: true);
    _subscribeRealtime();
  }

  Future<void> _loadPurchases({bool showLoader = false, bool reset = false}) async {
    if (_isLoadingMore) return;

    if (reset) {
      _page = 0;
      _purchases.clear();
      _hasMore = true;
    }

    setState(() {
      if (showLoader) _loading = true;
      _isLoadingMore = true;
    });

    try {
      final res = await supabase
          .from('purchases_with_total')
          .select()
          .order('created_at', ascending: false)
          .range(_page * _limit, (_page + 1) * _limit - 1);

      final List<Purchase> newPurchases = List<Map<String, dynamic>>.from(res)
          .map((m) => Purchase.fromMap(m))
          .toList();

      setState(() {
        _purchases.addAll(newPurchases);
        _hasMore = newPurchases.length == _limit;
        if (_hasMore) _page++;
      });
    } catch (e) {
      print("Erreur pagination: $e");
    } finally {
      setState(() {
        _loading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _subscribeRealtime() {
    _subPurchases = supabase.from('purchases').stream(primaryKey: ['id']).listen(
          (_) => _loadPurchases(showLoader: false, reset: true),
    );

    _subItems = supabase.from('purchase_items').stream(primaryKey: ['id']).listen(
          (_) => _itemsCache.clear(),
    );
  }

  @override
  void dispose() {
    _subPurchases?.cancel();
    _subItems?.cancel();
    super.dispose();
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat('EEEE dd MMM yyyy, HH:mm', 'fr_FR')
        .format(dateTime.toLocal());
  }

  Future<List<PurchaseItem>> _loadItems(String purchaseId) async {
    if (_itemsCache.containsKey(purchaseId)) {
      return _itemsCache[purchaseId]!;
    }

    final res =
    await supabase.from('purchase_items').select().eq('purchase_id', purchaseId);

    if (res != null) {
      _itemsCache[purchaseId] = List<Map<String, dynamic>>.from(res)
          .map((m) => PurchaseItem.fromMap(m))
          .toList();
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
          : RefreshIndicator(
        onRefresh: () => _loadPurchases(showLoader: true, reset: true),
        child: ListView.builder(
          itemCount: _purchases.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _purchases.length) {
              // 🔹 bouton "Afficher plus" au lieu du loader
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: ElevatedButton(
                    onPressed: _isLoadingMore ? null : () => _loadPurchases(),
                    child: _isLoadingMore
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text("Afficher plus"),
                  ),
                ),
              );
            }

            final purchase = _purchases[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: ExpansionTile(
                title: Text(purchase.buyerName),
                subtitle: Text("${purchase.gn} — ${purchase.purchaseType}"),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Total: ${_currencyFormat.format(purchase.totalAmount)} GNF"),
                    Text("PV: ${_currencyFormat.format(purchase.totalPv)}"),
                  ],
                ),
                children: [
                  FutureBuilder<List<PurchaseItem>>(
                    future: _loadItems(purchase.id!),
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
                        children: items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(
                                left: 30, top: 6, bottom: 6),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                (() {
                                  if (item.quantityReceived ==
                                      item.quantityTotal) {
                                    return "${item.quantityTotal} ${item.productName} — Tout reçu";
                                  } else if (item.quantityReceived == 0) {
                                    return "${item.quantityTotal} ${item.productName} — Aucun reçu";
                                  } else {
                                    final manquant = item.quantityTotal -
                                        item.quantityReceived;
                                    return "${item.quantityTotal} ${item.productName} — ${item.quantityReceived} reçu${item.quantityReceived > 1 ? 's' : ''}, $manquant manquant${manquant > 1 ? 's' : ''}";
                                  }
                                })(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Text("${_formatDate(purchase.createdAt)}"),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) async {
                          if (value == 'edit') {
                            final itemsRes = await _loadItems(purchase.id!);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NewPurchasePage(
                                  purchase: purchase,
                                  purchaseItems: itemsRes,
                                ),
                              ),
                            ).then((_) =>
                                _loadPurchases(showLoader: true, reset: true));
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
                                  .eq('id', purchase.id!);
                              _itemsCache.remove(purchase.id);
                              _loadPurchases(showLoader: false, reset: true);
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
      ),
    );
  }
}
