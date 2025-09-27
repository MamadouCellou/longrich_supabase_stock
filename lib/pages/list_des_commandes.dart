import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nouvelle_commande.dart';
import '../models/purchase.dart';
import '../models/purchase_item.dart';

class PurchasesListPage extends StatefulWidget {
  const PurchasesListPage({super.key});

  @override
  State<PurchasesListPage> createState() => _PurchasesListPageState();
}

/// 🔹 Enum des différents tris possibles
enum PurchaseSortOption {
  buyerNameAsc,
  buyerNameDesc,
  createdAtNewest,
  createdAtOldest,
  updatedAtNewest,
  updatedAtOldest,
  totalAmountHighToLow,
  totalAmountLowToHigh,
  totalPvHighToLow,
  totalPvLowToHigh,
}

enum PurchaseFilterOption {
  all, // Toutes les commandes
  retail, // Toutes commandes en Retail
  rehaussement, // Toutes commandes en Rehaussement
  retailPositioned, // Retail positionnées
  rehaussementPositioned, // Rehaussement positionnées
  retailPositionedNotValidated, // Retail positionnées mais non validées
  rehaussementPositionedNotValidated, // Rehaussement positionnées mais non validées
  allPositioned, // Toutes positionnées (Retail + Rehaussement)
  allPositionedNotValidated, // Toutes positionnées mais non validées
  validatedAll, // Toutes validées
  validatedRetail, // Validées retail
  validatedRehaussement // Validées rehaussement
}

class _PurchasesListPageState extends State<PurchasesListPage> {
  final supabase = Supabase.instance.client;

  List<Purchase> _purchases = [];
  Map<String, List<PurchaseItem>> _itemsCache = {};

  bool _loading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  int _page = 0;
  final int _limit = 5;

  final NumberFormat _currencyFormat = NumberFormat("#,##0.00", "fr_FR");

  PurchaseSortOption _currentSort = PurchaseSortOption.createdAtNewest;
  PurchaseFilterOption _currentFilter = PurchaseFilterOption.all;

  @override
  void initState() {
    super.initState();
    _loadPurchases(reset: true);
  }

  List<Purchase> _applyFilter(List<Purchase> purchases) {
    switch (_currentFilter) {
      case PurchaseFilterOption.all:
        return purchases;

      case PurchaseFilterOption.retail:
        // Toutes les commandes Retail
        return purchases.where((p) => p.purchaseType == "Retail").toList();

      case PurchaseFilterOption.rehaussement:
        // Toutes les commandes Rehaussement
        return purchases
            .where((p) => p.purchaseType == "Rehaussement")
            .toList();

      case PurchaseFilterOption.retailPositioned:
        return purchases
            .where((p) => p.purchaseType == "Retail" && p.positioned)
            .toList();

      case PurchaseFilterOption.rehaussementPositioned:
        return purchases
            .where((p) => p.purchaseType == "Rehaussement" && p.positioned)
            .toList();

      case PurchaseFilterOption.retailPositionedNotValidated:
        return purchases
            .where((p) =>
                p.purchaseType == "Retail" && p.positioned && !p.validated)
            .toList();

      case PurchaseFilterOption.rehaussementPositionedNotValidated:
        return purchases
            .where((p) =>
                p.purchaseType == "Rehaussement" &&
                p.positioned &&
                !p.validated)
            .toList();

      case PurchaseFilterOption.allPositioned:
        return purchases.where((p) => p.positioned).toList();

      case PurchaseFilterOption.allPositionedNotValidated:
        return purchases.where((p) => p.positioned && !p.validated).toList();

      case PurchaseFilterOption.validatedAll:
        return purchases.where((p) => p.validated).toList();

      case PurchaseFilterOption.validatedRetail:
        return purchases
            .where((p) => p.validated && p.purchaseType == "Retail")
            .toList();

      case PurchaseFilterOption.validatedRehaussement:
        return purchases
            .where((p) => p.validated && p.purchaseType == "Rehaussement")
            .toList();
    }
  }

  void _applySorting() {
    setState(() {
      _purchases.sort((a, b) {
        switch (_currentSort) {
          case PurchaseSortOption.buyerNameAsc:
            return a.buyerName
                .toLowerCase()
                .compareTo(b.buyerName.toLowerCase());
          case PurchaseSortOption.buyerNameDesc:
            return b.buyerName
                .toLowerCase()
                .compareTo(a.buyerName.toLowerCase());
          case PurchaseSortOption.createdAtNewest:
            return (b.createdAt ?? DateTime(0))
                .compareTo(a.createdAt ?? DateTime(0));
          case PurchaseSortOption.createdAtOldest:
            return (a.createdAt ?? DateTime(0))
                .compareTo(b.createdAt ?? DateTime(0));
          case PurchaseSortOption.updatedAtNewest:
            return (b.updatedAt ?? DateTime(0))
                .compareTo(a.updatedAt ?? DateTime(0));
          case PurchaseSortOption.updatedAtOldest:
            return (a.updatedAt ?? DateTime(0))
                .compareTo(b.updatedAt ?? DateTime(0));
          case PurchaseSortOption.totalAmountHighToLow:
            return b.totalAmount.compareTo(a.totalAmount);
          case PurchaseSortOption.totalAmountLowToHigh:
            return a.totalAmount.compareTo(b.totalAmount);
          case PurchaseSortOption.totalPvHighToLow:
            return b.totalPv.compareTo(a.totalPv);
          case PurchaseSortOption.totalPvLowToHigh:
            return a.totalPv.compareTo(b.totalPv);
        }
      });
    });
  }

  /// 🔹 Charger les achats (pagination depuis la vue purchases_with_total)
  Future<void> _loadPurchases({bool reset = false}) async {
    if (_isLoadingMore) return;

    if (reset) {
      _page = 0;
      _purchases.clear();
      _hasMore = true;
      _itemsCache.clear();
      setState(() => _loading = true);
    }

    setState(() => _isLoadingMore = true);

    try {
      final res = await supabase
          .from('purchases_with_total')
          .select()
          .order('created_at', ascending: false)
          .range(_page * _limit, (_page + 1) * _limit - 1);

      final newPurchases = List<Map<String, dynamic>>.from(res)
          .map((m) => Purchase.fromMap(m))
          .toList();

      // Précharger les items associés
      for (var purchase in newPurchases) {
        await _preloadItems(purchase.id!);
      }

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

  /// 🔹 Précharge les items d’un achat donné
  Future<void> _preloadItems(String purchaseId) async {
    try {
      final itemsRes = await supabase
          .from('purchase_items')
          .select()
          .eq('purchase_id', purchaseId);

      if (itemsRes != null) {
        _itemsCache[purchaseId] = List<Map<String, dynamic>>.from(itemsRes)
            .map((m) => PurchaseItem.fromMap(m))
            .toList();
      }
    } catch (e) {
      print("Erreur preload items: $e");
    }
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat('EEEE dd MMM yyyy, HH:mm', 'fr_FR')
        .format(dateTime.toLocal());
  }

  Future<List<PurchaseItem>> _loadItems(String purchaseId) async {
    return _itemsCache[purchaseId] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Liste des achats"),
        actions: [
          PopupMenuButton<PurchaseSortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (option) {
              setState(() {
                _currentSort = option;
                _applySorting();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: PurchaseSortOption.buyerNameAsc,
                child: Text("Nom acheteur (A-Z)"),
              ),
              const PopupMenuItem(
                value: PurchaseSortOption.buyerNameDesc,
                child: Text("Nom acheteur (Z-A)"),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: PurchaseSortOption.createdAtNewest,
                child: Text("Date création (récentes)"),
              ),
              const PopupMenuItem(
                value: PurchaseSortOption.createdAtOldest,
                child: Text("Date création (anciennes)"),
              ),
              const PopupMenuItem(
                value: PurchaseSortOption.updatedAtNewest,
                child: Text("Date modification (récentes)"),
              ),
              const PopupMenuItem(
                value: PurchaseSortOption.updatedAtOldest,
                child: Text("Date modification (anciennes)"),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: PurchaseSortOption.totalAmountHighToLow,
                child: Text("Montant (du + grand au + petit)"),
              ),
              const PopupMenuItem(
                value: PurchaseSortOption.totalAmountLowToHigh,
                child: Text("Montant (du + petit au + grand)"),
              ),
              const PopupMenuItem(
                value: PurchaseSortOption.totalPvHighToLow,
                child: Text("PV (du + grand au + petit)"),
              ),
              const PopupMenuItem(
                value: PurchaseSortOption.totalPvLowToHigh,
                child: Text("PV (du + petit au + grand)"),
              ),
            ],
          ),
          PopupMenuButton<PurchaseFilterOption>(
            icon: const Icon(Icons.filter_alt),
            onSelected: (option) {
              setState(() {
                _currentFilter = option;
              });
            },
            itemBuilder: (context) => [
              // 🔹 Toutes les commandes
              const PopupMenuItem(
                value: PurchaseFilterOption.all,
                child: Text("Toutes les commandes"),
              ),
              const PopupMenuItem(
                value: PurchaseFilterOption.rehaussement,
                child: Text("Commandes en Rehaussement"),
              ),
              const PopupMenuItem(
                value: PurchaseFilterOption.retail,
                child: Text("Commandes en Retail"),
              ),
              const PopupMenuDivider(),

              // 🔹 Commandes positionnées
              const PopupMenuItem(
                value: PurchaseFilterOption.retailPositioned,
                child: Text("Retail positionnées"),
              ),
              const PopupMenuItem(
                value: PurchaseFilterOption.rehaussementPositioned,
                child: Text("Rehaussement positionnées"),
              ),
              const PopupMenuItem(
                value: PurchaseFilterOption.allPositioned,
                child: Text("Toutes positionnées"),
              ),
              const PopupMenuDivider(),

              // 🔹 Commandes positionnées mais non validées
              const PopupMenuItem(
                value: PurchaseFilterOption.retailPositionedNotValidated,
                child: Text("Retail positionnées non validées"),
              ),
              const PopupMenuItem(
                value: PurchaseFilterOption.rehaussementPositionedNotValidated,
                child: Text("Rehaussement positionnées non validées"),
              ),
              const PopupMenuItem(
                value: PurchaseFilterOption.allPositionedNotValidated,
                child: Text("Toutes positionnées non validées"),
              ),
              const PopupMenuDivider(),

              // 🔹 Commandes validées
              const PopupMenuItem(
                value: PurchaseFilterOption.validatedAll,
                child: Text("Validées (toutes)"),
              ),
              const PopupMenuItem(
                value: PurchaseFilterOption.validatedRetail,
                child: Text("Validées retail"),
              ),
              const PopupMenuItem(
                value: PurchaseFilterOption.validatedRehaussement,
                child: Text("Validées rehaussement"),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _purchases.isEmpty
              ? const Center(child: Text("Aucun achat pour l'instant"))
              : RefreshIndicator(
                  onRefresh: () => _loadPurchases(reset: true),
                  child: Builder(builder: (context) {
                    // 🔹 Appliquer le filtre sur la liste locale
                    final filteredPurchases = _applyFilter(_purchases);

                    return ListView.builder(
                      itemCount: filteredPurchases.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        // 🔹 Bouton "Afficher plus" pour la pagination
                        if (index == filteredPurchases.length) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: ElevatedButton(
                                onPressed: _isLoadingMore
                                    ? null
                                    : () => _loadPurchases(reset: false),
                                child: _isLoadingMore
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Text("Afficher plus"),
                              ),
                            ),
                          );
                        }

                        final purchase = filteredPurchases[index];
                        final items = _itemsCache[purchase.id] ?? [];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: ExpansionTile(
                            title: Text(purchase.buyerName),
                            subtitle: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // 🔹 Nom et type
                                SizedBox(
                                  width: 150, // Ajustable selon espace
                                  child: Text(
                                    purchase.gn,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                SizedBox(
                                  width: 150, // Ajustable selon espace
                                  child: Text(
                                    purchase.purchaseType,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontStyle: FontStyle.italic),
                                  ),
                                ),

                                // 🔹 Badge positionné
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: purchase.positioned
                                        ? Colors.blue.shade100
                                        : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    purchase.positioned ? "Positionné" : "Non positionné",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: purchase.positioned ? Colors.blue : Colors.black54,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                // 🔹 Badge validé
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: purchase.validated
                                        ? Colors.green.shade100
                                        : Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    purchase.validated ? "Validée" : "Non validée",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: purchase.validated ? Colors.green : Colors.orange,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("Total: ${_currencyFormat.format(purchase.totalAmount)} GNF"),
                                Text("PV: ${_currencyFormat.format(purchase.totalPv)}"),
                              ],
                            ),
                            children: [
                              // 🔹 Liste des items
                              if (items.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text("Aucun produit"),
                                )
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: items.map((item) {
                                    final manquant = item.quantityTotal - item.quantityReceived;
                                    String text;
                                    if (item.quantityReceived == item.quantityTotal) {
                                      text = "${item.quantityTotal} ${item.productName} — Tout reçu";
                                    } else if (item.quantityReceived == 0) {
                                      text = "${item.quantityTotal} ${item.productName} — Aucun reçu";
                                    } else {
                                      text =
                                      "${item.quantityTotal} ${item.productName} — ${item.quantityReceived} reçu${item.quantityReceived > 1 ? 's' : ''}, $manquant manquant${manquant > 1 ? 's' : ''}";
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 30, top: 6, bottom: 6),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(text, style: const TextStyle(fontSize: 14)),
                                      ),
                                    );
                                  }).toList(),
                                ),

                              // 🔹 Row des actions
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 16.0),
                                    child: Text(_formatDate(purchase.createdAt)),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (value) async {
                                      // 🔹 Logique Edit / Delete reste identique
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(value: 'edit', child: Text("Modifier")),
                                      PopupMenuItem(value: 'delete', child: Text("Supprimer")),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),

                        );
                      },
                    );
                  }),
                ),
    );
  }
}
