class HgTransaction {
  Object transaction;

  HgTransaction(this.transaction);

  static T getOr<T>(HgTransaction? tx, T defaultTx) {
    if (null == tx) {
      return defaultTx;
    }
    return tx.transaction as T;
  }

  T getTx<T>() => transaction as T;
}
