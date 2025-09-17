import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:longrich_supabase_stock/utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/product.dart';
import 'models/purchase.dart';
import 'models/purchase_item.dart';

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

  Map<String, int> _quantities = {};
  Map<String, int> _missingQuantities = {};
  List<Product> _products = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();

    if (widget.purchase != null && widget.purchaseItems != null) {
      _buyerController.text = widget.purchase!.buyerName;
      _paymentMethod = widget.purchase!.paymentMethod;
      for (var item in widget.purchaseItems!) {
        _quantities[item.productId] = item.quantityTotal;
        _missingQuantities[item.productId] = item.quantityMissing;
      }
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
        productId: product.id,
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
                        backgroundColor: Colors.transparent,        // fond ouvert
                        collapsedBackgroundColor: Colors.transparent, // fond fermé
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
                                  _missingQuantities[product.id] =
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
                                        _missingQuantities[product.id] = m;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez ajouter au moins un produit")),
      );
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
          await supabase.from('purchase_items').insert({
            'purchase_id': purchaseId,
            'product_id': product.id,
            'product_name': product.name,
            'unit_price': product.pricePartner,
            'unit_pv': product.pv,
            ...item.toMap(),
          });
        }

        await supabase.from('purchases').update({
          'buyer_name': _buyerController.text,
          'payment_method': _paymentMethod,
        }).eq('id', purchaseId);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Achat modifié ✅")),
        );
      } else {
        final res = await supabase.rpc('create_purchase', params: {
          'p_buyer_name': _buyerController.text,
          'p_payment': _paymentMethod,
          'p_items': items.map((e) => e.toMap()).toList(),
        }).maybeSingle();

        if (res == null || res['purchase_id'] == null) {
          throw Exception("Impossible de créer l'achat");
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Achat créé ✅")),
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      print("Erreur: $e");
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
        ),
        body: _products.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      child: Text(
                          "Total prévisionnel: ${currencyFormat.format(totalPreview)} — Total PV: ${totalPV.toStringAsFixed(2)}"),
                    ),
                    TextFormField(
                      controller: _buyerController,
                      decoration:
                          const InputDecoration(labelText: "Nom de l'acheteur"),
                      validator: (v) =>
                          v == null || v.isEmpty ? "Nom requis" : null,
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
                    const SizedBox(height: 20),
                    Text("Produits",
                        style: Theme.of(context).textTheme.titleMedium),

// PageView des produits (5 produits max par page)
                    SizedBox(
                      height: 450, // ajuste selon ton design
                      child: PageView.builder(
                        itemCount: (_products.length / 5).ceil(),
                        itemBuilder: (context, pageIndex) {
                          final start = pageIndex * 5;
                          final end = (start + 5) > _products.length
                              ? _products.length
                              : start + 5;
                          final pageProducts = _products.sublist(start, end);

                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Column(
                              children: pageProducts.map((p) {
                                final qty = _quantities[p.id] ?? 0;
                                final missing = _missingQuantities[p.id] ?? 0;

                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 6),
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
                                                  _quantities[p.id] = qty - 1)
                                              : null,
                                        ),
                                        Text("$qty"),
                                        IconButton(
                                          icon: const Icon(Icons.add),
                                          onPressed: qty < p.stock
                                              ? () => setState(() =>
                                                  _quantities[p.id] = qty + 1)
                                              : null,
                                        ),
                                      ],
                                    ),
                                    onTap: () async {},
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
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
