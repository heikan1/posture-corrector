import 'dart:async';
import 'dart:convert';
import 'package:posture_corrector/core/models/posture_data.dart';
import 'package:posture_corrector/core/repository/ble_service.dart';
import 'package:posture_corrector/core/repository/sqlite_posture_repository.dart';
import 'package:posture_corrector/core/utils/app_logger.dart';

class PosturePersistenceManager {
  static final PosturePersistenceManager _instance =
      PosturePersistenceManager._internal();
  factory PosturePersistenceManager() => _instance;
  PosturePersistenceManager._internal();

  final BleService _bleService = BleService();
  final SqlitePostureRepository _repository = SqlitePostureRepository();

  StreamSubscription<String>? _dataSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  final StreamController<PostureData> _postureDataController =
      StreamController<PostureData>.broadcast();
  Stream<PostureData> get postureDataStream => _postureDataController.stream;

  final StreamController<bool> _bulkSyncController =
      StreamController<bool>.broadcast();
  Stream<bool> get bulkSyncStream => _bulkSyncController.stream;

  final StreamController<bool> _calibResultController =
      StreamController<bool>.broadcast();
  Stream<bool> get calibResultStream => _calibResultController.stream;

  bool _isBulkSyncing = false;
  final List<PostureData> _bulkList = [];

  void init() {
    _dataSubscription?.cancel();
    _dataSubscription = _bleService.dataStream.listen(_handleIncomingData);

    _connectionSubscription?.cancel();
    _connectionSubscription = _bleService.connectionStateStream.listen((
      isConnected,
    ) {
      if (!isConnected) {
        _isBulkSyncing = false;
        _bulkList.clear();
        _bulkSyncController.add(false);
      }
    });
  }

  void _handleIncomingData(String dataString) async {
    try {
      final jsonData = jsonDecode(dataString);

      if (jsonData.containsKey("calib_result")) {
        _calibResultController.add(jsonData["calib_result"] == true);
        return;
      }

      if (jsonData.containsKey("bulk")) {
        if (jsonData["bulk"] == "start") {
          _isBulkSyncing = true;
          _bulkList.clear();
          _bulkSyncController.add(true);
        } else if (jsonData["bulk"] == "end") {
          if (_bulkList.isNotEmpty) {
            await _repository.saveDataList(_bulkList);
            _bulkList.clear();
          }
          _isBulkSyncing = false;
          _bulkSyncController.add(false);
        }
        return;
      }

      final postureData = PostureData.fromJson(jsonData);

      if (_isBulkSyncing) {
        _bulkList.add(postureData);
      } else {
        _repository.saveData(postureData).catchError((e) {
          AppLogger.e("SQLite Persistence Error", e);
          return 0;
        });

        _postureDataController.add(postureData);
      }
    } catch (e) {
      AppLogger.e("Data parsing/persistence error", e);
    }
  }

  void dispose() {
    _dataSubscription?.cancel();
    _connectionSubscription?.cancel();
    _postureDataController.close();
    _bulkSyncController.close();
    _calibResultController.close();
  }
}
