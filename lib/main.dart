import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }
  runApp(const CafeApp());
}

class CafeApp extends StatelessWidget {
  const CafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cafe 1999',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const RoleSelectScreen(),
    );
  }
}

// ----------------- ভূমিকা নির্বাচন স্ক্রিন -----------------
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cafe 1999 Live System', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.restaurant, size: 80, color: Colors.deepOrange),
              const SizedBox(height: 24),
              const Text(
                'মোড নির্বাচন করুন',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text('এডমিন প্যানেল (মালিক / ক্যাশ)', style: TextStyle(fontSize: 18)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminHomeScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepOrange,
                    side: const BorderSide(color: Colors.deepOrange, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.person_pin),
                  label: const Text('ওয়েটার অর্ডার স্ক্রিন', style: TextStyle(fontSize: 18)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const WaiterTableScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------- এডমিন হোম স্ক্রিন -----------------
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabIndex == 0 ? 'লাইভ টেবিল ও অর্ডার' : 'মেনু ম্যানেজমেন্ট'),
        backgroundColor: Colors.deepOrange.shade100,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.table_restaurant), label: 'লাইভ টেবিল'),
          NavigationDestination(icon: Icon(Icons.fastfood), label: 'মেনু কার্ড'),
        ],
      ),
      body: _tabIndex == 0 ? const LiveTablesView() : const MenuManagementView(),
    );
  }
}

// এডমিন: লাইভ টেবিল ভিউ
class LiveTablesView extends StatelessWidget {
  const LiveTablesView({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('active_orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('ত্রুটি: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text('বর্তমানে কোনো রানিং অর্ডার নেই।', style: TextStyle(fontSize: 16, color: Colors.grey)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final table = data['table'] ?? docs[index].id;
            final items = (data['items'] as List<dynamic>?) ?? [];
            final total = data['total'] ?? 0;
            final time = (data['updated_at'] as Timestamp?)?.toDate();
            final formattedTime = time != null ? DateFormat('hh:mm a').format(time) : '';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('টেবিল নং: $table', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                        Text(formattedTime, style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const Divider(),
                    ...items.map((it) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${it['name']}  x ${it['qty']}', style: const TextStyle(fontSize: 16)),
                          Text('₹${(it['price'] ?? 0) * (it['qty'] ?? 1)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('মোট বিল: ₹$total', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('পেইড ও ক্লিয়ার'),
                          onPressed: () async {
                            await FirebaseFirestore.instance.collection('active_orders').doc(docs[index].id).delete();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('টেবিল $table বিল সম্পন্ন হয়েছে!')),
                            );
                          },
                        )
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// এডমিন: মেনু পরিবর্তন ভিউ
class MenuManagementView extends StatelessWidget {
  const MenuManagementView({super.key});

  void _showItemDialog(BuildContext context, [DocumentSnapshot? doc]) {
    final nameCtrl = TextEditingController(text: doc != null ? doc['name'] : '');
    final priceCtrl = TextEditingController(text: doc != null ? doc['price'].toString() : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(doc == null ? 'নতুন খাবার যোগ করুন' : 'খাবার এডিট করুন'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'খাবারের নাম')),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'দাম (টাকা)'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final price = int.tryParse(priceCtrl.text.trim()) ?? 0;
              if (name.isNotEmpty && price > 0) {
                if (doc == null) {
                  await FirebaseFirestore.instance.collection('menu').add({'name': name, 'price': price});
                } else {
                  await doc.reference.update({'name': name, 'price': price});
                }
                Navigator.pop(ctx);
              }
            },
            child: const Text('সেভ করুন'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepOrange,
        onPressed: () => _showItemDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('menu').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!.docs;

          if (items.isEmpty) {
            return const Center(child: Text('কোনো আইটেম নেই। নিচে + বাটনে চাপ দিয়ে যোগ করুন।'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = items[index];
              return ListTile(
                title: Text(doc['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                subtitle: Text('দাম: ₹${doc['price']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showItemDialog(context, doc)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => doc.reference.delete()),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ----------------- ওয়েটার স্ক্রিন -----------------
class WaiterTableScreen extends StatefulWidget {
  const WaiterTableScreen({super.key});

  @override
  State<WaiterTableScreen> createState() => _WaiterTableScreenState();
}

class _WaiterTableScreenState extends State<WaiterTableScreen> {
  String selectedTable = '1';
  final Map<String, int> orderQuantities = {};
  final phoneCtrl = TextEditingController();

  Future<void> _sendLiveOrder(List<DocumentSnapshot> menuDocs) async {
    final selectedItems = [];
    int total = 0;

    for (var doc in menuDocs) {
      final qty = orderQuantities[doc.id] ?? 0;
      if (qty > 0) {
        final price = doc['price'] as int;
        selectedItems.add({
          'name': doc['name'],
          'price': price,
          'qty': qty,
        });
        total += price * qty;
      }
    }

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('কমপক্ষে একটি খাবার নির্বাচন করুন!')));
      return;
    }

    // ফায়ারবেসে লাইভ অর্ডার পাঠানো
    await FirebaseFirestore.instance.collection('active_orders').doc('table_$selectedTable').set({
      'table': selectedTable,
      'items': selectedItems,
      'total': total,
      'updated_at': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('টেবিল $selectedTable-এর অর্ডার লাইভ পাঠানো হয়েছে!')));

    // হোয়াটসঅ্যাপে রসিদ পাঠানো
    final phone = phoneCtrl.text.trim();
    if (phone.isNotEmpty) {
      String billText = "🧾 *Cafe 1999 রসিদ*\n";
      billText += "টেবিল: $selectedTable\n";
      billText += "তারিখ: ${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now())}\n";
      billText += "-------------------------\n";
      for (var item in selectedItems) {
        billText += "${item['name']} x ${item['qty']} = ₹${item['price'] * item['qty']}\n";
      }
      billText += "-------------------------\n";
      billText += "*মোট বিল: ₹$total*\n\n";
      billText += "আমাদের কাফেতে আসার জন্য ধন্যবাদ!";

      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      final formattedPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
      final uri = Uri.parse("https://api.whatsapp.com/send?phone=$formattedPhone&text=${Uri.encodeComponent(billText)}");

      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    setState(() {
      orderQuantities.clear();
      phoneCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('অর্ডার গ্রহণ (ওয়েটার)'),
        backgroundColor: Colors.deepOrange.shade100,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('menu').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final menuDocs = snapshot.data!.docs;

          int totalBill = 0;
          for (var doc in menuDocs) {
            final qty = orderQuantities[doc.id] ?? 0;
            totalBill += (doc['price'] as int) * qty;
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.orange.shade50,
                child: Row(
                  children: [
                    const Text('টেবিল নির্বাচন: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: selectedTable,
                      items: List.generate(15, (index) => (index + 1).toString())
                          .map((val) => DropdownMenuItem(value: val, child: Text('টেবিল $val')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedTable = val);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: menuDocs.length,
                  itemBuilder: (context, index) {
                    final doc = menuDocs[index];
                    final qty = orderQuantities[doc.id] ?? 0;
                    return ListTile(
                      title: Text(doc['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('₹${doc['price']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: qty > 0 ? () => setState(() => orderQuantities[doc.id] = qty - 1) : null,
                          ),
                          Text('$qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                            onPressed: () => setState(() => orderQuantities[doc.id] = qty + 1),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'কাস্টমারের হোয়াটসঅ্যাপ নম্বর (ঐচ্ছিক)',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('মোট: ₹$totalBill', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          icon: const Icon(Icons.send),
                          label: const Text('অর্ডার পাঠান', style: TextStyle(fontSize: 16)),
                          onPressed: () => _sendLiveOrder(menuDocs),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
