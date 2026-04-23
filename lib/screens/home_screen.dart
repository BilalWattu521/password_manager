import 'package:flutter/material.dart';
import 'package:password_manager/services/database_helper.dart';
import 'package:password_manager/screens/credential_list_screen.dart';
import 'package:password_manager/screens/add_credential_screen.dart';
import 'package:password_manager/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _dbHelper = DatabaseHelper();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _allApps = [];
  List<Map<String, dynamic>> _filteredApps = [];

  @override
  void initState() {
    super.initState();
    _loadApps();
    _searchController.addListener(_filterApps);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    final apps = await _dbHelper.getAppsWithCounts();
    setState(() {
      _allApps = apps;
      _filteredApps = apps;
    });
  }

  void _filterApps() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredApps = _allApps
          .where(
            (app) => (app['appName'] as String).toLowerCase().contains(query),
          )
          .toList();
    });
  }

  Future<void> _openSettings() async {
    // If settings returns true, an import happened — reload the list
    final imported = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (imported == true) _loadApps();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Your Passwords',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header with total count
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${_allApps.length} App${_allApps.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            // Search Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search apps or websites',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Apps List
            Expanded(
              child: _filteredApps.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 64,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _allApps.isEmpty
                                ? 'No passwords yet'
                                : 'No results found',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _filteredApps.length,
                      itemBuilder: (context, index) {
                        final appData = _filteredApps[index];
                        final appName = appData['appName'] as String;
                        final count = appData['count'] as int;

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CredentialsListScreen(appName: appName),
                              ),
                            ).then((_) => _loadApps());
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[800]!),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        appName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$count credential${count != 1 ? 's' : ''}',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey[600],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCredentialScreen()),
          ).then((_) => _loadApps());
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
