import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:myoffice_sunshine/utils/standard_table_style.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';

class Stock extends StatefulWidget {
  const Stock({super.key});

  @override
  State<Stock> createState() => _StockState();
}

class _StockState extends State<Stock> {
  List<Map<String, dynamic>> stockList = [];
  int page = 1;
  int limit = 20;
  int totalPages = 1;
  int total = 0;
  bool isLoading = true;
  List<int> allStoreIds = [];

  @override
  void initState() {
    super.initState();
    fetchStock();
  }

  Future<void> fetchStock() async {
    setState(() {
      isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to continue.')),
          );
        }
        return;
      }
      final response = await http.get(
        Uri.parse(
          'https://1.sunshineiot.in/api/v2/store/stock/all?page=$page&limit=$limit&search=&item_type_id=',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Map<String, dynamic>> stocks =
            List<Map<String, dynamic>>.from(data['data'] ?? []);
        // Collect all unique store IDs for columns
        final Set<int> storeIds = {};
        for (final item in stocks) {
          final stores = item['stores'] as List<dynamic>? ?? [];
          for (final store in stores) {
            storeIds.add(store['store_id'] as int);
          }
        }
        if (mounted) {
          setState(() {
            stockList = stocks;
            allStoreIds = storeIds.toList()..sort();
            total = data['total'] ?? 0;
            page = data['page'] ?? 1;
            limit = data['limit'] ?? 20;
            totalPages = data['totalPages'] ?? 1;
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load stock.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void goToPage(int newPage) {
    if (newPage < 1 || newPage > totalPages) return;
    setState(() {
      page = newPage;
    });
    fetchStock();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'refresh') {
                fetchStock();
              } else if (value == 'transfer') {
                Get.toNamed('/dashboard/store/stock/transfer');
              } else if (value == 'adjust') {
                Get.toNamed('/dashboard/store/stock/adjust');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.black),
                    SizedBox(width: 8),
                    Text('Refresh Stock'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'transfer',
                child: Row(
                  children: [
                    Icon(Icons.compare_arrows, color: Colors.black),
                    SizedBox(width: 8),
                    Text('Transfer'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'adjust',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.black),
                    SizedBox(width: 8),
                    Text('Adjustment'),
                  ],
                ),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 8,
            color: Colors.white,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.04).toInt()),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.more_horiz, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Actions',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withAlpha((0.08 * 255).toInt()),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: 350 + allStoreIds.length * 120,
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                CustomTable(
                                  headers: [
                                    'Item ID',
                                    'Description',
                                    ...allStoreIds.map(
                                      (storeId) => 'Store $storeId',
                                    ),
                                  ],
                                  rows: stockList.asMap().entries.map((entry) {
                                    final item = entry.value;
                                    final Map<int, int> storeQty = {};

                                    for (final store
                                        in (item['stores'] as List<dynamic>? ??
                                            [])) {
                                      storeQty[store['store_id']] =
                                          store['qty'];
                                    }

                                    return [
                                      Text(item['item_id'].toString()),
                                      Text(item['description'] ?? ''),
                                      ...allStoreIds.map(
                                        (storeId) => Text(
                                          storeQty[storeId]?.toString() ?? '0',
                                        ),
                                      ),
                                    ];
                                  }).toList(),
                                  columnWidths: {
                                    0: const FixedColumnWidth(100), // Item ID
                                    1: const FixedColumnWidth(
                                      250,
                                    ), // Description
                                    for (
                                      int i = 2;
                                      i < 2 + allStoreIds.length;
                                      i++
                                    )
                                      i: const FixedColumnWidth(120), // Stores
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: page > 1 ? () => goToPage(page - 1) : null,
                        ),
                        Text('Page $page of $totalPages'),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: page < totalPages
                              ? () => goToPage(page + 1)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Total records: $total'),
                  ),
                ],
              ),
            ),
    );
  }

  
}
