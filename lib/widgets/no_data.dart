import 'package:flutter/material.dart';

class NoData extends StatelessWidget {
  final title;
  final imagePath;
  final double textFontSize;
  const NoData(
      {Key? key,
      required this.title,
      required this.imagePath,
      required this.textFontSize})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final Size size = mediaQuery.size;

    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: SizedBox(
        height: size.height * 0.5,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (size.height > 500)
              Flexible(child: Image.asset(imagePath, fit: BoxFit.fill)),
            SizedBox(
              height: size.height * 0.01,
            ),
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
