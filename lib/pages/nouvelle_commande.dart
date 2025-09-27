import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:longrich_supabase_stock/pages/gestion_produits.dart';
import 'package:longrich_supabase_stock/pages/summary_page.dart';
import 'package:longrich_supabase_stock/utils/snackbars.dart';
import 'package:longrich_supabase_stock/utils/utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../models/purchase.dart';
import '../models/purchase_item.dart';
import '../services/category_service.dart';
import '../services/product_service.dart';

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

  Category? _selectedCategory; // catégorie sélectionnée
  List<Category> _allCategorie = []; // 🔹 tous les produits (realtime)

  late final CategoryService _categoryService;
  late final ProductService _productService;

  @override
  void initState() {
    super.initState();

    _loadProducts();
    _productService = ProductService(supabase: Supabase.instance.client);
    _categoryService = CategoryService(supabase: Supabase.instance.client);

    _categoryService.categoriesRealtime().listen((list) {
      setState(() {
        _allCategorie = list;
        _selectedCategory = list.first;
      });
    });

    // Ecoute en temps réel
    _productService.productsRealtime().listen((list) {
      setState(() {
        _products = list;
      });
    });

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

  Future<void> _handleSubmit() async {
    setState(() => _loading = true);
    await _submit();
    setState(() => _loading = false);
  }

  Future<void> _showSummaryBottomSheet() async {
    // items = buildItems(_products) -> List<PurchaseItem>
    final items = buildItems(_products);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SummaryPage(
          buyer: _buyerController.text,
          gn: _gnController.text,
          paymentMethod: _paymentMethod,
          purchaseType: _purchaseType,
          products: _products,
          items: items,
          missingQuantities: _missingQuantities, // passed by reference
          currencyFormat: currencyFormat,
          loading: _loading,
          onSubmit:
              _handleSubmit, // ta méthode existante (Future<void> _submit())
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return showErrorSnackbar(
          context: context, message: "Tous les champs sont obligatoires");
    }

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
        showSucessSnackbar(context: context, message: "Achat modifié ✅");
        _resetForm();
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

        showSucessSnackbar(context: context, message: "Achat créé ✅");
        _resetForm();
      }

      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      print("❌ Erreur: $e");
      print("StackTrace: $st");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.purchase != null
              ? "Erreur lors de la modification"
              : "Erreur lors de l'ajout")));
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

  // 🔹 Dans ton State
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _buyerController.dispose();
    _pageController.dispose();
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
                  "Total montant: ${currencyFormat.format(totalPreview)} — Total PV: ${totalPV.toStringAsFixed(2)}",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        body: _products.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Padding(
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: PageView(
                    physics: NeverScrollableScrollPhysics(),
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    children: [
                      Column(
                        children: [
                          TextFormField(
                            controller: _buyerController,
                            decoration: const InputDecoration(
                                labelText: "Nom de l'acheteur"),
                            validator: (v) =>
                                v == null || v.isEmpty ? "Nom requis" : null,
                          ),
                          TextFormField(
                            controller: _gnController,
                            decoration: const InputDecoration(
                                labelText: 'GN (Matricule)'),
                            validator: (v) => v == null || v.isEmpty
                                ? "Matricule requis"
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _paymentMethod,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'cash', child: Text("Cash")),
                                    DropdownMenuItem(
                                        value: 'om',
                                        child: Text("Orange Money")),
                                    DropdownMenuItem(
                                        value: 'debt', child: Text("Dette")),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _paymentMethod = v!),
                                  decoration: const InputDecoration(
                                      labelText: "Mode de paiement"),
                                ),
                              ),
                              const SizedBox(
                                  width: 12), // espace entre les deux
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _purchaseType,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'Rehaussement',
                                        child: Text("Rehaussement")),
                                    DropdownMenuItem(
                                        value: 'Retail', child: Text("Retail")),
                                  ],
                                  onChanged: (val) =>
                                      setState(() => _purchaseType = val!),
                                  decoration: const InputDecoration(
                                      labelText: "Type d'achat"),
                                  validator: (val) {
                                    if (val == null || val.isEmpty) {
                                      return 'Veuillez choisir un type d\'achat';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Titre
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Produits",
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              GestureDetector(
                                onTap: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text("Confirmation"),
                                      content: const Text(
                                        "Voulez-vous vraiment réinitialiser la quantité de tous les produits à 0 ?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context)
                                              .pop(false), // Annuler
                                          child: const Text("Annuler"),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.of(context)
                                              .pop(true), // Confirmer
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.red.shade300),
                                          child:
                                              const Text("Oui, réinitialiser"),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    setState(() {
                                      for (var p in _products) {
                                        _quantities[p.id!] = 0;
                                      }
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            "Toutes les quantités ont été réinitialisées ✅"),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                child: Text(
                                  "Tout à zéro",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // 🔹 Liste horizontale des catégories
                          SizedBox(
                            height: 40,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _allCategorie.length,
                              itemBuilder: (context, index) {
                                final cat = _allCategorie[index];
                                final isSelected =
                                    _selectedCategory?.id == cat.id;

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedCategory = cat;
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blue
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Center(
                                      child: Text(
                                        cat.name,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 🔹 Liste des produits filtrée par catégorie
                          SizedBox(
                            height:
                                480, // hauteur fixe pour éviter Expanded dans ListView
                            child: _selectedCategory == null
                                ? Center(
                                    child: Text(
                                      "Veuillez sélectionner une catégorie",
                                      style: TextStyle(
                                          color: Colors.grey.shade600),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _products
                                        .where((p) =>
                                            p.categoryId ==
                                            _selectedCategory!.id)
                                        .length,
                                    itemBuilder: (context, index) {
                                      final product = _products
                                          .where((p) =>
                                              p.categoryId ==
                                              _selectedCategory!.id)
                                          .toList()[index];
                                      final qty = _quantities[product.id] ?? 0;
                                      final controller = TextEditingController(
                                          text: qty.toString());

                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        child: ListTile(
                                          title: Text(product.name),
                                          subtitle: Text(
                                              "GNF: ${currencyFormat.format(product.pricePartner)} — PV: ${product.pv}"),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove),
                                                onPressed: qty > 0
                                                    ? () => setState(() =>
                                                        _quantities[product
                                                            .id!] = qty - 1)
                                                    : null,
                                              ),
                                              SizedBox(
                                                width: 60,
                                                child: TextField(
                                                  controller: controller,
                                                  textAlign: TextAlign.center,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration:
                                                      const InputDecoration(
                                                    border:
                                                        OutlineInputBorder(),
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                            vertical: 4,
                                                            horizontal: 4),
                                                  ),
                                                  onSubmitted: (val) {
                                                    final newQty =
                                                        int.tryParse(val) ??
                                                            qty;
                                                    setState(() => _quantities[
                                                        product.id!] = newQty);
                                                  },
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.add),
                                                onPressed: () => setState(() =>
                                                    _quantities[product.id!] =
                                                        qty + 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          SizedBox(
                            height: 16,
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        bottomSheet: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
              ),
              onPressed: _loading
                  ? null
                  : () {
                      if (_currentPage == 0) {
                        // 👉 Page 1 : on valide d'abord le formulaire
                        if (!_formKey.currentState!.validate() ||
                            _buyerController.text.trim().isEmpty ||
                            _gnController.text.trim().isEmpty) {
                          showErrorSnackbar(
                            context: context,
                            message: "Tous les champs sont obligatoires",
                          );
                          return;
                        }

                        // ✅ Formulaire valide → aller à la page 2
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        // 👉 Page 2 : on vérifie les produits
                        final items = buildItems(_products);
                        if (items.isEmpty) {
                          showErrorSnackbar(
                            context: context,
                            message: "Veuillez ajouter au moins un produit",
                          );
                          return;
                        }

                        // 🚨 Vérifier aussi que le formulaire est toujours valide
                        if (!_formKey.currentState!.validate() ||
                            _buyerController.text.trim().isEmpty ||
                            _gnController.text.trim().isEmpty) {
                          showErrorSnackbar(
                            context: context,
                            message:
                                "Veuillez remplir correctement le formulaire",
                          );
                          // 👉 On force le retour à la page 1
                          _pageController.jumpToPage(0);
                          setState(() {
                            _currentPage = 0;
                          });
                          return;
                        }

                        // ✅ Si tout est bon → lancer le résumé
                        _showSummaryBottomSheet();
                      }
                    },
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _currentPage == 0
                          ? "Continuer à sélectionner les produits"
                          : (widget.purchase != null
                              ? "Résumé et modification"
                              : "Résumé et ajout"),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _resetForm() {
    _pageController.jumpToPage(0);
    setState(() {
      _currentPage = 0;
      // 🔹 Si tu as un formKey, on reset aussi la validation
      _formKey.currentState?.reset();

      // 🔹 Réinitialiser les TextEditingController
      _buyerController.clear();
      _gnController.clear();

      // 🔹 Réinitialiser les Dropdowns
      _paymentMethod = 'cash'; // valeur par défaut
      _purchaseType = 'Rehaussement'; // valeur par défaut

      // 🔹 Réinitialiser les quantités de produits
      _quantities.clear();
    });
  }
}
