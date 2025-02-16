import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'Signin.dart';
import 'BloggerDetailScreen.dart';

class BlogManagementScreen extends StatefulWidget {
  @override
  _BlogManagementScreenState createState() => _BlogManagementScreenState();
}

class _BlogManagementScreenState extends State<BlogManagementScreen> with SingleTickerProviderStateMixin {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController authorController = TextEditingController();
  final TextEditingController contentController = TextEditingController();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool isEditing = false;
  String editingDocId = "";
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => AuthPage()),
    );
  }

  Future<void> _pickImage() async {
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
      Reference storageRef = FirebaseStorage.instance.ref().child('blog_images/$fileName');
      UploadTask uploadTask = storageRef.putFile(_selectedImage!);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Lỗi upload ảnh: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi khi tải ảnh lên")),
      );
      return null;
    }
  }

  Future<void> createOrUpdateBlog() async {
    if (titleController.text.isEmpty ||
        authorController.text.isEmpty ||
        contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Vui lòng nhập đầy đủ thông tin")),
      );
      return;
    }

    String? imageUrl;
    if (_selectedImage != null) {
      imageUrl = await _uploadImage();
      if (imageUrl == null) return;
    } else if (isEditing) {
      // Giữ nguyên ảnh cũ nếu không chọn ảnh mới
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("Blogs")
          .doc(editingDocId)
          .get();
      imageUrl = doc['blogImage'];
    }

    Map<String, dynamic> blogData = {
      "blogTitle": titleController.text,
      "blogAuthor": authorController.text,
      "blogContent": contentController.text,
      "blogImage": imageUrl,
      "publishDate": DateTime.now()
    };

    if (isEditing) {
      await FirebaseFirestore.instance.collection("Blogs").doc(editingDocId).update(blogData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bài viết đã được cập nhật thành công")),
      );
    } else {
      await FirebaseFirestore.instance.collection("Blogs").add(blogData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bài viết đã được thêm thành công")),
      );
    }
    clearFields();
  }

  void deleteBlog(String documentId) {
    FirebaseFirestore.instance.collection("Blogs").doc(documentId).delete().then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bài viết đã được xóa")),
      );
    });
  }

  void clearFields() {
    titleController.clear();
    authorController.clear();
    contentController.clear();
    setState(() {
      _selectedImage = null;
      isEditing = false;
      editingDocId = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Quản lý Blogger", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        iconTheme: IconThemeData(color: Colors.white),
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
            Tab(icon: Icon(Icons.create), text: "Tạo bài viết"),
            Tab(icon: Icon(Icons.list), text: "Danh sách bài viết"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab Tạo bài viết
          Padding(
            padding: EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0), // Khoảng cách trên dưới 16px
                    child: Text(
                      "Thêm bài viết",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                    ),
                  ),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                        labelText: "Tiêu đề bài viết",
                        border: OutlineInputBorder(),
                        hintText: "Nhập tiêu đề bài viết"
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: authorController,
                    decoration: InputDecoration(
                        labelText: "Tác giả",
                        border: OutlineInputBorder(),
                        hintText: "Nhập tên tác giả"
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: contentController,
                    decoration: InputDecoration(
                        labelText: "Nội dung",
                        border: OutlineInputBorder(),
                        hintText: "Nhập nội dung bài viết"
                    ),
                    maxLines: 5,
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _pickImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: Text("Chọn ảnh đính kèm"),
                  ),
                  SizedBox(height: 10),
                  _selectedImage != null
                      ? Image.file(_selectedImage!, height: 150, fit: BoxFit.cover)
                      : isEditing
                      ? FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection("Blogs")
                        .doc(editingDocId)
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!['blogImage'] != null) {
                        return Image.network(
                          snapshot.data!['blogImage'],
                          height: 150,
                          fit: BoxFit.cover,
                        );
                      }
                      return SizedBox();
                    },
                  )
                      : SizedBox(),
                  SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text(isEditing ? "Cập nhật bài viết" : "Thêm bài viết"),
                    onPressed: createOrUpdateBlog,
                  ),
                ],
              ),
            ),
          ),
          // Tab Danh sách bài viết
          Padding(
            padding: EdgeInsets.all(16.0),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection("Blogs").snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("Không có bài viết nào"));
                }
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot doc = snapshot.data!.docs[index];
                    return Card(
                      elevation: 5,
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BloggerDetailScreen(
                                title: doc['blogTitle'],
                                author: doc['blogAuthor'],
                                content: doc['blogContent'],
                                imageUrl: doc['blogImage'],
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (doc['blogImage'] != null)
                                Image.network(
                                  doc['blogImage'],
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              SizedBox(height: 10),
                              Text(
                                doc['blogTitle'],
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 5),
                              Text(
                                "Tác giả: ${doc['blogAuthor']}",
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              SizedBox(height: 10),
                              Text(
                                doc['blogContent'],
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}