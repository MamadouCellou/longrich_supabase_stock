import 'package:flutter/material.dart';
import 'package:longrich_supabase_stock/utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NewPurchasePage extends StatefulWidget {
  final Map<String, dynamic>? purchase;
  final List<Map<String, dynamic>>? purchaseItems;

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
  List<Map<String, dynamic>> _products = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    if (widget.purchase != null && widget.purchaseItems != null) {
      _buyerController.text = widget.purchase!['buyer_name'] ?? '';
      _paymentMethod = widget.purchase!['payment_method'] ?? 'cash';
      for (var item in widget.purchaseItems!) {
        _quantities[item['product_id']] = item['quantity_total'] ?? 0;
        _missingQuantities[item['product_id']] = item['quantity_missing'] ?? 0;
      }
    }
  }

  Future<void> _loadProducts() async {
    final res = await supabase.from('products').select().order('created_at');
    if (res != null) {
      setState(() => _products = List<Map<String, dynamic>>.from(res));
    }
  }

  double computeTotalPreview() {
    double total = 0;
    for (final p in _products) {
      final pid = p['id'] as String;
      final unit = (p['price_partner'] as num?)?.toDouble() ?? 0;
      final qty = _quantities[pid] ?? 0;
      total += unit * qty;
    }
    return total;
  }

  double computeTotalPV() {
    double totalPV = 0;
    for (final p in _products) {
      final pid = p['id'] as String;
      final pv = (p['pv'] as num).toDouble();
      final qty = _quantities[pid] ?? 0;
      totalPV += pv * qty;
    }
    return totalPV;
  }

  Future<void> _showSummaryBottomSheet() async {
    final totalPreview = computeTotalPreview();
    final totalPV = computeTotalPV();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Résumé de la commande",
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text("Acheteur : ${_buyerController.text}"),
                  Text("Mode de paiement : $_paymentMethod"),
                  Text(
                      "Total Montant : ${currencyFormat.format(totalPreview)} GNF"),
                  Text("Total PV : ${totalPV.toStringAsFixed(2)}"),
                  const Divider(),
                  ..._products.map((p) {
                    final pid = p['id'] as String;
                    final qty = _quantities[pid] ?? 0;
                    if (qty == 0) return const SizedBox.shrink();

                    final missing = _missingQuantities[pid] ?? 0;
                    final allReceived = missing == 0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text("$qty × ${p['name']}")),
                            Checkbox(
                              value: allReceived,
                              onChanged: (val) {
                                setModalState(() {
                                  _missingQuantities[pid] = val! ? 0 : 1;
                                });
                              },
                            ),
                            const Text("Tout reçu"),
                          ],
                        ),
                        if (!allReceived)
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: missing.toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "Quantité manquante",
                                  ),
                                  onChanged: (val) {
                                    final m = int.tryParse(val) ?? 0;
                                    setModalState(() {
                                      _missingQuantities[pid] =
                                      (m > qty) ? qty : m;
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
                              )
                            ],
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
            );
          },
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final items = _quantities.entries
        .where((e) => e.value > 0)
        .map((e) {
      final pid = e.key;
      final qtyTotal = e.value;
      final missing = _missingQuantities[pid] ?? 0;
      final received = qtyTotal - missing;
      return {
        'product_id': pid,
        'quantity_total': qtyTotal,
        'quantity_received': received,
        'quantity_missing': missing,
      };
    })
        .toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez ajouter au moins un produit")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      if (widget.purchase != null) {
        final purchaseId = widget.purchase!['id'];

        await supabase
            .from('purchase_items')
            .delete()
            .eq('purchase_id', purchaseId);

        for (final item in items) {
          final p = _products.firstWhere((p) => p['id'] == item['product_id']);
          await supabase.from('purchase_items').insert({
            'purchase_id': purchaseId,
            'product_id': p['id'],
            'product_name': p['name'],
            'unit_price': p['price_partner'],
            'unit_pv': p['pv'],
            'quantity_total': item['quantity_total'],
            'quantity_received': item['quantity_received'],
            'quantity_missing': item['quantity_missing'],
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
          'p_items': items,
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

  @override
  void dispose() {
    _buyerController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    bool? shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.purchase != null ? "Abandonner la modification de l'achat" : "Abandonner la création de l'achat"),
        content: const Text(
            "Êtes-vous sûr(e) de vouloir quitter ? Toutes les données entrées seront perdues."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false); // Rester sur la page
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
              const SizedBox(height: 8),
              ..._products.map((p) {
                final productId = p['id'] as String;
                final name = p['name'] as String;
                final price = (p['price_partner'] as num).toDouble();
                final stock = p['stock'] as int;
                final pv = (p['pv'] as num).toDouble();
                final qty = _quantities[productId] ?? 0;
                final missing = _missingQuantities[productId] ?? 0;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(name),
                    subtitle: Text(
                        "GNF: ${currencyFormat.format(price)} — Stock: $stock — PV: $pv"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: qty > 0
                              ? () => setState(
                                  () => _quantities[productId] = qty - 1)
                              : null,
                        ),
                        Text("$qty"),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: qty < stock
                              ? () => setState(
                                  () => _quantities[productId] = qty + 1)
                              : null,
                        ),
                      ],
                    ),
                    onTap: () async {
                      if (qty > 0) {
                        final ctrl =
                        TextEditingController(text: missing.toString());
                        final newMissing = await showDialog<int>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text("Quantité manquante — $name"),
                            content: TextField(
                              controller: ctrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Quantité manquante",
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, null),
                                child: const Text("Annuler"),
                              ),
                              TextButton(
                                onPressed: () {
                                  final v = int.tryParse(ctrl.text) ?? 0;
                                  Navigator.pop(context, v);
                                },
                                child: const Text("OK"),
                              ),
                            ],
                          ),
                        );
                        if (newMissing != null && newMissing <= qty) {
                          setState(
                                  () => _missingQuantities[productId] = newMissing);
                        }
                      }
                    },
                  ),
                );
              }).toList(),
              const SizedBox(height: 16),
              Text(
                  "Total prévisionnel: ${currencyFormat.format(totalPreview)} — Total PV: ${totalPV.toStringAsFixed(2)}"),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading ? null : _showSummaryBottomSheet,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(widget.purchase != null ? "Modifier" : "Enregistrer"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
