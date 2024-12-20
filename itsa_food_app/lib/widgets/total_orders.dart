import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class TotalOrdersCard extends StatefulWidget {
  final int totalOrders;
  final int deliveryOrders;
  final int pickupOrders;
  final String userName;
  final double chartWidth;
  final double chartHeight;
  final double sectionRadius;
  final double centerSpaceRadius;

  const TotalOrdersCard({
    super.key,
    required this.userName,
    required this.totalOrders,
    required this.deliveryOrders,
    required this.pickupOrders,
    this.chartWidth = 100,
    this.chartHeight = 100,
    this.sectionRadius = 45,
    this.centerSpaceRadius = 20,
  });

  @override
  _TotalOrdersCardState createState() => _TotalOrdersCardState();
}

class _TotalOrdersCardState extends State<TotalOrdersCard> {
  int totalOrders = 0;
  int deliveryOrders = 0;
  int pickupOrders = 0;
  DateTime? lastUpdate;
  bool loading = true; // New loading state
  Timer? updateTimer; // Timer for periodic fetching

  Future<void> fetchOrderCounts() async {
    setState(() {
      loading = true; // Set loading to true when fetching starts
    });

    try {
      int deliveryCount = 0;
      int pickupCount = 0;

      // Determine branchID based on userName
      String? branchID;
      if (widget.userName == "Main Branch Admin") {
        branchID = "branch 1";
      } else if (widget.userName == "Sta. Cruz II Admin") {
        branchID = "branch 2";
      } else if (widget.userName == "San Dionisio Admin") {
        branchID = "branch 3";
      }

      if (branchID == null) {
        throw ArgumentError("Invalid userName: ${widget.userName}");
      }

      // Fetch all customer documents
      final customersSnapshot =
          await FirebaseFirestore.instance.collection('customer').get();

      // Filter orders based on branchID
      await Future.wait(customersSnapshot.docs.map((customerDoc) async {
        final ordersSnapshot = await customerDoc.reference
            .collection('orders')
            .where('branchID', isEqualTo: branchID) // Filter by branchID
            .get();

        for (var orderDoc in ordersSnapshot.docs) {
          String orderType = orderDoc['orderType'];
          if (orderType == 'Delivery') {
            deliveryCount++;
          } else if (orderType == 'Pickup') {
            pickupCount++;
          }
        }
      }));

      setState(() {
        deliveryOrders = deliveryCount;
        pickupOrders = pickupCount;
        totalOrders = deliveryCount + pickupCount;
        lastUpdate = DateTime.now();
        loading = false; // Set loading to false when fetch completes
        print(
            "Updated values - Total: $totalOrders, Delivery: $deliveryOrders, Pickup: $pickupOrders");
      });
    } catch (e) {
      print("Error fetching orders: $e");
      setState(() {
        loading = false; // Ensure loading is false even if fetch fails
      });
    }
  }

  // Refresh method for manual triggering of fetchOrderCounts
  Future<void> _onRefresh() async {
    await fetchOrderCounts(); // Fetch new data on refresh
  }

  @override
  void initState() {
    super.initState();
    fetchOrderCounts(); // Initial fetch on widget initialization

    // Set up a Timer to fetch data every 3 minutes
    updateTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      fetchOrderCounts();
    });
  }

  @override
  void dispose() {
    // Cancel the timer when the widget is disposed
    updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lastUpdatedText = lastUpdate != null
        ? 'Updated ${DateTime.now().difference(lastUpdate!).inMinutes} minutes ago'
        : 'Updating...';

    return RefreshIndicator(
      onRefresh: _onRefresh, // Trigger the refresh on pull down
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 5),
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Orders',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loading ? 'Loading...' : '$totalOrders',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          loading ? 'Fetching data...' : lastUpdatedText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            LegendIndicator(
                                color: Colors.blue, text: 'Delivery'),
                            SizedBox(width: 10),
                            LegendIndicator(
                                color: Colors.amber, text: 'Pick-up'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: widget.chartWidth,
                    height: widget.chartHeight,
                    child: loading
                        ? Center(child: CircularProgressIndicator())
                        : PieChart(
                            PieChartData(
                              sections: [
                                PieChartSectionData(
                                  value: deliveryOrders.toDouble(),
                                  color: Colors.blue,
                                  title: '$deliveryOrders\nDelivery',
                                  radius: widget.sectionRadius,
                                  titleStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                PieChartSectionData(
                                  value: pickupOrders.toDouble(),
                                  color: Colors.amber,
                                  title: '$pickupOrders\nPick-up',
                                  radius: widget.sectionRadius,
                                  titleStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                              borderData: FlBorderData(show: false),
                              sectionsSpace: 2,
                              centerSpaceRadius: widget.centerSpaceRadius,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom widget for the legend indicator
class LegendIndicator extends StatelessWidget {
  final Color color;
  final String text;

  const LegendIndicator({super.key, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: Colors.black),
        ),
      ],
    );
  }
}
