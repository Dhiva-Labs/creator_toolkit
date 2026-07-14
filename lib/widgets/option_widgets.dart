import 'package:flutter/material.dart';

/// Card wrapper for a group of tool options.
class OptionCard extends StatelessWidget {
  const OptionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.display,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(display ?? value.round().toString(),
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Wrap of choice chips bound to a single selected value.
class ChipSelector<T> extends StatelessWidget {
  const ChipSelector({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  /// value → label
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in options.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: entry.key == value,
            onSelected: (_) => onChanged(entry.key),
          ),
      ],
    );
  }
}

/// Standard page body for tool tabs: scrollable, centered, max 760 wide.
class ToolTabBody extends StatelessWidget {
  const ToolTabBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// The big "run" button shown under the options.
class ProcessButton extends StatelessWidget {
  const ProcessButton({
    super.key,
    required this.label,
    required this.busy,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: FilledButton.icon(
        onPressed: enabled && !busy ? onPressed : null,
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.bolt),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(busy ? 'Processing…' : label),
        ),
      ),
    );
  }
}
