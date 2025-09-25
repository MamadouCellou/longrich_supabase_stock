import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';
import '../services/category_service.dart';

class GestionCategories extends StatefulWidget {
  const GestionCategories({super.key});

  @override
  State<GestionCategories> createState() => _GestionCategoriesState();
}

class _GestionCategoriesState extends State<GestionCategories> {
  final CategoryService _categoryService = CategoryService(supabase: Supabase.instance.client);
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final _uuid = const Uuid();

  Category? _editingCategory;

  Stream<List<Category>> _categoriesStream() {
    final client = Supabase.instance.client;
    return client
        .from('categories')
        .stream(primaryKey: ['id'])
        .order('name')
        .map((maps) => maps.map((m) => Category.fromMap(m)).toList());
  }

  Future<void> _saveCategory() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Le nom de la catégorie est requis"),
            backgroundColor: Colors.red),
      );
      return;
    }

    final category = Category(
      id: _editingCategory?.id ?? _uuid.v4(),
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      createdAt: _editingCategory?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (_editingCategory == null) {
      await _categoryService.createCategory(category);
    } else {
      await _categoryService.updateCategory(category);
    }

    _nameCtrl.clear();
    _descCtrl.clear();
    _editingCategory = null;
  }

  Future<void> _deleteCategory(Category c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer la catégorie"),
        content: Text("Voulez-vous vraiment supprimer la catégorie « ${c.name} » ?"),
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
      await _categoryService.deleteCategory(c.id!);
    }
  }

  void _editCategory(Category c) {
    setState(() {
      _editingCategory = c;
      _nameCtrl.text = c.name;
      _descCtrl.text = c.description ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion des catégories"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Formulaire
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: "Nom de la catégorie",
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: Text(_editingCategory == null ? "Ajouter" : "Mettre à jour"),
                onPressed: _saveCategory,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Liste des catégories en temps réel
            Expanded(
              child: StreamBuilder<List<Category>>(
                stream: _categoriesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final categories = snapshot.data ?? [];
                  if (categories.isEmpty) {
                    return const Center(child: Text("Aucune catégorie"));
                  }

                  return ListView.separated(
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final c = categories[i];
                      return ListTile(
                        title: Text(c.name),
                        subtitle: Text(c.description ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editCategory(c),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteCategory(c),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
