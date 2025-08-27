import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        "question": "How do I book a charging slot?",
        "answer": "Go to a station detail and tap on 'Book Slot'."
      },
      {
        "question": "Can I cancel my booking?",
        "answer": "Yes, bookings can be canceled before start time."
      },
      {
        "question": "Is payment required in advance?",
        "answer": "Some stations may require advance payment depending on policy."
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqs.length,
        itemBuilder: (context, index) {
          final faq = faqs[index];
          return ExpansionTile(
            title: Text(faq["question"]!, style: const TextStyle(fontWeight: FontWeight.bold)),
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(faq["answer"]!),
              ),
            ],
          );
        },
      ),
    );
  }
}
