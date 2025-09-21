import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchase.dart';

class PurchaseService {
  final SupabaseClient supabase;

  PurchaseService({required this.supabase});

  /// ✅ Créer une commande
  Future<Purchase?> createPurchase(Purchase purchase) async {
    final res = await supabase
        .from('purchases')
        .insert(purchase.toMap())
        .select()
        .maybeSingle();

    if (res != null) return Purchase.fromMap(res as Map<String, dynamic>);
    return null;
  }

  /// ✅ Récupérer toutes les commandes
  Future<List<Purchase>> getAllPurchases() async {
    final res = await supabase
        .from('purchases')
        .select('*')
        .order('created_at', ascending: false);

    if (res == null) return [];
    return List<Map<String, dynamic>>.from(res)
        .map((m) => Purchase.fromMap(m))
        .toList();
  }

  /// ✅ Récupérer une commande par ID
  Future<Purchase?> getPurchaseById(String id) async {
    final res = await supabase
        .from('purchases')
        .select('*')
        .eq('id', id)
        .maybeSingle();

    if (res != null) return Purchase.fromMap(res as Map<String, dynamic>);
    return null;
  }

  /// ✅ Mettre à jour une commande
  Future<Purchase?> updatePurchase(Purchase purchase) async {
    if (purchase.id == null) return null;

    final res = await supabase
        .from('purchases')
        .update(purchase.toMap())
        .eq('id', purchase.id!) // ✅ forcer non-null
        .select()
        .maybeSingle();

    if (res != null) return Purchase.fromMap(res as Map<String, dynamic>);
    return null;
  }

  /// ✅ Supprimer une commande
  Future<bool> deletePurchase(String id) async {
    final res =
    await supabase.from('purchases').delete().eq('id', id).select();
    return res != null;
  }

  /// ✅ Stream realtime (pas besoin de .select ici)
  Stream<List<Purchase>> purchasesRealtime() {
    return supabase
        .from('purchases_with_total')
        .stream(primaryKey: ['id'])
        .map((data) {
      return List<Map<String, dynamic>>.from(data)
          .map((m) => Purchase.fromMap(m))
          .toList();
    });
  }

}
