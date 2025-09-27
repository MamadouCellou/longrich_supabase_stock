// lib/pages/summary_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/purchase_item.dart';

class SummaryPage extends StatefulWidget {
  final String buyer;
  final String gn;
  final String paymentMethod;
  final String purchaseType;
  final List<Product> products;
  final List<PurchaseItem> items;
  final Map<String, int> missingQuantities; // passé par ref
  final NumberFormat currencyFormat;
  final Future<void> Function()? onSubmit;
  final bool loading;

  const SummaryPage({
    super.key,
    required this.buyer,
    required this.gn,
    required this.paymentMethod,
    required this.purchaseType,
    required this.products,
    required this.items,
    required this.missingQuantities,
    required this.currencyFormat,
    this.onSubmit,
    this.loading = false,
  });

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = false; // 👈 local au widget

  @override
  void initState() {
    super.initState();
    for (final item in widget.items) {
      widget.missingQuantities[item.productId] ??= 0;
      _controllers[item.productId] = TextEditingController(
        text: widget.missingQuantities[item.productId]!.toString(),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get totalPreview {
    double sum = 0;
    for (final item in widget.items) {
      final prod = widget.products.firstWhere(
            (p) => p.id == item.productId,
        orElse: () => Product(
          id: item.productId,
          name: item.productName,
          pricePartner: item.unitPrice,
          pv: item.unitPv,
          description: null,
          createdAt: null,
        ),
      );
      sum += prod.pricePartner * item.quantityTotal;
    }
    return sum;
  }

  double get totalPV {
    double sum = 0;
    for (final item in widget.items) {
      final prod = widget.products.firstWhere(
            (p) => p.id == item.productId,
        orElse: () => Product(
          id: item.productId,
          name: item.productName,
          pricePartner: item.unitPrice,
          pv: item.unitPv,
          description: null,
          createdAt: null,
        ),
      );
      sum += prod.pv * item.quantityTotal;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Résumé de la commande"),
      ),
      body: widget.items.isEmpty
          ? Center(
        child: Text(
          "Aucun produit sélectionné",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Acheteur : ${widget.buyer}",
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text("Matricule : ${widget.gn}"),
          const SizedBox(height: 4),
          Text("Type d'achat : ${widget.purchaseType}"),
          const SizedBox(height: 4),
          Text("Mode de paiement : ${widget.paymentMethod}"),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total montant:",
                  style: Theme.of(context).textTheme.titleSmall),
              Text("${widget.currencyFormat.format(totalPreview)} GNF",
                  style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total PV:",
                  style: Theme.of(context).textTheme.titleSmall),
              Text("${totalPV.toStringAsFixed(2)}",
                  style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const Divider(height: 24),

          // --- Liste des produits avec ExpansionTile ---
          ...widget.items.map((item) {
            final product = widget.products.firstWhere(
                  (p) => p.id == item.productId,
              orElse: () => Product(
                id: item.productId,
                name: item.productName,
                pricePartner: item.unitPrice,
                pv: item.unitPv,
                description: null,
                createdAt: null,
              ),
            );
            final controller = _controllers[product.id]!;
            final allReceived =
                (widget.missingQuantities[product.id] ?? 0) == 0;

            return ExpansionTile(
              backgroundColor: Colors.transparent,
              collapsedBackgroundColor: Colors.transparent,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero),
              collapsedShape: const RoundedRectangleBorder(
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
                      setState(() {
                        widget.missingQuantities[product.id!] =
                        val! ? 0 : item.quantityTotal;
                        controller.text = widget
                            .missingQuantities[product.id]!
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
                              if (m > item.quantityTotal) {
                                m = item.quantityTotal;
                              }
                            }
                            setState(() {
                              widget.missingQuantities[product.id!] = m;
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
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),

          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _loading
                ? null
                : () async {
              setState(() => _loading = true); // 👈 active le spinner
              try {
                if (widget.onSubmit != null) {
                  await widget.onSubmit!();
                } else {
                  Navigator.of(context).maybePop();
                }
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Confirmer et enregistrer",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
