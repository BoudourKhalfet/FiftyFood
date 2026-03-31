import 'package:flutter/material.dart';

class ComplaintModal extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<String> reasons;
  final void Function(String reason, String? description) onSubmit;

  const ComplaintModal({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.reasons,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<ComplaintModal> createState() => _ComplaintModalState();
}

class _ComplaintModalState extends State<ComplaintModal> {
  String? selectedReason;
  final descriptionController = TextEditingController();
  final otherReasonController = TextEditingController();
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.report_gmailerrorred, color: Color(0xFFD7263D)),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              SizedBox(height: 2),
              Text(
                widget.subtitle,
                style: TextStyle(color: Colors.grey[700], fontSize: 15),
              ),
              SizedBox(height: 14),
              Text(
                "Reason",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              SizedBox(height: 5),
              Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isOpen = !_isOpen;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedReason ?? "Select a reason",
                              style: TextStyle(
                                color: selectedReason == null
                                    ? Colors.grey
                                    : Colors.black,
                              ),
                            ),
                          ),
                          Icon(
                            _isOpen
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                          ),
                        ],
                      ),
                    ),
                  ),

                  AnimatedCrossFade(
                    firstChild: SizedBox(),
                    secondChild: Container(
                      margin: EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Column(
                        children: widget.reasons.map((r) {
                          return InkWell(
                            onTap: () {
                              setState(() {
                                selectedReason = r;
                                _isOpen = false;
                                if (r != "Other") otherReasonController.clear();
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              child: Row(
                                children: [
                                  Expanded(child: Text(r)),
                                  if (selectedReason == r)
                                    Icon(Icons.check, color: Color(0xFFD7263D)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    crossFadeState: _isOpen
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: Duration(milliseconds: 200),
                  ),
                ],
              ),
              if (selectedReason == "Other") ...[
                SizedBox(height: 10),
                TextField(
                  controller: otherReasonController,
                  decoration: InputDecoration(
                    hintText: "Please specify your reason...",
                    filled: true,
                    fillColor: Color(0xFFF7F8FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                  maxLines: 2,
                ),
              ],
              SizedBox(height: 13),
              Text(
                "Description (optional)",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              SizedBox(height: 5),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  hintText: "Provide additional details...",
                  filled: true,
                  fillColor: Color(0xFFF7F8FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.arrow_back, color: Color(0xFFD7263D)),
                      label: Text(
                        "Cancel",
                        style: TextStyle(
                          color: Color(0xFFD7263D),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Color(0xFFD7263D)),
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
                      icon: Icon(
                        Icons.report_gmailerrorred,
                        color: Colors.white,
                      ),
                      label: Text(
                        "Submit Complaint",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFD7263D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final customReason = selectedReason == "Other"
                            ? otherReasonController.text.trim()
                            : selectedReason ?? '';
                        if (customReason.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Please specify a reason.")),
                          );
                          return;
                        }
                        widget.onSubmit(
                          customReason,
                          descriptionController.text.trim().isEmpty
                              ? null
                              : descriptionController.text.trim(),
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
      ),
    );
  }
}
