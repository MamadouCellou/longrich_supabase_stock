import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:longrich_supabase_stock/services/purchase_service.dart';
import 'package:longrich_supabase_stock/utils/snackbars.dart';
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
      print("Les commandes : ${_purchases}");
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
                    PurchaseService purchaseService =
                        PurchaseService(supabase: supabase);

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
                            child: Slidable(
                              key: ValueKey(purchase.id),

                              // ➡️ Glissement droite → gauche : Valider / Invalider
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                extentRatio: 0.25,
                                children: [
                                  // Exemple pour la partie Valider / Invalider
                                  SlidableAction(
                                    onPressed: (context) async {
                                      try {
                                        if (!purchase.validated) {
                                          // 🔹 Valider directement
                                          final success = await purchaseService.markValidated(purchase.id!);
                                          if (!mounted) return;
                                          if (success) {
                                            setState(() => purchase.validated = true);
                                            showSucessSnackbar(
                                                context: context,
                                                message: "Commande validée ✅");
                                          }
                                        } else {
                                          // 🔹 Invalider => nécessite confirmation
                                          final confirmed = await showConfirmationBottomSheet(
                                            context: context,
                                            action: "Invalider",
                                            correctName: purchase.buyerName,
                                            correctMatricule: purchase.gn,
                                          );

                                          if (confirmed != true) return; // Stop si non confirmé

                                          final success = await purchaseService.unmarkValidated(purchase.id!);
                                          if (!mounted) return;
                                          if (success) {
                                            setState(() => purchase.validated = false);
                                            showSucessSnackbar(
                                                context: context,
                                                message: "Commande invalidée ❌");
                                          }
                                        }
                                      } catch (e) {
                                        if (!mounted) return;
                                        showErrorSnackbar(
                                            context: context,
                                            message: "Erreur inattendue ❌ : $e");
                                      }
                                    },
                                    backgroundColor: purchase.validated ? Colors.orange : Colors.green,
                                    foregroundColor: Colors.white,
                                    icon: purchase.validated ? Icons.undo : Icons.check_circle,
                                    label: purchase.validated ? "Invalider" : "Valider",
                                  ),

                                ],
                              ),

                              // ⬅️ Glissement gauche → droite : Positionner / Dépositionner
                              startActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                extentRatio: 0.25,
                                children: [
                                  // Exemple pour Positionner / Déposition
                                  SlidableAction(
                                    onPressed: (context) async {
                                      try {
                                        if (!purchase.positioned) {
                                          // 🔹 Positionner directement
                                          final success = await purchaseService.markPositioned(purchase.id!);
                                          if (!mounted) return;
                                          if (success) {
                                            setState(() => purchase.positioned = true);
                                            showSucessSnackbar(
                                                context: context,
                                                message: "Commande positionnée 📌");
                                          }
                                        } else {
                                          // 🔹 Déposition => nécessite confirmation
                                          final confirmed = await showConfirmationBottomSheet(
                                            context: context,
                                            action: "Déposition",
                                            correctName: purchase.buyerName,
                                            correctMatricule: purchase.gn,
                                          );

                                          if (confirmed != true) return; // Stop si non confirmé

                                          final success = await purchaseService.unmarkPositioned(purchase.id!);
                                          if (!mounted) return;
                                          if (success) {
                                            setState(() => purchase.positioned = false);
                                            showSucessSnackbar(
                                                context: context,
                                                message: "Commande dépositionnée ❌");
                                          }
                                        }
                                      } catch (e) {
                                        if (!mounted) return;
                                        showErrorSnackbar(
                                            context: context,
                                            message: "Erreur inattendue ❌ : $e");
                                      }
                                    },
                                    backgroundColor: purchase.positioned ? Colors.orange : Colors.blue,
                                    foregroundColor: Colors.white,
                                    icon: purchase.positioned ? Icons.undo : Icons.push_pin,
                                    label: purchase.positioned ? "Déposition" : "Positionner",
                                  ),

                                ],
                              ),

                              // 🔹 ExpansionTile inchangé (affichage de la commande, badges, items, etc.)
                              child: ExpansionTile(
                                title: Text(purchase.buyerName),
                                subtitle: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 150,
                                      child: Text(
                                        purchase.gn,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 150,
                                      child: Text(
                                        purchase.purchaseType,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                    // Badge Positionné
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: purchase.positioned ? Colors.green : Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        purchase.positioned ? "Positionné" : "Non positionné",
                                        style: const TextStyle(fontSize: 12, color: Colors.white),
                                      ),
                                    ),
                                    // Badge Validé
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: purchase.validated ? Colors.green : Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        purchase.validated ? "Validée" : "Non validée",
                                        style: const TextStyle(fontSize: 12, color: Colors.white),
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
                                  // Row des actions classiques
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
                                          if (value == 'edit') {
                                            final itemsRes = await _loadItems(purchase.id!);
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => NewPurchasePage(
                                                  purchase: purchase,
                                                  purchaseItems: itemsRes,
                                                ),
                                              ),
                                            );
                                            _loadPurchases(reset: true); // 🔹 Recharger après modification
                                          } else if (value == 'delete') {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (_) => AlertDialog(
                                                title: const Text("Confirmer la suppression"),
                                                content: const Text("Voulez-vous vraiment supprimer cet achat ?"),
                                                actions: [
                                                  TextButton(
                                                    child: const Text("Annuler"),
                                                    onPressed: () => Navigator.pop(context, false),
                                                  ),
                                                  TextButton(
                                                    child: const Text("Supprimer"),
                                                    onPressed: () => Navigator.pop(context, true),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirm == true) {
                                              try {
                                                await supabase
                                                    .from('purchases')
                                                    .delete()
                                                    .eq('id', purchase.id!);

                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          "Commande de ${purchase.buyerName} supprimée avec succès")),
                                                );

                                                // 🔹 Mise à jour locale instantanée sans loader global
                                                setState(() {
                                                  _purchases.removeWhere((p) => p.id == purchase.id);
                                                  _itemsCache.remove(purchase.id);
                                                });
                                              } catch (e) {
                                                print("Erreur suppression: $e");
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                      content: Text("Erreur lors de la suppression")),
                                                );
                                              }
                                            }
                                          }
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
                            )
                        );
                      },
                    );
                  }),
                ),
    );
  }

  Future<bool?> showConfirmationBottomSheet({
    required BuildContext context,
    required String action, // "Deposition" ou "Invalider"
    required String correctName, // Nom exact de la commande
    required String correctMatricule, // Matricule exact de la commande
  }) async {
    final _formKey = GlobalKey<FormState>();
    String enteredName = '';
    String enteredMatricule = '';

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$action la commande",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: "Nom",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                  (value == null || value.isEmpty) ? "Champ requis" : null,
                  onSaved: (value) => enteredName = value!.trim(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: "Matricule",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                  (value == null || value.isEmpty) ? "Champ requis" : null,
                  onSaved: (value) => enteredMatricule = value!.trim(),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();

                      // ✅ Vérification que les infos saisies correspondent exactement
                      if (enteredName == correctName &&
                          enteredMatricule == correctMatricule) {
                        Navigator.of(context).pop(true); // Confirme l'action
                      } else {
                        // ❌ Affiche un message si incorrect
                        showErrorSnackbar(context: context, message: "Nom ou matricule incorrect. Vérifiez vos saisies ❌");
                      }
                    }
                  },
                  child: const Text("Confirmer"),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }


}
