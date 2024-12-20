import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:itsa_food_app/admin_pages/offer_forecast.dart';
import 'package:itsa_food_app/widgets/admin_appbar.dart';
import 'package:itsa_food_app/widgets/admin_navbar.dart';
import 'package:itsa_food_app/widgets/admin_sidebar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:itsa_food_app/widgets/tags_chart.dart';
import 'package:itsa_food_app/widgets/pending_orders.dart';
import 'package:itsa_food_app/widgets/total_orders.dart';
import 'package:itsa_food_app/widgets/most_ordered.dart';
import 'package:itsa_food_app/admin_pages/forecasting.dart';

class AdminHome extends StatefulWidget {
  final String userName;
  final String email;
  final String imageUrl;

  const AdminHome({
    super.key,
    required this.userName,
    required this.email,
    this.imageUrl = '',
  });

  @override
  _AdminHomeState createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _selectedIndex = 0;
  String? mostOrderedProduct;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, int> productCount = {}; // Store product order counts
  String? lastActiveTime;
  List<Map<String, dynamic>> orders = []; // Fetch this from Firestore
  String selectedFilter = 'Today';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchMostOrderedProduct('Today'); // Pass a default filter
    _getLastActiveTime();
  }

  Future<void> _getLastActiveTime() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      lastActiveTime = prefs.getString('last_active_time');
    });
  }

  Future<void> fetchMostOrderedProduct(String filter) async {
    setState(() {
      isLoading = true; // Start loading indicator
    });

    productCount.clear(); // Clear the previous data

    DateTime now = DateTime.now();
    DateTime startTime;

    // Determine the filter's start time
    if (filter == 'Today') {
      startTime = DateTime(now.year, now.month, now.day);
    } else if (filter == '3 Days') {
      startTime = now.subtract(Duration(days: 3));
    } else if (filter == '1 Week') {
      startTime = now.subtract(Duration(days: 7));
    } else {
      throw ArgumentError('Invalid filter: $filter');
    }

    String? branchID;
    // Determine the branchID based on the userName
    if (widget.userName == "Main Branch Admin") {
      branchID = "branch 1";
    } else if (widget.userName == "Sta. Cruz II Admin") {
      branchID = "branch 2";
    } else if (widget.userName == "San Dionisio Admin") {
      branchID = "branch 3";
    }

    if (branchID == null) {
      setState(() {
        isLoading = false; // Stop loading indicator
      });
      throw ArgumentError("Invalid userName: ${widget.userName}");
    }

    try {
      // Fetch all customer documents
      QuerySnapshot customerSnapshot =
          await FirebaseFirestore.instance.collection('customer').get();

      for (var customerDoc in customerSnapshot.docs) {
        // For each customer, fetch their orders and filter by branchID
        QuerySnapshot orderSnapshot = await customerDoc.reference
            .collection('orders')
            .where('branchID', isEqualTo: branchID) // Filter by branchID
            .get();

        for (var orderDoc in orderSnapshot.docs) {
          Timestamp timestamp = orderDoc['timestamp'];
          DateTime orderDate = timestamp.toDate();

          // Only process orders within the selected time range
          if (orderDate.isAfter(startTime)) {
            List<dynamic> products = orderDoc['products'] ?? [];

            for (var product in products) {
              // Ensure the product has the required fields
              if (product['productName'] != null &&
                  product['quantity'] != null) {
                String productName = product['productName'];
                int quantity = product['quantity'];

                // Accumulate product quantities
                productCount[productName] =
                    (productCount[productName] ?? 0) + quantity;
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching product counts: $e');
    }

    setState(() {
      isLoading = false; // Stop loading indicator
    });
  }

  Future<void> _onRefresh() async {
    await fetchMostOrderedProduct('Today'); // Fetch new data on refresh
  }

  List<BarChartGroupData> _buildBarChartData() {
    return productCount.entries.map((entry) {
      final index = productCount.keys.toList().indexOf(entry.key);
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: Colors.blue, // Customize bar color
          ),
        ],
        showingTooltipIndicators: [0],
      );
    }).toList();
  }

  void _updateChartData(String filter) {
    fetchMostOrderedProduct(filter);
  }

  Widget _buildTimeFilterButton({
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        elevation: isSelected ? 4 : 0,
        backgroundColor: isSelected ? Colors.blueAccent : Colors.grey[300],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalOrders = 372; // Example data, replace with dynamic data
    int deliveryOrders = 122; // Example data, replace with dynamic data
    int pickupOrders = 100; // Example data, replace with dynamic data

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFE1D4C2), // Set the background color
      appBar: AdminAppBar(scaffoldKey: _scaffoldKey),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                // Existing Total Orders Card
                TotalOrdersCard(
                  totalOrders: totalOrders,
                  deliveryOrders: deliveryOrders,
                  pickupOrders: pickupOrders,
                  userName: widget.userName,
                ),
                // New Most Ordered Card
                MostOrderedCard(userName: widget.userName),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 1,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin:
                        const EdgeInsets.symmetric(vertical: 20, horizontal: 5),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Forecasting',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {
                              // Navigate to Forecasting page
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ForecastingPage(
                                    userName: widget.userName,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14.0, horizontal: 30.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: Colors
                                  .blue, // Use backgroundColor for button color
                            ),
                            child: const Text(
                              'Go to Forecasting',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10), // Spacing between buttons
                          ElevatedButton(
                            onPressed: () {
                              // Navigate to OffersForecast page
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OffersForecast(
                                    userName: widget.userName,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14.0, horizontal: 30.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: Colors
                                  .green, // Different color for distinction
                            ),
                            child: const Text(
                              'Go to Offers Forecast',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (productCount.isNotEmpty)
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 1,
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 5),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Product Order Count',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Responsive buttons
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  _buildTimeFilterButton(
                                    label: 'Today',
                                    isSelected: selectedFilter == 'Today',
                                    onPressed: () {
                                      setState(() {
                                        selectedFilter = 'Today';
                                      });
                                      _updateChartData('Today');
                                    },
                                  ),
                                  const SizedBox(width: 30),
                                  _buildTimeFilterButton(
                                    label: '3 Days',
                                    isSelected: selectedFilter == '3 Days',
                                    onPressed: () {
                                      setState(() {
                                        selectedFilter = '3 Days';
                                      });
                                      _updateChartData('3 Days');
                                    },
                                  ),
                                  const SizedBox(width: 30),
                                  _buildTimeFilterButton(
                                    label: '1 Week',
                                    isSelected: selectedFilter == '1 Week',
                                    onPressed: () {
                                      setState(() {
                                        selectedFilter = '1 Week';
                                      });
                                      _updateChartData('1 Week');
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Chart with loading overlay using Stack
                            SizedBox(
                              height: 300,
                              child: Stack(
                                children: [
                                  // The BarChart widget
                                  BarChart(
                                    BarChartData(
                                      alignment: BarChartAlignment.spaceAround,
                                      maxY: productCount.values.isEmpty
                                          ? 0
                                          : productCount.values
                                              .reduce((a, b) => a > b ? a : b)
                                              .toDouble(),
                                      barTouchData: BarTouchData(
                                        enabled: true,
                                        touchTooltipData: BarTouchTooltipData(
                                          tooltipRoundedRadius: 4,
                                          tooltipPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 4, vertical: 2),
                                          getTooltipItem: (group, groupIndex,
                                              rod, rodIndex) {
                                            final productName = productCount
                                                .keys
                                                .elementAt(groupIndex);
                                            final orderCount = rod.toY.toInt();
                                            return BarTooltipItem(
                                              '$productName\n',
                                              const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                              ),
                                              children: [
                                                TextSpan(
                                                  text: '$orderCount orders',
                                                  style: const TextStyle(
                                                    color: Colors.yellow,
                                                    fontSize: 8,
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                      titlesData: FlTitlesData(
                                        topTitles: AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false),
                                        ),
                                        rightTitles: AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 40,
                                            interval: 20,
                                            getTitlesWidget: (value, _) {
                                              return Text(
                                                value.toInt().toString(),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.black,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 50,
                                            interval: 2,
                                            getTitlesWidget: (value, _) {
                                              final product =
                                                  productCount.keys.firstWhere(
                                                (k) =>
                                                    k.hashCode == value.toInt(),
                                                orElse: () => '',
                                              );
                                              return Transform.rotate(
                                                angle: -0.45,
                                                child: Text(
                                                  product.length > 10
                                                      ? '${product.substring(0, 10)}...'
                                                      : product,
                                                  style: const TextStyle(
                                                      fontSize: 9),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      gridData: FlGridData(
                                        show: true,
                                        horizontalInterval: 20,
                                        getDrawingHorizontalLine: (value) =>
                                            FlLine(
                                          color: Colors.grey[300],
                                          strokeWidth: 1,
                                        ),
                                      ),
                                      borderData: FlBorderData(
                                        show: true,
                                        border: const Border(
                                          left: BorderSide(
                                              width: 1, color: Colors.black54),
                                          bottom: BorderSide(
                                              width: 1, color: Colors.black54),
                                        ),
                                      ),
                                      barGroups: _buildBarChartData(),
                                    ),
                                  ),
                                  // Show loading spinner if data is being fetched
                                  if (isLoading)
                                    Positioned.fill(
                                      child: Container(
                                        color: Colors.white.withOpacity(0.7),
                                        alignment: Alignment.center,
                                        child:
                                            const CircularProgressIndicator(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                FrequentOrdersByTagsChart(userName: widget.userName),
              ],
            ),
          ),
        ),
      ),
      drawer: AdminSidebar(
        onLogout: _logout,
        userName: widget.userName,
      ),

      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta! < -10) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    builder: (context) {
                      return SizedBox(
                        height: MediaQuery.of(context).size.height * 0.95,
                        child: PendingOrderNotifications(
                            userName: widget.userName),
                      );
                    },
                  );
                }
              },
              child: MaterialButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    builder: (context) {
                      return SizedBox(
                        height: MediaQuery.of(context).size.height * 0.95,
                        child: PendingOrderNotifications(
                            userName: widget.userName),
                      );
                    },
                  );
                },
                color: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.assignment_turned_in,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Pending Orders for Approval',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AdminBottomNavBar(
            selectedIndex: _selectedIndex,
            onItemTapped: _onItemTapped,
            userName: widget.userName,
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _logout() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  void dispose() {
    super.dispose();
    _updateLastActiveTime();
  }

  Future<void> _updateLastActiveTime() async {
    final prefs = await SharedPreferences.getInstance();
    final currentTime = DateTime.now().toString();
    await prefs.setString('last_active_time', currentTime);
  }
}

class ProductOrder {
  final String productName;
  final int count;

  ProductOrder(this.productName, this.count);
}
