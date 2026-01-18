import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/module_model.dart';
import 'firestore_paths.dart';

class ModuleService {
  Stream<List<ModuleModel>> watchModules(String courseId) {
    return FsPaths.modules(courseId)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ModuleModel.fromMap(d.id, d.data()))
            .toList());
  }

  Future<void> renameModule({
    required String courseId,
    required String moduleId,
    required String title,
  }) async {
    await FsPaths.moduleDoc(courseId, moduleId).update({
      'title': title,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a module only if it has no topics.
  /// Returns true if deleted, false if blocked (topics exist).
  Future<bool> deleteModuleIfEmpty({
    required String courseId,
    required String moduleId,
  }) async {
    final topicsSnap = await FsPaths.topics(courseId, moduleId).limit(1).get();
    if (topicsSnap.docs.isNotEmpty) return false;

    await FsPaths.moduleDoc(courseId, moduleId).delete();
    return true;
  }
  Future<void> reorderModules(String courseId, List<ModuleModel> modules) async {
    final batch = FirebaseFirestore.instance.batch();

    for (int i = 0; i < modules.length; i++) {
      final ref = FsPaths.modules(courseId).doc(modules[i].id);
      batch.update(ref, {
        'order': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> addModule({
    required String courseId,
    required String title,
    required int order,
  }) async {
    final now = FieldValue.serverTimestamp();
    await FsPaths.modules(courseId).add({
      'title': title,
      'order': order,
      'createdAt': now,
      'updatedAt': now,
    });
  }

}

