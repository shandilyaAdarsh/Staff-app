// lib/features/auth/presentation/screens/organization_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../state/auth_notifier.dart';

class OrganizationSelectionScreen extends ConsumerStatefulWidget {
  const OrganizationSelectionScreen({super.key});

  @override
  ConsumerState<OrganizationSelectionScreen> createState() => _OrganizationSelectionScreenState();
}

class _OrganizationSelectionScreenState extends ConsumerState<OrganizationSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(authNotifierProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredOrgs = notifier.mockOrganizations
        .where((org) => org.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Organization'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                'Enter Company Access Tenant',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Search and link this device to your company franchise account.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 24),
              
              // Search Input field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search Organizations',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
              const SizedBox(height: 24),
              
              // Recent / Quick Access Header
              if (notifier.mockOrganizations.isNotEmpty) ...[
                Text(
                  'Recent Access Tenants',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                
                // Recent selections mock card
                Card(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.history_rounded, color: AppColors.primary),
                    title: Text(notifier.mockOrganizations[0].name),
                    subtitle: const Text('Last synced: 2 hours ago'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      notifier.selectOrganization(notifier.mockOrganizations[0]);
                      context.go('/branch-select');
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              // Full Tenant List
              Text(
                'All Connected Tenants (${filteredOrgs.length})',
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filteredOrgs.isEmpty
                    ? const Center(
                        child: Text('No organizations found matching search criteria.'),
                      )
                    : ListView.builder(
                        itemCount: filteredOrgs.length,
                        itemBuilder: (context, index) {
                          final org = filteredOrgs[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Card(
                              color: isDark ? AppColors.darkSurface : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                ),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.business_rounded, color: AppColors.info),
                                title: Text(org.name),
                                trailing: const Icon(Icons.chevron_right_rounded),
                                onTap: () {
                                  notifier.selectOrganization(org);
                                  context.go('/branch-select');
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
