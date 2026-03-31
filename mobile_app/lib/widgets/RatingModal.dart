import 'package:flutter/material.dart';

class RatingModal extends StatefulWidget {
  final String title;
  final String subtitle;
  final void Function(int rating, String? comment) onSubmit;

  const RatingModal({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<RatingModal> createState() => _RatingModalState();
}

class _RatingModalState extends State<RatingModal> {
  int rating = 0;
  final commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start, // Ensures left alignment
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            SizedBox(height: 2),
            // LEFT-ALIGNED subtitle
            Text(
              widget.subtitle,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.left,
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    Icons.star_border,
                    color: (index < rating)
                        ? Color(0xFF199060)
                        : Colors.grey[400],
                    size: 36,
                  ),
                  onPressed: () {
                    setState(() => rating = index + 1);
                  },
                );
              }),
            ),
            SizedBox(height: 10),
            TextField(
              controller: commentController,
              decoration: InputDecoration(
                hintText: "Tell us about your experience...",
                filled: true,
                fillColor: Color(0xFFF1F3F6),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.arrow_back, color: Color(0xFF199060)),
                    label: Text(
                      "Cancel",
                      style: TextStyle(
                        color: Color(0xFF199060),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Color(0xFF199060)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                SizedBox(width: 13),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.star_border, color: Colors.white),
                    label: Text(
                      "Submit Rating",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF199060),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: rating == 0
                        ? null
                        : () {
                            widget.onSubmit(
                              rating,
                              commentController.text.trim().isEmpty
                                  ? null
                                  : commentController.text.trim(),
                            );
                            Navigator.of(context).pop();
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
