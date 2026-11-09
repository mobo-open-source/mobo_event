import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';

/// Reusable product selector dialog following MVVM pattern
class ProductSelectorDialog extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final String title;

  const ProductSelectorDialog({
    super.key,
    required this.products,
    this.title = 'Select Product',
  });

  @override
  State<ProductSelectorDialog> createState() => _ProductSelectorDialogState();
}

class _ProductSelectorDialogState extends State<ProductSelectorDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    // A phone in landscape is ~300–400dp tall — and well under 200 with the
    // keyboard up for the search box. There, the header and search box scroll
    // away with the list instead of being pinned above it, so nothing can
    // overflow, and the dialog uses the room it has rather than a fraction
    // of the screen.
    final short = context.isShortScreen;
    final verticalInset = short ? 8.0 : 24.0;

    final filteredProducts = widget.products.where((p) {
      final name = p['name']?.toString().toLowerCase() ?? '';
      final code = p['default_code']?.toString().toLowerCase() ?? '';
      final barcode = p['barcode']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          code.contains(query) ||
          barcode.contains(query);
    }).toList();

    // 80% of the screen, but never more than the dialog can actually have once
    // the keyboard and the dialog's own margins are taken off.
    final height = math.min(
      media.size.height * 0.8,
      media.size.height - media.viewInsets.bottom - verticalInset * 2,
    );
    // Same 90% of the screen as ever; only a wide (landscape) window caps it,
    // where a dialog the width of the screen reads badly.
    final width = context.isLandscape
        ? math.min(media.size.width * 0.9, 560.0)
        : media.size.width * 0.9;

    // The header and search box scroll away with the list on a short window —
    // and also whenever the room the dialog really has (the keyboard and its
    // margins already taken off) is that small, whatever the window.
    final scrolling = short || height < 380;

    final header = _buildHeader(theme);
    final search = _buildSearchField(theme, isDark);
    final count = filteredProducts.isNotEmpty
        ? _buildCount(filteredProducts.length, isDark)
        : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF232323) : Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: 40,
        vertical: verticalInset,
      ),
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(short ? 16 : 20),
        child: scrolling
            ? CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        header,
                        const SizedBox(height: 8),
                        search,
                        const SizedBox(height: 12),
                        if (count != null) count,
                      ],
                    ),
                  ),
                  if (filteredProducts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmpty(isDark, compact: true),
                    )
                  else
                    SliverList.builder(
                      itemCount: filteredProducts.length,
                      itemBuilder: (ctx, index) =>
                          _buildProduct(ctx, filteredProducts[index], isDark),
                    ),
                ],
              )
            : Column(
                children: [
                  header,
                  const SizedBox(height: 16),

                  search,
                  const SizedBox(height: 16),

                  if (count != null) count,

                  Expanded(
                    child: filteredProducts.isEmpty
                        ? _buildEmpty(isDark)
                        : ListView.builder(
                            itemCount: filteredProducts.length,
                            itemBuilder: (ctx, index) => _buildProduct(
                              ctx,
                              filteredProducts[index],
                              isDark,
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedPackage,
          color: theme.primaryColor,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _buildSearchField(ThemeData theme, bool isDark) {
    return TextField(
      controller: _searchController,
      // On a short window (a phone in landscape) the keyboard would take most
      // of the dialog before the user has chosen to search: the list comes
      // first there, and tapping the box brings the keyboard up.
      autofocus: !context.isShortScreen,
      onTapOutside: (val) => FocusScope.of(context).unfocus(),
      decoration: InputDecoration(
        hintText: 'Search by name, code, or barcode...',
        prefixIcon: HugeIcon(
          icon: HugeIcons.strokeRoundedSearch01,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          size: 20,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.clear,
                  color: isDark ? Colors.grey[400] : Colors.grey,
                  size: 20,
                ),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.primaryColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        isDense: true,
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  Widget _buildCount(int count, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            '$count ${count == 1 ? 'product' : 'products'}',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark, {bool compact = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          HugeIcon(
            icon: widget.products.isEmpty
                ? HugeIcons.strokeRoundedPackageOpen
                : HugeIcons.strokeRoundedSearch01,
            size: compact ? 40 : 64,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          SizedBox(height: compact ? 8 : 16),
          Text(
            widget.products.isEmpty
                ? 'No products available'
                : 'No products match your search',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProduct(
    BuildContext ctx,
    Map<String, dynamic> product,
    bool isDark,
  ) {
    final productName = product['name']?.toString() ?? 'Unknown';
    final defaultCode = product['default_code']?.toString();
    final barcode = product['barcode']?.toString();
    final qtyAvailable = product['qty_available'] ?? 0;
    final uomName = product['uom_id'] is List
        ? (product['uom_id'] as List)[1]?.toString() ?? 'Unit'
        : 'Unit';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: InkWell(
        onTap: () => Navigator.pop(ctx, product),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      productName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: qtyAvailable > 0
                          ? StatusColors.green.withValues(alpha: 0.1)
                          : StatusColors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$qtyAvailable $uomName',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: qtyAvailable > 0
                            ? StatusColors.green
                            : StatusColors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              if (defaultCode != null || barcode != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (defaultCode != null) ...[
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedTag01,
                        size: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        defaultCode,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                    if (defaultCode != null && barcode != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '•',
                          style: TextStyle(
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                        ),
                      ),
                    if (barcode != null) ...[
                      Icon(
                        Icons.qr_code_2,
                        size: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        barcode,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
