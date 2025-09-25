import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:longrich_supabase_stock/pages/gestion_categories.dart';
import 'package:longrich_supabase_stock/services/category_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../utils/utils.dart';

class GestionProduits extends StatefulWidget {
  const GestionProduits({super.key});

  @override
  State<GestionProduits> createState() => _GestionProduitsState();
}

class _GestionProduitsState extends State<GestionProduits> {
  late final ProductService _productService;
  late final CategoryService _categoryService;
  final TextEditingController _searchController = TextEditingController();

  bool _isSearching = false;
  bool _loading = true;

  List<Product> _allProducts = []; // 🔹 tous les produits (realtime)
  List<Category> _allCategorie = []; // 🔹 tous les produits (realtime)

  List<Product> _filteredProducts = []; // 🔹 produits affichés (filtrés)

  Category? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _productService = ProductService(supabase: Supabase.instance.client);
    _categoryService = CategoryService(supabase: Supabase.instance.client);

    _loadAllCategories(); // <- charge les catégories dès le départ

    // Ecoute en temps réel
    _productService.productsRealtime().listen((list) {
      setState(() {
        _allProducts = list;
        _applySearch(_searchController.text);
        _loading = false;
      });
    });

    _categoryService.categoriesRealtime().listen((list) {
      setState(() {
        _allCategorie = list;
        _applySearch(_searchController.text);
        _loading = false;
      });
    });
  }

  Future<void> _loadAllCategories() async {
    final categories = await _categoryService.getAllCategories();
    setState(() {
      _allCategorie = categories;
    });
  }

  // 🔹 Filtrage local
  void _applySearch(String keyword) {
    final kw = keyword.trim().toLowerCase();
    if (kw.isEmpty) {
      _filteredProducts = List.from(_allProducts);
    } else {
      final parsedNumber = double.tryParse(kw);

      _filteredProducts = _allProducts.where((p) {
        final matchText = p.name.toLowerCase().contains(kw) ||
            (p.description?.toLowerCase().contains(kw) ?? false);
        final matchNumber = parsedNumber != null &&
            (p.pricePartner.toString().contains(kw) ||
                p.pv.toString().contains(kw));
        return matchText || matchNumber;
      }).toList();
    }
    setState(() {});
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _applySearch(""); // reset
      FocusScope.of(context).unfocus();
    });
  }

// 🔹 Ajout / édition produit
  void _showProductForm({Product? product}) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final priceCtrl = TextEditingController(
        text: product != null ? product.pricePartner.toString() : '');
    final pvCtrl = TextEditingController(
        text: product != null ? product.pv.toString() : '');
    final descCtrl = TextEditingController(text: product?.description ?? '');
    bool saving = false;
    final uuid = const Uuid();
    if (_allCategorie.isNotEmpty) {
      _selectedCategory = product != null
          ? _allCategorie.firstWhere(
            (c) => c.id == product.categoryId,
        orElse: () => _allCategorie.first,
      )
          : _allCategorie.first;
    } else {
      _selectedCategory = null;
    }



    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      product == null
                          ? "Ajouter un produit"
                          : "Modifier le produit",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),

                    // 🔹 Sélection de catégorie
                    FutureBuilder<List<Category>>(
                      future: _categoryService.getAllCategories(),
                      builder: (context, snapshot) {
                        final categories = snapshot.data ?? [];
                        return DropdownButtonFormField<String>(
                          value: _selectedCategory
                              ?.id, // on utilise l'id au lieu de l'objet
                          items: categories
                              .map((c) => DropdownMenuItem<String>(
                                    value: c.id, // l'id de la catégorie
                                    child: Text(c.name),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedCategory =
                                  categories.firstWhere((c) => c.id == val);
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: "Catégorie",
                            border: OutlineInputBorder(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Nom
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                          labelText: "Nom du produit *",
                          border: OutlineInputBorder()),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? "Nom requis"
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Prix
                    TextFormField(
                      controller: priceCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: "Prix partenaire *",
                          border: OutlineInputBorder()),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty)
                          return "Prix requis";
                        return double.tryParse(val.replaceAll(',', '.')) == null
                            ? "Prix invalide"
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // PV
                    TextFormField(
                      controller: pvCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: "PV *", border: OutlineInputBorder()),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty)
                          return "PV requis";
                        return double.tryParse(val.replaceAll(',', '.')) == null
                            ? "PV invalide"
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: "Description",
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save),
                        label: Text(saving
                            ? "Enregistrement..."
                            : (product == null
                                ? "Enregistrer"
                                : "Mettre à jour")),
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => saving = true);

                                try {
                                  final newProduct = Product(
                                    id: product?.id ?? uuid.v4(),
                                    name: nameCtrl.text.trim(),
                                    pricePartner: double.parse(
                                        priceCtrl.text.replaceAll(',', '.')),
                                    pv: double.parse(
                                        pvCtrl.text.replaceAll(',', '.')),
                                    description: descCtrl.text.trim().isEmpty
                                        ? null
                                        : descCtrl.text.trim(),
                                    createdAt:
                                        product?.createdAt ?? DateTime.now(),
                                    categoryId: _selectedCategory?.id,
                                  );

                                  if (product == null) {
                                    await _productService
                                        .createProduct(newProduct);
                                  } else {
                                    await _productService
                                        .updateProduct(newProduct);
                                  }

                                  if (context.mounted) Navigator.pop(context);
                                } catch (err) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text("Erreur: $err"),
                                          backgroundColor: Colors.red),
                                    );
                                  }
                                } finally {
                                  setModalState(() => saving = false);
                                }
                              },
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  // 🔹 Suppression produit
  Future<void> _deleteProduct(Product p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer le produit"),
        content: Text("Voulez-vous vraiment supprimer « ${p.name} » ?"),
        actions: [
          TextButton(
            child: const Text("Annuler"),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            child: const Text("Supprimer"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _productService.deleteProduct(p.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Produit supprimé"),
          backgroundColor: Colors.green,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return WillPopScope(
      onWillPop: () async {
        if (_isSearching) {
          _closeSearch();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  maxLength: 150,
                  onChanged: _applySearch, // 🔹 filtre local uniquement
                  decoration: InputDecoration(
                    hintText: "Rechercher par nom, prix, pv, ou description".tr,
                    focusedBorder: InputBorder.none,
                    counterText: "",
                    border: InputBorder.none,
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onBackground.withOpacity(0.6)),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.close, color: colorScheme.onBackground),
                      onPressed: _closeSearch,
                    ),
                  ),
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: colorScheme.onBackground),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Gestion des produits",
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: colorScheme.onBackground)),
                    IconButton(
                        icon: Icon(Icons.search, color: colorScheme.primary),
                        onPressed: () => setState(() => _isSearching = true))
                  ],
                ),
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
                  "${_filteredProducts.length} produits",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _filteredProducts.isEmpty
                ? const Center(child: Text("Aucun produit"))
                : ListView.separated(
                    itemCount: _filteredProducts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = _filteredProducts[i];
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text(
                            "Prix: ${currencyFormat.format(p.pricePartner)} | PV: ${p.pv}"), // seulement prix et PV
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'edit') {
                              _showProductForm(product: p);
                            } else if (val == 'delete') {
                              _deleteProduct(p);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'edit', child: Text("Modifier")),
                            PopupMenuItem(
                                value: 'delete', child: Text("Supprimer")),
                          ],
                        ),
                        onTap: () {
                          // Affiche le bottomsheet avec toutes les infos
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            builder: (context) {
                              final categoryName = _allCategorie.firstWhere(
                                    (c) => c.id == p.categoryId,
                                orElse: () => Category(id: '', name: '-', description: null),
                              ).name;

                              return Padding(
                                padding: EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  top: 16,
                                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Nom du produit
                                      Text(
                                        p.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 12),

                                      // Infos clés (Prix et PV)
                                      Row(
                                        children: [
                                          Chip(
                                            label: Text("Prix: ${currencyFormat.format(p.pricePartner)} GNF"),
                                            backgroundColor: Colors.blue.shade50,
                                          ),
                                          const SizedBox(width: 8),
                                          Chip(
                                            label: Text("PV: ${p.pv}"),
                                            backgroundColor: Colors.green.shade50,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      // Catégorie
                                      Row(
                                        children: [
                                          const Icon(Icons.category, size: 20, color: Colors.grey),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Catégorie: $categoryName",
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Description
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.description, size: 20, color: Colors.grey),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              "Description: ${p.description ?? '-'}",
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Date de création
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Créé le: ${p.createdAt != null ? p.createdAt!.toLocal().toString().split('.')[0] : '-'}",
                                            style: const TextStyle(fontSize: 16),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),

                                      // Bouton fermer
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.close),
                                          onPressed: () => Navigator.pop(context),
                                          label: const Text("Fermer"),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            textStyle: const TextStyle(fontSize: 16),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );

                        },
                      );
                    },
                  ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Que voulez-vous effectuer ?",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: const Text("Ajouter un produit"),
                        onTap: () {
                          Navigator.pop(context); // ferme le bottomsheet
                          _showProductForm(); // ouvre le formulaire produit
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.category),
                        title: const Text("Gérer les catégories"),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GestionCategories(),
                              )); // ferme le bottomsheet
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
