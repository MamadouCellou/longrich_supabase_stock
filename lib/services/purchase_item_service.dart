import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchase_item.dart';

class PurchaseItemService {
  final SupabaseClient supabase;

  PurchaseItemService({required this.supabase});

  /// ✅ Créer un élément d'achat
  Future<PurchaseItem?> createPurchaseItem(PurchaseItem item) async {
    final res = await supabase
        .from('purchase_items')
        .insert(item.toMap())
        .select()
        .maybeSingle();

    if (res != null) return PurchaseItem.fromMap(res as Map<String, dynamic>);
    return null;
  }

  /// ✅ Récupérer tous les éléments d'achat
  Future<List<PurchaseItem>> getAllPurchaseItems() async {
    final res = await supabase
        .from('purchase_items')
        .select('*')
        .order('created_at', ascending: false);

    if (res == null) return [];
    return List<Map<String, dynamic>>.from(res)
        .map((m) => PurchaseItem.fromMap(m))
        .toList();
  }

  /// ✅ Récupérer un élément par ID
  Future<PurchaseItem?> getPurchaseItemById(String id) async {
    final res = await supabase
        .from('purchase_items')
        .select('*')
        .eq('id', id)
        .maybeSingle();

    if (res != null) return PurchaseItem.fromMap(res as Map<String, dynamic>);
    return null;
  }

  /// ✅ Récupérer tous les items d’une commande donnée
  Future<List<PurchaseItem>> getItemsByPurchaseId(String purchaseId) async {
    final res = await supabase
        .from('purchase_items')
        .select('*')
        .eq('purchase_id', purchaseId);

    if (res == null) return [];
    return List<Map<String, dynamic>>.from(res)
        .map((m) => PurchaseItem.fromMap(m))
        .toList();
  }

  /// ✅ Mettre à jour un élément
  Future<PurchaseItem?> updatePurchaseItem(PurchaseItem item) async {
    if (item.id == null) return null;

    final res = await supabase
        .from('purchase_items')
        .update(item.toMap())
        .eq('id', item.id!) // ✅ on force non-null
        .select()
        .maybeSingle();

    if (res != null) return PurchaseItem.fromMap(res as Map<String, dynamic>);
    return null;
  }

  /// ✅ Supprimer un élément
  Future<bool> deletePurchaseItem(String id) async {
    final res =
    await supabase.from('purchase_items').delete().eq('id', id).select();
    return res != null;
  }

  /// ✅ Stream realtime (pas de .select ici)
  Stream<List<PurchaseItem>> purchaseItemsRealtime() {
    return supabase
        .from('purchase_items')
        .stream(primaryKey: ['id'])
        .map((data) {
      return List<Map<String, dynamic>>.from(data)
          .map((m) => PurchaseItem.fromMap(m))
          .toList();
    });
  }
}
