import 'package:flutter/material.dart';

import '../models/medicament.dart';
import '../theme/app_theme.dart';
import '../utils/text_utils.dart';

IconData iconForma(String forma) {
  final f = forma.toUpperCase();
  if (f.contains('INJ') || f.contains('PERF')) return Icons.vaccines_outlined;
  if (f.contains('COMPR') || f.contains('CAPS') || f.contains('DRAJ')) {
    return Icons.medication_outlined;
  }
  if (f.contains('SIROP') ||
      f.contains('SOL') ||
      f.contains('SUSP') ||
      f.contains('PIC')) {
    return Icons.water_drop_outlined;
  }
  if (f.contains('CREMA') || f.contains('UNG') || f.contains('GEL')) {
    return Icons.spa_outlined;
  }
  if (f.contains('INHAL') || f.contains('SPRAY')) return Icons.air;
  return Icons.medication_liquid_outlined;
}

/// Eticheta cu tipul de prescriptie: albastru pentru OTC, rosu pentru reteta.
class PrescriptieBadge extends StatelessWidget {
  final String cod;
  const PrescriptieBadge(this.cod, {super.key});

  @override
  Widget build(BuildContext context) {
    if (cod.isEmpty) return const SizedBox.shrink();
    final otc = cod == 'OTC';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: otc ? AppColors.blueSoft : AppColors.redSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        cod,
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 0.3,
          color: otc ? AppColors.blue : AppColors.red,
        ),
      ),
    );
  }
}

class MedicamentTile extends StatelessWidget {
  final Medicament medicament;
  final bool favorit;
  final VoidCallback onTap;

  const MedicamentTile({
    super.key,
    required this.medicament,
    required this.favorit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final m = medicament;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.blueSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconForma(m.forma),
                  color: AppColors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.denumire,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      titleCase(m.dci),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.liste.isEmpty
                          ? m.forma.toLowerCase()
                          : '${m.forma.toLowerCase()} · CNAS ${m.liste.join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PrescriptieBadge(m.prescriptie),
                  if (favorit) ...[
                    const SizedBox(height: 8),
                    const Icon(Icons.favorite, color: AppColors.red, size: 18),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
