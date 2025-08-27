import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReviewScreen extends StatefulWidget {
  final String stationId;
  const ReviewScreen({super.key, required this.stationId});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final TextEditingController _commentController = TextEditingController();
  double _rating = 3;

  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final reviewRef = FirebaseFirestore.instance
        .collection('ev_stations')
        .doc(widget.stationId)
        .collection('reviews')
        .doc(user.uid);

    await reviewRef.set({
      'userId': user.uid,
      'name': user.displayName ?? 'Anonymous',
      'profileUrl': user.photoURL ?? '',
      'rating': _rating,
      'comment': _commentController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update average rating
    final allReviews = await FirebaseFirestore.instance
        .collection('ev_stations')
        .doc(widget.stationId)
        .collection('reviews')
        .get();

    double total = 0;
    for (var doc in allReviews.docs) {
      total += (doc['rating'] ?? 0).toDouble();
    }

    final averageRating = total / allReviews.docs.length;

    await FirebaseFirestore.instance
        .collection('ev_stations')
        .doc(widget.stationId)
        .update({'rating': averageRating});

    _commentController.clear();
    setState(() => _rating = 3);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Review submitted successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Station Reviews"),
        backgroundColor: Colors.green.shade700,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Leave a Review", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        Icons.star,
                        color: index < _rating ? Colors.amber : Colors.grey,
                      ),
                      onPressed: () => setState(() => _rating = (index + 1).toDouble()),
                    );
                  }),
                ),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Write your comment...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitReview,
                    child: const Text("Submit Review"),
                  ),
                )
              ],
            ),
          ),
          const Divider(thickness: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ev_stations')
                  .doc(widget.stationId)
                  .collection('reviews')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final reviews = snapshot.data!.docs;

                if (reviews.isEmpty) return const Center(child: Text("No reviews yet."));

                QueryDocumentSnapshot? myReview;
                for (var doc in reviews) {
                  if (doc['userId'] == currentUser?.uid) {
                    myReview = doc;
                    break;
                  }
                }


                final otherReviews = reviews.where((doc) => doc['userId'] != currentUser?.uid).toList();

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  separatorBuilder: (_, __) => const Divider(),
                  itemCount: (myReview != null ? 1 : 0) + otherReviews.length,
                  itemBuilder: (context, index) {
                    final doc = index == 0 && myReview != null ? myReview : otherReviews[index - (myReview != null ? 1 : 0)];
                    final data = doc.data() as Map<String, dynamic>;

                    return _buildReviewItem(
                      name: data['name'] ?? 'Anonymous',
                      profileUrl: data['profileUrl'],
                      rating: (data['rating'] ?? 0).toDouble(),
                      comment: data['comment'] ?? '',
                      highlight: doc['userId'] == currentUser?.uid,
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
  Future<void> _deleteMyReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final reviewRef = FirebaseFirestore.instance
        .collection('ev_stations')
        .doc(widget.stationId)
        .collection('reviews')
        .doc(user.uid);

    await reviewRef.delete();

    // Recalculate average rating
    final allReviews = await FirebaseFirestore.instance
        .collection('ev_stations')
        .doc(widget.stationId)
        .collection('reviews')
        .get();

    double total = 0;
    for (var doc in allReviews.docs) {
      total += (doc['rating'] ?? 0).toDouble();
    }

    final avgRating = allReviews.docs.isEmpty ? 0 : total / allReviews.docs.length;

    await FirebaseFirestore.instance
        .collection('ev_stations')
        .doc(widget.stationId)
        .update({'rating': avgRating});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your review was deleted.')),
    );

    setState(() {
      _commentController.clear();
      _rating = 3;
    });
  }

  Widget _buildReviewItem({
    required String name,
    String? profileUrl,
    required double rating,
    required String comment,
    bool highlight = false,
  }) {
    final isMyReview = highlight;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundImage: profileUrl != null && profileUrl.isNotEmpty
              ? NetworkImage(profileUrl)
              : const AssetImage('assets/images/profile.jpg') as ImageProvider,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: highlight ? Colors.green.shade50 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (isMyReview) ...[
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () {
                          _commentController.text = comment;
                          setState(() => _rating = rating);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('You can now edit your review. Submit to save.')),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18),
                        onPressed: () => _deleteMyReview(),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 18,
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(comment, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
