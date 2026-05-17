
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(
    '${Platform.environment['SUPABASE_URL']}',
    '${Platform.environment['SUPABASE_ANON_KEY']}',
  );

  final items = await supabase.from('menu_items').select('name, item_type, category_id').limit(10);
  print("Sample Menu Items:");
  for (var item in items) {
    print("Name: ${item['name']}, Type: ${item['item_type']}, CatID: ${item['category_id']}");
  }

  final categories = await supabase.from('categories').select('id, name');
  print("\nCategories:");
  for (var cat in categories) {
    print("ID: ${cat['id']}, Name: ${cat['name']}");
  }
}
