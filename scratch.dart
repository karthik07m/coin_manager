import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  var t = TextCellValue("Hello");
  print(t.value);
  var d = DoubleCellValue(10.5);
  print(d.value);
  var dt = DateCellValue(year: 2023, month: 10, day: 1);
  print(dt.year);
}
