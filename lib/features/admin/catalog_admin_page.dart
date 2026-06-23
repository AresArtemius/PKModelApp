import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/brand/ui_constants.dart';
import '../catalog/catalog_page.dart';

class CatalogAdminPage extends StatelessWidget {
  const CatalogAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CatalogPage(
      leading: IconButton(
        onPressed: () => context.go('/admin'),
        icon: const Icon(Icons.arrow_back_rounded, color: kTextDark),
      ),
    );
  }
}
