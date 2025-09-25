import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category.dart';

class CategoryService {
  final SupabaseClient supabase;

  CategoryService({required this.supabase});

  Future<List<Category>> getAllCategories() async {
    final res = await supabase.from('categories').select().order('name');
    return List<Map<String, dynamic>>.from(res)
        .map((m) => Category.fromMap(m))
        .toList();
  }

  Future<Category?> createCategory(Category c) async {
    final res = await supabase.from('categories').insert(c.toMap()).select().maybeSingle();
    return res != null ? Category.fromMap(res) : null;
  }

  Future<Category?> updateCategory(Category c) async {
    if (c.id == null) return null;
    final res = await supabase
        .from('categories')
        .update(c.toMap())
        .eq('id', c.id!)
        .select()
        .maybeSingle();
    return res != null ? Category.fromMap(res) : null;
  }

  Future<bool> deleteCategory(String id) async {
    final res = await supabase.from('categories').delete().eq('id', id).select();
    return res != null && (res as List).isNotEmpty;
  }

  Stream<List<Category>> categoriesRealtime() {
    final controller = StreamController<List<Category>>();

    // Écoute les changements sur la table "products"
    final subscription = supabase
        .from('categories')
        .stream(primaryKey: ['id'])
        .listen((data) {
      final categories = List<Map<String, dynamic>>.from(data)
          .map((m) => Category.fromMap(m))
          .toList();
      controller.add(categories);
    });

    // Gestion de l'arrêt du stream
    controller.onCancel = () {
      subscription.cancel();
    };

    return controller.stream;
  }
}
