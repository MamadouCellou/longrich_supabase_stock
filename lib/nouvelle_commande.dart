import 'dart:convert';
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
        _quantities[item['product_id']] = item['quantity'];
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
      final unit = (p['price_partner'] as num).toDouble();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final items = _quantities.entries
        .where((e) => e.value > 0)
        .map((e) => {'product_id': e.key, 'quantity': e.value})
        .toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Veuillez ajouter au moins un produit")));
      return;
    }

    setState(() => _loading = true);
    try {
      if (widget.purchase != null) {
        // MODIFICATION
        final purchaseId = widget.purchase!['id'];
        await supabase
            .from('purchase_items')
            .delete()
            .eq('purchase_id', purchaseId);
        for (var item in items) {
          final p = _products.firstWhere((p) => p['id'] == item['product_id']);
          await supabase.from('purchase_items').insert({
            'purchase_id': purchaseId,
            'product_id': p['id'],
            'product_name': p['name'],
            'unit_price': p['price_partner'],
            'unit_pv': p['pv'],
            'quantity': item['quantity'],
          });
        }
        await supabase.from('purchases').update({
          'buyer_name': _buyerController.text,
          'payment_method': _paymentMethod,
        }).eq('id', purchaseId);

        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Achat modifié ✅")));
      } else {
        // CREATION via RPC
        final res = await supabase.rpc('create_purchase', params: {
          'p_buyer_name': _buyerController.text,
          'p_payment': _paymentMethod,
          'p_items': items,
        }).maybeSingle();

        if (res == null || res['purchase_id'] == null) {
          throw Exception("Impossible de créer l'achat");
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Achat créé ✅")));
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

  @override
  Widget build(BuildContext context) {
    final totalPreview = computeTotalPreview();
    final totalPV = computeTotalPV();

    return Scaffold(
      appBar: AppBar(
          title: Text(
              widget.purchase != null ? "Modifier Achat" : "Nouvel Achat")),
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
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(name),
                        subtitle: Text(
                            "GNF: ${currencyFormat.format(price)} — Stock: $stock — PV : $pv"),
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
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 16),
                  Text(
                      "Total prévisionnel: ${currencyFormat.format(totalPreview)} — Total PV: ${totalPV.toStringAsFixed(2)}"),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(widget.purchase != null
                            ? "Modifier"
                            : "Enregistrer"),
                  )
                ],
              ),
            ),
    );
  }
}
