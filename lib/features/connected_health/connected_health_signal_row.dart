part of 'connected_health_page.dart';

/// Keep readable values below their label when accessibility text cannot fit
/// beside it. The normal-size row retains its established layout.
class _ConnectedSignalRow extends StatelessWidget {
  const _ConnectedSignalRow({
    required this.leading,
    required this.title,
    required this.trailing,
    this.contentPadding = EdgeInsets.zero,
  });
  final Widget leading, title, trailing;
  final EdgeInsetsGeometry contentPadding;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= 280 &&
          MediaQuery.textScalerOf(context).scale(16) < 24) {
        return ListTile(
          contentPadding: contentPadding,
          leading: leading,
          title: title,
          trailing: trailing,
        );
      }
      return MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Expanded(child: title),
                ],
              ),
              const SizedBox(height: 8),
              Align(alignment: AlignmentDirectional.centerEnd, child: trailing),
            ],
          ),
        ),
      );
    },
  );
}
