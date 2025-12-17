import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WellnessProductsSection extends StatelessWidget {
  final bool isOwnProfile;
  final List<Map<String, dynamic>> products;
  final VoidCallback? onEdit;

  const WellnessProductsSection({
    Key? key,
    required this.isOwnProfile,
    required this.products,
    this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty && !isOwnProfile) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Products',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: onEdit,
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (products.isEmpty)
            Text(
              'Add products to sell',
              style: GoogleFonts.poppins(color: Colors.grey),
            )
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final p = products[i];
                  return Container(
                    width: 160,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(child: Text('Image')),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p['name'] ?? 'Product',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          p['price'] ?? '',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
