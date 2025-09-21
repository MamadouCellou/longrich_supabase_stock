import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:longrich_supabase_stock/pages/gestion_produits.dart';
import 'package:longrich_supabase_stock/utils/snackbars.dart';
import 'package:longrich_supabase_stock/utils/utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/product.dart';
import '../models/purchase.dart';
import '../models/purchase_item.dart';

class NewPurchasePage extends StatefulWidget {
  final Purchase? purchase;
  final List<PurchaseItem>? purchaseItems;

  const NewPurchasePage({super.key, this.purchase, this.purchaseItems});

  @override
  State<NewPurchasePage> createState() => _NewPurchasePageState();
}

class _NewPurchasePageState extends State<NewPurchasePage> {
  final supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _buyerController = TextEditingController();
  String _paymentMethod = 'cash';

  final TextEditingController _gnController = TextEditingController();
  String _purchaseType = 'Rehaussement';

  Map<String, int> _quantities = {};
  Map<String, int> _missingQuantities = {};
  List<Product> _products = [];
  bool _loading = false;


  int _currentPage = 0; // 🔹 état pour suivre la page actuelle

  @override
  void initState() {
    super.initState();
    _loadProducts();

    if (widget.purchase != null && widget.purchaseItems != null) {
      final purchase = widget.purchase!;

      _buyerController.text = purchase.buyerName;
      _paymentMethod = purchase.paymentMethod;
      _gnController.text = purchase.gn ?? '';

      // purchaseType déjà nettoyé dans Purchase.fromMap
      _purchaseType = purchase.purchaseType!;

      for (var item in widget.purchaseItems!) {
        _quantities[item.productId] = item.quantityTotal;
        _missingQuantities[item.productId] = item.quantityMissing;
      }
    } else {
      _purchaseType = 'Rehaussement';
      _gnController.text = '';
    }
  }

  Future<void> _loadProducts() async {
    final res = await supabase.from('products').select().order('created_at');
    if (res != null) {
      setState(() => _products = List<Map<String, dynamic>>.from(res)
          .map((m) => Product.fromMap(m))
          .toList());
    }
  }

  double computeTotalPreview() {
    return _products.fold(
      0,
      (sum, p) => sum + (p.pricePartner * (_quantities[p.id] ?? 0)),
    );
  }

  double computeTotalPV() {
    return _products.fold(
      0,
      (sum, p) => sum + (p.pv * (_quantities[p.id] ?? 0)),
    );
  }

  List<PurchaseItem> buildItems(List<Product> products) {
    return _quantities.entries.where((e) => e.value > 0).map((e) {
      final product = products.firstWhere((p) => p.id == e.key);
      final qtyTotal = e.value;
      final missing = _missingQuantities[e.key] ?? 0;

      return PurchaseItem(
        id: '', // ou UUID temporaire
        productId: product.id!,
        productName: product.name,
        unitPrice: product.pricePartner,
        unitPv: product.pv,
        quantityTotal: qtyTotal,
        quantityReceived: qtyTotal - missing,
        quantityMissing: missing,
      );
    }).toList();
  }

  Future<void> _showSummaryBottomSheet() async {
    final totalPreview = computeTotalPreview();
    final totalPV = computeTotalPV();
    final items = buildItems(_products);

    // Créer un controller pour chaque produit si nécessaire
    final controllers = <String, TextEditingController>{};
    for (var item in items) {
      _missingQuantities[item.productId] ??= 0; // tout reçu par défaut
      controllers[item.productId] ??= TextEditingController(
        text: _missingQuantities[item.productId]!.toString(),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Résumé de la commande",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text("Acheteur : ${_buyerController.text}"),
                    Text("Matricule : ${_gnController.text}"),
                    Text("Type d'achat : ${_purchaseType}"),
                    Text("Mode de paiement : $_paymentMethod"),
                    Text(
                        "Total Montant : ${currencyFormat.format(totalPreview)} GNF"),
                    Text("Total PV : ${totalPV.toStringAsFixed(2)}"),

                    // --- Liste des produits avec ExpansionTile ---
                    ...items.map((item) {
                      final product =
                          _products.firstWhere((p) => p.id == item.productId);
                      final controller = controllers[product.id]!;
                      final allReceived =
                          (_missingQuantities[product.id] ?? 0) == 0;

                      return ExpansionTile(
                        backgroundColor: Colors.transparent, // fond ouvert
                        collapsedBackgroundColor:
                            Colors.transparent, // fond fermé
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero),
                        collapsedShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero),
                        tilePadding: EdgeInsets.zero,
                        key: ValueKey(product.id),
                        title: Row(
                          children: [
                            Expanded(
                                child: Text(
                                    "${item.quantityTotal} ${product.name}")),
                            Checkbox(
                              value: allReceived,
                              onChanged: (val) {
                                setModalState(() {
                                  _missingQuantities[product.id!] =
                                      val! ? 0 : item.quantityTotal;
                                  controller.text =
                                      _missingQuantities[product.id]!
                                          .toString();
                                });
                              },
                            ),
                            const Text(
                              "Tout reçu",
                              style: TextStyle(
                                  fontSize: 15, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    decoration: InputDecoration(
                                      labelText:
                                          "Quantité manquante (Max: ${item.quantityTotal})",
                                    ),
                                    onChanged: (val) {
                                      int m;
                                      if (val.isEmpty) {
                                        m = 0; // Champ vide = tout reçu
                                      } else {
                                        m = int.tryParse(val) ?? 0;
                                        if (m > item.quantityTotal)
                                          m = item.quantityTotal;
                                      }

                                      setModalState(() {
                                        _missingQuantities[product.id!] = m;
                                        // Mettre à jour le controller sans perdre le curseur
                                        controller.text = m.toString();
                                        controller.selection =
                                            TextSelection.fromPosition(
                                          TextPosition(
                                              offset: controller.text.length),
                                        );
                                      });
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check_circle,
                                      color: Colors.green),
                                  onPressed: () {
                                    FocusScope.of(context).unfocus();
                                    setModalState(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),

                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Confirmer et enregistrer"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final items = buildItems(_products);
    if (items.isEmpty) {
      showErrorSnackbar(
          context: context, message: "Veuillez ajouter au moins un produit");
      return;
    }

    setState(() => _loading = true);

    try {
      if (widget.purchase != null) {
        final purchaseId = widget.purchase!.id!;

        await supabase
            .from('purchase_items')
            .delete()
            .eq('purchase_id', purchaseId);
        for (final item in items) {
          final product = _products.firstWhere((p) => p.id == item.productId);

          final itemMap = {
            'purchase_id': purchaseId,
            'product_id': product.id,
            'product_name': product.name,
            'unit_price': product.pricePartner,
            'unit_pv': product.pv,
            ...item.toMap(),
          };

          // Nettoyage -> éviter d'envoyer id = ""
          if (itemMap['id'] == null ||
              (itemMap['id'] as String).trim().isEmpty) {
            itemMap.remove('id');
          }

          await supabase.from('purchase_items').insert(itemMap);
        }

        await supabase.from('purchases').update({
          'buyer_name': _buyerController.text.trim(),
          'payment_method': _paymentMethod,
          'gn': _gnController.text.trim(),
          'purchase_type': _purchaseType
        }).eq('id', purchaseId);

        print("✅ Mise à jour de la commande $purchaseId réussie");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Achat modifié ✅")),
        );
      } else {
        print("➡️ Création d'une nouvelle commande");
        final itemsMaps = items.map((e) => e.toMap()).toList();
        print("Items envoyés: $itemsMaps");

        final res = await supabase.rpc('create_purchase', params: {
          'p_buyer_name': _buyerController.text,
          'p_payment': _paymentMethod,
          'p_gn': _gnController.text,
          'p_type': _purchaseType,
          'p_items': itemsMaps,
        }).maybeSingle();

        print("Résultat RPC: $res");

        if (res == null || res['purchase_id'] == null) {
          throw Exception("Impossible de créer l'achat");
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Achat créé ✅")),
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      print("❌ Erreur: $e");
      print("StackTrace: $st");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erreur: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<bool> _onWillPop() async {
    bool? shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.purchase != null
            ? "Abandonner la modification de l'achat"
            : "Abandonner la création de l'achat"),
        content: const Text(
            "Êtes-vous sûr(e) de vouloir quitter ? Toutes les données entrées seront perdues."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: const Text("Non"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Oui, quitter"),
          ),
        ],
      ),
    );

    return shouldLeave ?? false;
  }

  @override
  void dispose() {
    _buyerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalPreview = computeTotalPreview();
    final totalPV = computeTotalPV();

    return WillPopScope(
      onWillPop: () => _onWillPop(),
      child: Scaffold(
        appBar: AppBar(
          title:
              Text(widget.purchase != null ? "Modifier Achat" : "Nouvel Achat"),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GestionProduits()),
                );
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                    value: 'manage_products',
                    child: Text("Gestion des produits")),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(40),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.transparent),
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                  color: Colors.blueGrey,
                ),
                child: Text(
                    "Total montant: ${currencyFormat.format(totalPreview)} — Total PV: ${totalPV.toStringAsFixed(2)}", style: TextStyle(color: Colors.white),),

              ),
            ),
          ),
        ),
        body: _products.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextFormField(
                      controller: _buyerController,
                      decoration:
                          const InputDecoration(labelText: "Nom de l'acheteur"),
                      validator: (v) =>
                          v == null || v.isEmpty ? "Nom requis" : null,
                    ),
                    TextFormField(
                      controller: _gnController,
                      decoration: const InputDecoration(
                          labelText: 'GN (Matricule)'),
                      validator: (v) =>
                          v == null || v.isEmpty ? "Matricule requis" : null,
                    ),

                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _paymentMethod,
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text("Cash")),
                        DropdownMenuItem(
                            value: 'om', child: Text("Orange Money")),
                        DropdownMenuItem(value: 'debt', child: Text("Dette")),
                      ],
                      onChanged: (v) => setState(() => _paymentMethod = v!),
                      decoration:
                          const InputDecoration(labelText: "Mode de paiement"),
                    ),
                    DropdownButtonFormField<String>(
                      value: _purchaseType,
                      items: const [
                        DropdownMenuItem(
                            value: 'Rehaussement', child: Text("Rehaussement")),
                        DropdownMenuItem(
                            value: 'Retail', child: Text("Retail")),
                      ],
                      onChanged: (val) => setState(() => _purchaseType = val!),
                      decoration:
                          const InputDecoration(labelText: "Type d'achat"),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Veuillez choisir un type d\'achat';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),


                    Text("Produits", style: Theme.of(context).textTheme.titleMedium),
                    // 🔹 Indicateurs de page
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        (_products.length / 5).ceil(),
                            (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          width: _currentPage == index ? 12 : 8,
                          height: _currentPage == index ? 12 : 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPage == index ? Colors.blue : Colors.grey,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(
                      height: 480,
                      child: Column(
                        children: [
                          Expanded(
                            child: PageView.builder(
                              itemCount: (_products.length / 5).ceil(),
                              onPageChanged: (index) {
                                setState(() => _currentPage = index);
                              },
                              itemBuilder: (context, pageIndex) {
                                final start = pageIndex * 5;
                                final end = (start + 5) > _products.length
                                    ? _products.length
                                    : start + 5;
                                final pageProducts = _products.sublist(start, end);

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Column(
                                    children: pageProducts.map((p) {
                                      final qty = _quantities[p.id] ?? 0;
                                      final controller =
                                      TextEditingController(text: qty.toString());

                                      return Card(
                                        margin: const EdgeInsets.symmetric(vertical: 6),
                                        child: ListTile(
                                          title: Text(p.name),
                                          subtitle: Text(
                                              "GNF: ${currencyFormat.format(p.pricePartner)} — PV: ${p.pv}"),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove),
                                                onPressed: qty > 0
                                                    ? () => setState(() =>
                                                _quantities[p.id!] = qty - 1)
                                                    : null,
                                              ),

                                              // 🔹 TextField inline pour éditer la quantité
                                              SizedBox(
                                                width: 50,
                                                child: TextField(
                                                  controller: controller,
                                                  textAlign: TextAlign.center,
                                                  keyboardType: TextInputType.number,
                                                  decoration: const InputDecoration(
                                                    border: OutlineInputBorder(),
                                                    contentPadding: EdgeInsets.symmetric(
                                                        vertical: 4, horizontal: 4),
                                                  ),
                                                  onSubmitted: (val) {
                                                    final newQty = int.tryParse(val) ?? qty;
                                                    setState(() => _quantities[p.id!] = newQty);
                                                  },
                                                ),
                                              ),

                                              IconButton(
                                                icon: const Icon(Icons.add),
                                                onPressed: () =>
                                                    setState(() => _quantities[p.id!] = qty + 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),


        ElevatedButton(
                      onPressed: _loading ? null : _showSummaryBottomSheet,
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(widget.purchase != null
                              ? "Modifier"
                              : "Enregistrer"),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
