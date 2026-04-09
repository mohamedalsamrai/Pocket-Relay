import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_radii.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_meta_surface.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_transcript_frame.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';
import 'package:pocket_relay/widgetbook/catalog/story_catalog_layout.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookCategory buildCoreUiWidgetbookCategory() {
  return WidgetbookCategory(
    name: 'Core UI',
    children: <WidgetbookNode>[
      WidgetbookComponent(
        name: 'Panel Surface',
        useCases: <WidgetbookUseCase>[
          WidgetbookUseCase(
            name: 'Default',
            builder: (context) {
              final theme = Theme.of(context);
              final palette = theme.extension<PocketPalette>()!;
              return widgetbookStoryCanvas(
                child: PocketPanelSurface(
                  padding: const EdgeInsets.all(PocketSpacing.md),
                  radius: PocketRadii.lg,
                  backgroundColor: palette.surface,
                  borderColor: palette.surfaceBorder,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: palette.shadowColor.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shared panel surface',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: PocketSpacing.xs),
                      Text(
                        'This container is reused for settings and support surfaces that need a consistent panel shell.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      WidgetbookComponent(
        name: 'Transcript Frame',
        useCases: <WidgetbookUseCase>[
          WidgetbookUseCase(
            name: 'Default',
            builder: (context) {
              final theme = Theme.of(context);
              final cards = TranscriptPalette.of(context);
              final accent = blueAccent(theme.brightness);
              return widgetbookStoryCanvas(
                child: PocketTranscriptFrame(
                  backgroundColor: cards.tintedSurface(accent),
                  borderColor: cards.accentBorder(accent),
                  shadowColor: cards.shadow,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transcript frame primitive',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: PocketSpacing.xs),
                      Text(
                        'Transcript items use this shared shell for width, radius, border, and elevation behavior.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cards.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      WidgetbookComponent(
        name: 'Badges',
        useCases: <WidgetbookUseCase>[
          WidgetbookUseCase(
            name: 'Variants',
            builder: (context) {
              final theme = Theme.of(context);
              return widgetbookStoryCanvas(
                child: Wrap(
                  spacing: PocketSpacing.sm,
                  runSpacing: PocketSpacing.sm,
                  children: [
                    PocketTintBadge(
                      label: 'Pending',
                      color: amberAccent(theme.brightness),
                    ),
                    PocketSolidBadge(
                      label: 'Running',
                      color: blueAccent(theme.brightness),
                    ),
                    const InlinePulseChip(label: 'Streaming'),
                    StateChip(
                      label: 'Saved',
                      color: tealAccent(theme.brightness),
                    ),
                    TranscriptBadge(
                      label: 'Approved',
                      color: tealAccent(theme.brightness),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      WidgetbookComponent(
        name: 'Meta Surface',
        useCases: <WidgetbookUseCase>[
          WidgetbookUseCase(
            name: 'Default',
            builder: (context) => widgetbookStoryCanvas(
              child: PocketMetaSurface(
                title: 'Session attached',
                body:
                    'Pocket Relay resumed the existing Codex conversation without losing transcript context.',
                accent: tealAccent(Theme.of(context).brightness),
                icon: Icons.link_rounded,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
