  Creditor? _lastRemoved;

  /// يحذف الدائن وكل سجلاته من جميع الأماكن.
  void removeCreditor(int id) {
    final i = creditors.indexWhere((c) => c.id == id);
    if (i < 0) return;
    _lastRemoved = creditors.removeAt(i);
    selectedId = creditors.isNotEmpty ? sorted.first.id : null;
    _commit();
  }

  /// يتراجع عن آخر حذف.
  void undoRemove() {
    final c = _lastRemoved;
    if (c == null) return;
    creditors.add(c);
    selectedId = c.id;
    _lastRemoved = null;
    _commit();
  }