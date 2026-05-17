import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class FileViewer extends StatelessWidget {
  final String fileUrl;
  final String fileName;
  final int currentPage;
  const FileViewer({super.key, required this.fileUrl, required this.fileName, this.currentPage = 1});

  @override
  Widget build(BuildContext context) {
    final ext = fileName.split('.').last.toLowerCase();
    final isPdf = ext == 'pdf';
    return Container(
      color: AppColors.card,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPdf ? Icons.picture_as_pdf_outlined : Icons.slideshow_outlined,
              size: 64,
              color: isPdf ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 12),
            Text(
              fileName,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Live preview not available on this platform.\nExport as JPG/PNG pages to present inline.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
