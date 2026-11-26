import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/backup_automation_service.dart';

void main() {
  group('BackupAutomationService.isNetworkAllowed', () {
    test('Wi-Fi policy runs only on Wi-Fi', () {
      expect(
        BackupAutomationService.isNetworkAllowed(
          [ConnectivityResult.wifi],
          BackupAutomationService.wifiOnly,
        ),
        isTrue,
      );
      expect(
        BackupAutomationService.isNetworkAllowed(
          [ConnectivityResult.mobile],
          BackupAutomationService.wifiOnly,
        ),
        isFalse,
      );
      expect(
        BackupAutomationService.isNetworkAllowed(
          [ConnectivityResult.ethernet],
          BackupAutomationService.wifiOnly,
        ),
        isFalse,
      );
    });

    test('mobile-data policy runs only on cellular data', () {
      expect(
        BackupAutomationService.isNetworkAllowed(
          [ConnectivityResult.mobile],
          BackupAutomationService.mobileDataOnly,
        ),
        isTrue,
      );
      expect(
        BackupAutomationService.isNetworkAllowed(
          [ConnectivityResult.wifi],
          BackupAutomationService.mobileDataOnly,
        ),
        isFalse,
      );
    });

    test('Both policy accepts Wi-Fi, mobile data, and ethernet', () {
      for (final connection in [
        ConnectivityResult.wifi,
        ConnectivityResult.mobile,
        ConnectivityResult.ethernet,
      ]) {
        expect(
          BackupAutomationService.isNetworkAllowed(
            [connection],
            BackupAutomationService.wifiAndMobileData,
          ),
          isTrue,
        );
      }
      expect(
        BackupAutomationService.isNetworkAllowed(
          [ConnectivityResult.none],
          BackupAutomationService.wifiAndMobileData,
        ),
        isFalse,
      );
    });
  });
}
