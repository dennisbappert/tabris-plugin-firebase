var Analytics = tabris.NativeObject.extend('com.eclipsesource.firebase.Analytics');

Analytics.prototype._dispose = function() {
  throw new Error('Analytics can not be disposed');
};

Analytics.prototype.logEvent = function(name, data) {
  if (typeof name !== 'string') {
    throw new Error('Invoking "logEvent" requires a string parameter "name" but received ' + name);
  }
  this._nativeCall('logEvent', {name, data: data ? data : {}});
  return this;
}

Analytics.prototype.setUserProperty = function(key, value) {
  if (typeof key !== 'string') {
    throw new Error('Invoking "setUserProperty" requires a string parameter "key" but received ' + key);
  }
  this._nativeCall('setUserProperty', {key, value});
  return this;
}

tabris.NativeObject.defineProperties(Analytics.prototype, {
  analyticsCollectionEnabled: {type: 'boolean', default: null},
  screenName: {type: 'string', default: null},
  userId: {type: 'string', default: null}
});

module.exports = new Analytics();
