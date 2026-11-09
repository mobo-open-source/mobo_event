import '../../core/services/odoo_session_manager.dart';

/// Service for fetching products with pagination and search
/// Used by ProductSelectorBottomSheet for API-based product loading
class ProductSearchService {
  /// Fetch products from Odoo with pagination and search
  Future<List<Map<String, dynamic>>> fetchProducts({
    String? searchQuery,
    int limit = 20,
    int offset = 0,
    bool storableOnly = true,
  }) async {
    try {
      final client = await OdooSessionManager.getClientEnsured();

      List<dynamic> domain = [];

      if (storableOnly) {
        domain.add('|');
        domain.add(['type', '=', 'product']);
        domain.add(['type', '=', 'consu']);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        domain.add('|');
        domain.add(['name', 'ilike', searchQuery]);
        domain.add('|');
        domain.add(['default_code', 'ilike', searchQuery]);
        domain.add(['barcode', 'ilike', searchQuery]);
      }

      final result = await client.callKw({
        'model': 'product.product',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': [
            'id',
            'name',
            'display_name',
            'default_code',
            'barcode',
            'uom_id',
            'qty_available',
            'virtual_available',
            'type',
            'list_price',
            'standard_price',
            'categ_id',
            'image_128',
          ],
          'limit': limit,
          'offset': offset,
          'order': 'name asc',
        },
      });

      final products = (result as List).cast<Map<String, dynamic>>();

      return products;
    } catch (_) {
      rethrow;
    }
  }

  /// Get total count of products matching the search criteria
  Future<int> getProductCount({
    String? searchQuery,
    bool storableOnly = true,
  }) async {
    try {
      final client = await OdooSessionManager.getClientEnsured();

      List<dynamic> domain = [];

      if (storableOnly) {
        domain.add('|');
        domain.add(['type', '=', 'product']);
        domain.add(['type', '=', 'consu']);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        domain.add('|');
        domain.add(['name', 'ilike', searchQuery]);
        domain.add('|');
        domain.add(['default_code', 'ilike', searchQuery]);
        domain.add(['barcode', 'ilike', searchQuery]);
      }

      final result = await client.callKw({
        'model': 'product.product',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {},
      });

      return result as int;
    } catch (_) {
      return 0;
    }
  }
}
