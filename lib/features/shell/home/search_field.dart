import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/type_scale.dart';
import '../../../core/widgets/dally_empty_state.dart';
import '../../../core/widgets/filter_chip_pill.dart';
import '../../../core/widgets/game_tile.dart';
import 'home_filter.dart';

/// The 42px search pill plus Cancel, replacing the top bar in search mode. The
/// grid stays in place behind it; Cancel restores the bar and any prior filter.
class SearchBarRow extends ConsumerStatefulWidget {
  const SearchBarRow({super.key, required this.onCancel});
  final VoidCallback onCancel;

  @override
  ConsumerState<SearchBarRow> createState() => _SearchBarRowState();
}

class _SearchBarRowState extends ConsumerState<SearchBarRow> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(searchQueryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final query = ref.watch(searchQueryProvider);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: Insets.s3 + 2),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: Radii.pillBR,
              border: Border.all(color: _focus.hasFocus ? t.accent : t.border),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 18, color: t.textFaint),
                const Gap.h(Insets.s2),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    textInputAction: TextInputAction.search,
                    style: DallyType.body.copyWith(fontSize: 15, color: t.textPrimary),
                    cursorColor: t.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Search games',
                      hintStyle: DallyType.body.copyWith(fontSize: 15, color: t.textFaint),
                    ),
                    onChanged: (v) {
                      ref.read(searchQueryProvider.notifier).set(v);
                      setState(() {});
                    },
                  ),
                ),
                if (query.isNotEmpty)
                  Semantics(
                    button: true,
                    label: 'Clear search',
                    child: GestureDetector(
                      onTap: () {
                        _controller.clear();
                        ref.read(searchQueryProvider.notifier).clear();
                        setState(() {});
                      },
                      child: Icon(Icons.close_rounded, size: 18, color: t.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Gap.h(Insets.s3),
        GestureDetector(
          onTap: widget.onCancel,
          child: Text('Cancel',
              style: DallyType.bodyStrong.copyWith(fontSize: 14, color: t.accent)),
        ),
      ],
    );
  }
}

/// Search results: name matches as tiles in the normal grid, weaker matches in
/// a labelled list with the matched fragment in accent so the ranking is
/// legible. Empty query shows suggestions instead.
class SearchResults extends ConsumerWidget {
  const SearchResults({super.key, required this.onOpen});
  final void Function(GameModule) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final query = ref.watch(searchQueryProvider);
    final hits = ref.watch(searchResultsProvider);

    if (query.trim().isEmpty) {
      final suggestions = ref.watch(suggestedGamesProvider);
      return ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          Text('TRY',
              style: DallyType.label
                  .copyWith(fontSize: 10, letterSpacing: 1.4, color: t.textFaint)),
          const Gap(Insets.s3),
          Wrap(
            spacing: Insets.s2,
            runSpacing: Insets.s2,
            children: [
              for (final m in suggestions)
                FilterChipPill(label: m.title, selected: false, onTap: () => onOpen(m)),
            ],
          ),
        ],
      );
    }

    if (hits.isEmpty) {
      return DallyEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No games match "$query"',
        message: 'Try a category instead — Brain, Arcade, Party, Quick Play.',
      );
    }

    final tiles = hits.where((h) => h.isNameMatch).toList();
    final weak = hits.where((h) => !h.isNameMatch).toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: Insets.s3),
            child: Text('${hits.length} result${hits.length == 1 ? '' : 's'}',
                style: DallyType.monoSm.copyWith(fontSize: 11, color: t.textFaint)),
          ),
        ),
        if (tiles.isNotEmpty)
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: Insets.s3,
              crossAxisSpacing: Insets.s3,
              mainAxisExtent: 132,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final m = tiles[i].module;
                return RepaintBoundary(
                  child: GameTile(
                    title: m.title,
                    glyphAsset: m.id,
                    vibe: m.vibeLabel,
                    seats: m.players.contains(PlayerMode.passAndPlay) ? m.playerCount : null,
                    best: null,
                    onTap: () => onOpen(m),
                  ),
                );
              },
              childCount: tiles.length,
            ),
          ),
        if (weak.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: Insets.s5, bottom: Insets.s2),
              child: Text('MATCHED ON TAG',
                  style: DallyType.label
                      .copyWith(fontSize: 10, letterSpacing: 1.4, color: t.textFaint)),
            ),
          ),
          SliverList.builder(
            itemCount: weak.length,
            itemBuilder: (context, i) => _WeakRow(hit: weak[i], onOpen: onOpen),
          ),
        ],
        const SliverToBoxAdapter(child: Gap(Insets.s5)),
      ],
    );
  }
}

class _WeakRow extends StatelessWidget {
  const _WeakRow({required this.hit, required this.onOpen});
  final SearchHit hit;
  final void Function(GameModule) onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: () => onOpen(hit.module),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.s3),
        child: Row(
          children: [
            Expanded(
              child: Text(hit.module.title,
                  style: DallyType.bodyStrong.copyWith(fontSize: 15, color: t.textPrimary)),
            ),
            Text(hit.matchedOn,
                style: DallyType.body.copyWith(fontSize: 12, color: t.accent)),
            const Gap.h(Insets.s2),
            Icon(Icons.chevron_right_rounded, size: 18, color: t.textFaint),
          ],
        ),
      ),
    );
  }
}
