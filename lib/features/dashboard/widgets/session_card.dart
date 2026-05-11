import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/session_model.dart';

class SessionCard extends StatelessWidget {
  final SessionModel session;
  final VoidCallback onTap;

  const SessionCard({super.key, required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM y');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: session.isActive
                    ? AppColors.lime.withOpacity(0.1)
                    : AppColors.border,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                session.isActive ? Icons.sensors : Icons.sensors_off_outlined,
                color: session.isActive ? AppColors.lime : AppColors.textMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${session.code}  •  ${df.format(session.createdAt)}',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: session.isActive
                    ? AppColors.green.withOpacity(0.1)
                    : AppColors.border,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                session.isActive ? 'LIVE' : 'ENDED',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: session.isActive ? AppColors.green : AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
