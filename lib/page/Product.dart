import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProductManagementScreen extends StatefulWidget {
  @override
  _ProductManagementScreenState createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController typeController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool isEditing = false;
  String? editingProductId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    nameController.dispose();
    typeController.dispose();
    priceController.dispose();
    super.dispose();
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? pickedImage = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _selectedImage = File(pickedImage.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference storageReference = FirebaseStorage.instance.ref().child('images/$fileName');
      UploadTask uploadTask = storageReference.putFile(_selectedImage!);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Lỗi khi tải ảnh lên: $e");
      _showErrorSnackBar('Lỗi khi tải ảnh lên');
      return null;
    }
  }

  void _submitProduct() async {
    if (nameController.text.isEmpty) {
      _showErrorSnackBar('Vui lòng nhập tên sản phẩm');
      return;
    }
    if (typeController.text.isEmpty) {
      _showErrorSnackBar('Vui lòng nhập loại sản phẩm');
      return;
    }
    if (priceController.text.isEmpty) {
      _showErrorSnackBar('Vui lòng nhập giá');
      return;
    }
    if (!_isNumeric(priceController.text)) {
      _showErrorSnackBar('Giá phải là một con số hợp lệ');
      return;
    }
    if (_selectedImage == null && !isEditing) {
      _showErrorSnackBar('Vui lòng chọn ảnh sản phẩm');
      return;
    }
    String? imageUrl;

    if (_selectedImage != null) {
      imageUrl = await _uploadImage();
      if (imageUrl == null) return; // Nếu upload ảnh thất bại thì dừng
    } else if (isEditing) {
      // Giữ nguyên ảnh cũ nếu không chọn ảnh mới
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("Products")
          .doc(editingProductId)
          .get();
      imageUrl = doc['productImage'];
    }

    Map<String, dynamic> productData = {
      "productName": nameController.text,
      "productType": typeController.text,
      "productPrice": double.parse(priceController.text),
      "productImage": imageUrl, // Có thể là null nếu không có ảnh
    };


    if (isEditing && editingProductId != null) {
      await FirebaseFirestore.instance.collection("Products").doc(editingProductId).update(productData);
      _showSuccessSnackBar('Product updated successfully');
    } else {
      await FirebaseFirestore.instance.collection("Products").add(productData);
      _showSuccessSnackBar('Product added successfully');
    }

    _clearForm();
    _tabController.animateTo(0); // Switch to product list tab
  }

  void _clearForm() {
    setState(() {
      nameController.clear();
      typeController.clear();
      priceController.clear();
      _selectedImage = null;
      isEditing = false;
      editingProductId = null;
    });
  }

  void _editProduct(DocumentSnapshot product) {
    setState(() {
      nameController.text = product['productName'];
      typeController.text = product['productType'];
      priceController.text = product['productPrice'].toString();
      isEditing = true;
      editingProductId = product.id;
    });
    _tabController.animateTo(1); // Switch to add/edit tab
  }

  void _deleteProduct(String productId) async {
    await FirebaseFirestore.instance.collection("Products").doc(productId).delete();
    _showSuccessSnackBar('Product deleted successfully');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    ));
  }

  bool _isNumeric(String str) {
    if (str == null) {
      return false;
    }
    return double.tryParse(str) != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: Colors.deepPurple,
        title: Text(
          'Quản lý sản phẩm',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: _signOut,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: 'Danh sách sản phẩm'),
            Tab(text: isEditing ? 'Chỉnh sửa sản phẩm' : 'Thêm sản phẩm'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductList(),
          _buildProductForm(),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("Products").snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("Không có sản phẩm nào"));
        }
        return GridView.builder(
          padding: EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            DocumentSnapshot product = snapshot.data!.docs[index];
            return _buildProductCard(product);
          },
        );
      },
    );
  }

  Widget _buildProductCard(DocumentSnapshot product) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: product['productImage'] != null
                  ? Image.network(
                product['productImage'],
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.broken_image, size: 100, color: Colors.grey);
                },
              )
                  : Container(
                color: Colors.grey[200],
                child: Icon(Icons.image, size: 100, color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(product['productName'],
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('Loại: ${product['productType']}', style: TextStyle(color: Colors.grey[700])),
                Text('Giá: ${product['productPrice']} VND', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Spacer(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _editProduct(product),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteProduct(product.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0), // Khoảng cách trên dưới 16px
            child: Text(
              "Thêm sản phẩm",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              textAlign: TextAlign.center, // Căn giữa văn bản
            ),
          ),
          TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: 'Tên sản phẩm'),
          ),
          SizedBox(height: 16),
          TextField(
            controller: typeController,
            decoration: InputDecoration(labelText: 'Loại sản phẩm'),
          ),
          SizedBox(height: 16),
          TextField(
            controller: priceController,
            decoration: InputDecoration(labelText: 'Giá'),
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: _pickAndUploadImage,
            child: Text('Chọn hình ảnh'),
          ),

          SizedBox(height: 16),
          if (_selectedImage != null)
            Image.file(_selectedImage!, height: 200, fit: BoxFit.cover)
          else if (isEditing && editingProductId != null)
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection("Products").doc(editingProductId).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                  String? imageUrl = snapshot.data!['productImage'];
                  return imageUrl != null
                      ? Image.network(imageUrl, height: 200, fit: BoxFit.cover)
                      : SizedBox();
                }
                return SizedBox();
              },
            ),
          SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: _submitProduct,
            child: Text(isEditing ? 'Cập nhật sản phẩm' : 'Thêm sản phẩm'),
          ),

        ],
      ),
    );
  }
}

