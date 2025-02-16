import 'package:flutter/material.dart';
import 'package:flutter_share_me/flutter_share_me.dart';

class BloggerDetailScreen extends StatelessWidget {
  final String title;
  final String author;
  final String content;
  final String? imageUrl;

  const BloggerDetailScreen({
    Key? key,
    required this.title,
    required this.author,
    required this.content,
    this.imageUrl,
  }) : super(key: key);

  Future<void> _shareToFacebook(BuildContext context) async {
    String url = imageUrl ?? ''; // Nếu có ảnh, sử dụng link ảnh
    String message = "$title\n\nTác giả: $author\n\n$content";

    FlutterShareMe flutterShareMe = FlutterShareMe();
    String? response;

    if (url.isNotEmpty) {
      response = await flutterShareMe.shareToFacebook(
        msg: message,
        url: url,
      );
    } else {
      response = await flutterShareMe.shareToFacebook(
        msg: message,
      );
    }

    // Hiển thị thông báo nếu chia sẻ thất bại
    if (response == "error") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Chia sẻ thất bại! Vui lòng thử lại."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chi tiết bài viết"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.error, color: Colors.red),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Tác giả: $author",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  content,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _shareToFacebook(context),
        child: const Icon(Icons.share, color: Colors.white),
        backgroundColor: Colors.blueAccent, // Màu xanh nổi bật
      ),
    );
  }
}
