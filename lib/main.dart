import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
        title: const Text('Cafe 1999 System', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.restaurant_menu, size: 80, color: Colors.deepOrange),
              const SizedBox(height: 24),
              const Text('মোড নির্বাচন করুন', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminHomeScreen()));
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
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('ওয়েটার স্ক্রিন (অর্ডার ও KOT)', style: TextStyle(fontSize: 18)),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const WaiterTableScreen()));
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
        title: Text(_tabIndex == 0 ? 'লাইভ টেবিল ও ক্যাশিয়ার' : 'মেনু পরিবর্তন'),
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

// এডমিন: লাইভ টেবিল ভিউ ও বিল প্রিন্ট
class LiveTablesView extends StatelessWidget {
  const LiveTablesView({super.key});

  Future<void> _printCustomerBill(String table, List<dynamic> items, int total) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MM-yyyy hh:mm a').format(now);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('Cafe 1999', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
              pw.Text('Customer Receipt', style: const pw.TextStyle(fontSize: 12)),
              pw.Divider(),
              pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text('Table: $table')),
              pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text('Date: $formattedDate')),
              pw.Divider(),
              ...items.map((it) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${it['name']} x ${it['qty']}'),
                  pw.Text('Rs ${(it['price'] ?? 0) * (it['qty'] ?? 1)}'),
                ],
              )),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text('Rs $total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text('Thank You! Visit Again.', style: const pw.TextStyle(fontSize: 10)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Bill_Table_$table',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('active_orders').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text('বর্তমানে কোনো রানিং অর্ডার নেই।', style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final table = data['table'] ?? docs[index].id;
            final items = (data['items'] as List<dynamic>?) ?? [];
            final total = data['total'] ?? 0;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('টেবিল নং: $table', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                    const Divider(),
                    ...items.map((it) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${it['name']} x ${it['qty']}'),
                          Text('₹${(it['price'] ?? 0) * (it['qty'] ?? 1)}'),
                        ],
                      ),
                    )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('মোট: ₹$total', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.print, color: Colors.blueGrey),
                              tooltip: 'বিল প্রিন্ট করুন',
                              onPressed: () => _printCustomerBill(table.toString(), items, total),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              child: const Text('পেইড'),
                              onPressed: () async {
                                await FirebaseFirestore.instance.collection('active_orders').doc(docs[index].id).delete();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
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
        title: Text(doc == null ? 'নতুন খাবার যোগ করুন' : 'দাম বা নাম পরিবর্তন'),
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
            child: const Text('সেভ'),
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
            return const Center(child: Text('কোনো আইটেম নেই। নিচে + বাটনে চাপ দিন।'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = items[index];
              return ListTile(
                title: Text(doc['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
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

// ----------------- ওয়েটার স্ক্রিন (অর্ডার, KOT ও হোয়াটসঅ্যাপ) -----------------
class WaiterTableScreen extends StatefulWidget {
  const WaiterTableScreen({super.key});

  @override
  State<WaiterTableScreen> createState() => _WaiterTableScreenState();
}

class _WaiterTableScreenState extends State<WaiterTableScreen> {
  String selectedTable = '1';
  final Map<String, int> orderQuantities = {};
  final phoneCtrl = TextEditingController();

  Future<void> _printKOT(String table, List<dynamic> items) async {
    final pdf = pw.Document();
    final timeStr = DateFormat('hh:mm a, dd-MM').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('*** KITCHEN ORDER TICKET (KOT) ***', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13))),
              pw.Divider(),
              pw.Text('TABLE: $table', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.Text('Time: $timeStr'),
              pw.Divider(),
              ...items.map((it) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${it['name']}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('QTY: ${it['qty']}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              )),
              pw.Divider(),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'KOT_Table_$table',
    );
  }

  Future<void> _processOrder(List<DocumentSnapshot> menuDocs) async {
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('খাবার সিলেক্ট করুন!')));
      return;
    }

    // ১. ফায়ারবেসে অর্ডার পাঠানো (ক্যাশে লাইভ দেখা যাবে)
    await FirebaseFirestore.instance.collection('active_orders').doc('table_$selectedTable').set({
      'table': selectedTable,
      'items': selectedItems,
      'total': total,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // ২. কিচেন KOT প্রিন্ট পপ-আপ খোলা
    await _printKOT(selectedTable, selectedItems);

    // ৩. কাস্টমারের হোয়াটসঅ্যাপ নম্বর দেওয়া থাকলে সেখানে পাঠানো
    final phone = phoneCtrl.text.trim();
    if (phone.isNotEmpty) {
      String billText = "🧾 *Cafe 1999*\nটেবিল: $selectedTable\n-------------------------\n";
      for (var item in selectedItems) {
        billText += "${item['name']} x ${item['qty']} = ₹${item['price'] * item['qty']}\n";
      }
      billText += "-------------------------\n*মোট: ₹$total*";

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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('অর্ডার সম্পন্ন ও KOT তৈরি হয়েছে!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ওয়েটার অর্ডার স্ক্রিন'), backgroundColor: Colors.deepOrange.shade100),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.orange.shade50,
                child: Row(
                  children: [
                    const Text('টেবিল:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 16),
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
                        labelText: 'কাস্টমার হোয়াটসঅ্যাপ নম্বর (না দিলে খালি রাখুন)',
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          icon: const Icon(Icons.print),
                          label: const Text('অর্ডার ও KOT প্রিন্ট'),
                          onPressed: () => _processOrder(menuDocs),
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
