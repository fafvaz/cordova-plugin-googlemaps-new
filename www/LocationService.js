/*****************************************************************************
 * LocationService class
 *****************************************************************************/
var LatLng = require('./LatLng');

var LocationService = function(exec) {
  function _errorHandler(err) {
    console.error(err);
  }
  return {
    hasPermission: function(callback, errorCallback) {
      var self = this;

      var resolver = function(resolve, reject) {
        exec.call({
          _isReady: true
        },
        function(hasPermission) {
          resolve.call(self, hasPermission === 1);
        },
        reject.bind(self), 'PluginLocationService', 'hasPermission', [], {sync: true});
      };

      var errorHandler = function(result) {
        if (typeof errorCallback === 'function') {
          errorCallback.call(self, result);
        } else {
          (self.errorHandler || _errorHandler).call(self, result);
        }
      };
      if (typeof callback === 'function') {
        resolver(callback, errorHandler);
        return self;
      } else {
        return new Promise(resolver);
      }
    },
    getMyLocation: function(params, success_callback, errorCallback) {
      var self = this;
      var args = [params || {}, success_callback || null, errorCallback];
      if (typeof args[0] === 'function') {
        args.unshift({});
      }
      params = args[0];
      success_callback = args[1];
      errorCallback = args[2];


      var resolver = function(resolve, reject) {
        exec.call({
          _isReady: true
        },
        function(location) {
          location.latLng = new LatLng(location.latLng.lat, location.latLng.lng);
          resolve.call(self, location);
        },
        reject.bind(self), 'PluginLocationService', 'getMyLocation', [params], {sync: true});
      };

      params.enableHighAccuracy = params.enableHighAccuracy === true;
      var errorHandler = function(result) {
        if (typeof errorCallback === 'function') {
          errorCallback.call(self, result);
        } else {
          (self.errorHandler || _errorHandler).call(self, result);
        }
      };

      if (typeof success_callback === 'function') {
        resolver(success_callback, errorHandler);
        return self;
      } else {
        return new Promise(resolver);
      }
    },
    getSuggestionsFromLocations: function(arg1, arg2, arg3, arg4) {
      var self = this;
      var input, region, success_callback, errorCallback;
      var params = {};

      // Support two calling conventions:
      // 1) getSuggestionsFromLocations(input, region, success, error)
      // 2) getSuggestionsFromLocations({input, country, language, types, locationBias, ...}, success, error)
      if (typeof arg1 === 'string') {
        input = arg1;
        region = arg2;
        success_callback = arg3;
        errorCallback = arg4;
        params.input = input;
        if (region) {
          params.region = region;
        }
      } else if (typeof arg1 === 'object' && arg1 !== null) {
        input = arg1.input;
        region = arg1.country || arg1.region;
        success_callback = arg2;
        errorCallback = arg3;
        // Pass through all supported Places API (New) parameters
        params.input = input;
        if (arg1.country) params.country = arg1.country;
        if (arg1.region) params.region = arg1.region;
        if (arg1.language) params.language = arg1.language;
        if (arg1.languageCode) params.languageCode = arg1.languageCode;
        if (arg1.types) params.types = arg1.types;
        if (arg1.includedPrimaryTypes) params.includedPrimaryTypes = arg1.includedPrimaryTypes;
        if (arg1.locationBias) params.locationBias = arg1.locationBias;
        if (arg1.locationRestriction) params.locationRestriction = arg1.locationRestriction;
        if (arg1.origin) params.origin = arg1.origin;
        if (arg1.inputOffset) params.inputOffset = arg1.inputOffset;
        if (arg1.sessionToken) params.sessionToken = arg1.sessionToken;
      } else if (typeof arg1 === 'function') {
        success_callback = arg1;
        errorCallback = arg2;
      }

      var resolver = function(resolve, reject) {
        exec.call({
          _isReady: true
        },
        function(suggestions) {
          resolve.call(self, suggestions);
        },
        reject.bind(self), 'PluginLocationService', 'getSuggestionsFromLocations', [params], {sync: true});
      };

      var errorHandler = function(result) {
        if (typeof errorCallback === 'function') {
          errorCallback.call(self, result);
        } else {
          (self.errorHandler || _errorHandler).call(self, result);
        }
      };

      if (typeof success_callback === 'function') {
        resolver(success_callback, errorHandler);
        return self;
      } else {
        return new Promise(resolver);
      }
    }
  };
};

/**
 // TODO:
LocationService.prototype.followMyPosition = function(params, success_callback, errorCallback) {
  var self = this;
  var args = [params || {}, success_callback || null, errorCallback];
  if (typeof args[0] === 'function') {
      args.unshift({});
  }
  self.on('currentPosition_changed', success_callback);
  var successHandler = function(location) {
      location.latLng = new LatLng(location.latLng.lat, location.latLng.lng);
      if (typeof success_callback === 'function') {
          success_callback.call(self, location);
      }
      self.set('currentPosition', location);
  };
  var errorHandler = function(result) {
      if (typeof errorCallback === 'function') {
          errorCallback.call(self, result);
      }
  };
  exec.call({
    _isReady: true
  }, successHandler, errorHandler, 'CordovaGoogleMaps', 'followMyPosition', [params], {sync: true});
};

LocationService.prototype.clearFollowing = function() {
  var self = this;
  self.off('currentPosition_changed');
  exec.call({
    _isReady: true
  }, successHandler, errorHandler, 'CordovaGoogleMaps', 'clearFollowing', [params], {sync: true});
};
**/

module.exports = LocationService;
