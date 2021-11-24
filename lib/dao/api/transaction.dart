class HgTransaction {
  Object? transaction;

  HgTransaction(this.transaction);

  static T getOr<T>(HgTransaction? tx, T defaultTx) {
    if (null == tx) {
      return defaultTx;
    }
    if (null != tx.transaction) {
      return tx.transaction! as T;
    }
    return defaultTx;
  }
}
