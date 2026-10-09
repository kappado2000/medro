import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/icd_provider.dart';
import '../help/ajutor.dart';
import '../theme/app_theme.dart';

class IcdScreen extends StatefulWidget {
  const IcdScreen({super.key});

  @override
  State<IcdScreen> createState() => _IcdScreenState();
}

class _IcdScreenState extends State<IcdScreen> {
  final _controller = TextEditingController();
  String _interogare = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IcdProvider>();
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: AppColors.headerGradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: const Text(
                          'ICD-10',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const ButonAjutor(ajutorIcd),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    provider.incarcat && provider.eroare == null
                        ? '${provider.total} coduri · CIM-10-AM, lista RoDRG'
                        : 'Se încarcă clasificarea…',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    onChanged: (v) => setState(() => _interogare = v),
                    decoration: InputDecoration(
                      hintText: 'Cod (F32.1) sau diagnostic',
                      hintStyle: const TextStyle(color: AppColors.muted),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.blue,
                      ),
                      suffixIcon: _interogare.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: AppColors.muted,
                              ),
                              onPressed: () {
                                _controller.clear();
                                setState(() => _interogare = '');
                              },
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: _continut(provider)),
      ],
    );
  }

  Widget _continut(IcdProvider provider) {
    if (!provider.incarcat) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.eroare != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Clasificarea nu a putut fi încărcată.\n${provider.eroare}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.red),
          ),
        ),
      );
    }
    if (_interogare.trim().isEmpty) {
      return ListView.separated(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: provider.capitole.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _CapitolTile(provider.capitole[i]),
      );
    }
    final rezultate = provider.cauta(_interogare);
    if (rezultate.isEmpty) {
      return const Center(
        child: Text(
          'Niciun cod găsit',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    return IcdLista(coduri: rezultate);
  }
}

class _CapitolTile extends StatelessWidget {
  final IcdCapitol capitol;
  const _CapitolTile(this.capitol);

  @override
  Widget build(BuildContext context) {
    final psihiatrie = capitol.index == IcdProvider.indexPsihiatrie;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final provider = context.read<IcdProvider>();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => IcdListaScreen(
                titlu: 'Capitolul ${capitol.numar}',
                subtitlu: '${capitol.titlu} (${capitol.interval})',
                coduri: provider.categorii(capitol),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: psihiatrie ? AppColors.redSoft : AppColors.blueSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  capitol.numar,
                  style: TextStyle(
                    color: psihiatrie ? AppColors.red : AppColors.blue,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capitol.titlu,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      capitol.interval,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pagina cu categoriile unui capitol sau subcodurile unui cod.
class IcdListaScreen extends StatelessWidget {
  final String titlu;
  final String subtitlu;
  final List<IcdCod> coduri;

  const IcdListaScreen({
    super.key,
    required this.titlu,
    required this.subtitlu,
    required this.coduri,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titlu)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.blue,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              subtitlu,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
          Expanded(child: IcdLista(coduri: coduri)),
        ],
      ),
    );
  }
}

class IcdLista extends StatelessWidget {
  final List<IcdCod> coduri;
  const IcdLista({super.key, required this.coduri});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: coduri.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _CodTile(coduri[i]),
    );
  }
}

class _CodTile extends StatelessWidget {
  final IcdCod cod;
  const _CodTile(this.cod);

  @override
  Widget build(BuildContext context) {
    final provider = context.read<IcdProvider>();
    final areSubcoduri = provider.areSubcoduri(cod);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: areSubcoduri
            ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => IcdListaScreen(
                    titlu: cod.cod,
                    subtitlu: cod.titlu,
                    coduri: provider.subcoduri(cod),
                  ),
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              Container(
                width: 68,
                padding: const EdgeInsets.symmetric(vertical: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.blueSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  cod.cod,
                  style: const TextStyle(color: AppColors.blue, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  cod.titlu,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    height: 1.25,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copiază codul',
                icon: const Icon(Icons.copy, size: 18, color: AppColors.muted),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: cod.cod));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text('${cod.cod} copiat'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                },
              ),
              if (areSubcoduri)
                const Icon(Icons.chevron_right, color: AppColors.muted),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
