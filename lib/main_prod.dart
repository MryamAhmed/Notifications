import 'package:notifecation/flavors.dart';
import 'package:notifecation/main_common.dart';

Future<void> main() async {
  Flavor.appFlavor = AppFlavor.prod;
  await mainCommon();
}
