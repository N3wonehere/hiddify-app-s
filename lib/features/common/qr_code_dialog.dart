import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCodeDialog extends StatelessWidget {
  const QrCodeDialog(this.data, {super.key, this.message, this.width = 420, this.backgroundColor = Colors.white});

  final String data;
  final String? message;
  final double width;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveWidth = width.clamp(0, MediaQuery.sizeOf(context).shortestSide - 32).toDouble();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: effectiveWidth,
            child: QrImageView(
              data: data,
              backgroundColor: backgroundColor,
              errorCorrectionLevel: QrErrorCorrectLevel.L,
            ),
          ),
          if (message != null)
            SizedBox(
              width: effectiveWidth,
              child: Material(
                color: theme.colorScheme.surface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        message!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
