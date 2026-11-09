
var LOCATION_ERROR = {
  '1': 'service_denied',
  '2': 'not_available',
  '3': 'timeout'
};

module.exports = {
  'hasPermission': function(onSuccess, onError) {
    if (navigator.permissions) {
      navigator.permissions.query({'name': 'geolocation'})
        .then(function(permission) {
          onSuccess(permission.state === 'granted' ? 1 : 0);
        })
        .catch(onError);
    } else {
      onError('Browser does not support this feature.');
    }
  },
  'getMyLocation': function(onSuccess, onError) {

    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(function(position) {
        onSuccess({
          'latLng': {
            'lat': position.coords.latitude,
            'lng': position.coords.longitude
          },
          'elapsedRealtimeNanos': 0,
          'time': position.timestamp,
          'accuracy': position.coords.accuracy,
          'altitude': position.coords.altitude,
          'speed': position.coords.speed,
          'bearing': position.coords.heading,
          'provider': 'geolocationapi',
          'hashCode': 'dummy',
          'status': true
        });
      }, function(error) {
        onError({
          'status': false,
          'error_code': LOCATION_ERROR[error.code],
          'error_message': error.message
        });
      }, {
        'enableHighAccuracy': true
      });
    } else {
      onError({
        'status': false,
        'error_code': 'not_available',
        'error_message': 'Since this device does not have any location provider, this app can not detect your location.'
      });
    }
  },
  'getSuggestionsFromLocations': function(options, onSuccess, onError) {
    // Support legacy calling convention: getSuggestionsFromLocations(onSuccess, onError)
    if (typeof options === 'function') {
      onError = onSuccess;
      onSuccess = options;
      options = {};
    }

    var input = options && options.input;
    if (!input) {
      onError({
        'status': false,
        'error_code': 'invalid_request',
        'error_message': 'Missing required parameter: input'
      });
      return;
    }

    // Resolve API key from environment or options
    var apiKey = options.apiKey || '';
    try {
      var env = (typeof Environment !== 'undefined' && Environment._getEnv) ? Environment._getEnv() : null;
      if (env && env.API_KEY_FOR_BROWSER_RELEASE) {
        apiKey = env.API_KEY_FOR_BROWSER_RELEASE;
      }
    } catch (e) {
      // ignore
    }

    // Build JSON request body for Places API (New) Autocomplete
    var body = { input: input };
    if (options.languageCode) body.languageCode = options.languageCode;
    else if (options.language) body.languageCode = options.language;
    var primaryTypes = options.includedPrimaryTypes || options.types;
    if (primaryTypes) {
      body.includedPrimaryTypes = typeof primaryTypes === 'string' ?
        primaryTypes.split(',').map(function(type) { return type.trim(); }).filter(Boolean) :
        primaryTypes;
    }
    if (options.regionCode) body.regionCode = options.regionCode;
    else if (options.country) body.regionCode = options.country;
    else if (options.region) body.regionCode = options.region;
    if (options.includedRegionCodes) body.includedRegionCodes = options.includedRegionCodes;
    if (options.includeQueryPredictions !== undefined) {
      body.includeQueryPredictions = options.includeQueryPredictions;
    }
    if (options.locationBias) body.locationBias = options.locationBias;
    if (options.locationRestriction) body.locationRestriction = options.locationRestriction;
    if (options.origin) body.origin = options.origin;
    if (options.inputOffset) body.inputOffset = options.inputOffset;
    if (options.sessionToken) body.sessionToken = options.sessionToken;

    fetch('https://places.googleapis.com/v1/places:autocomplete', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'suggestions.placePrediction.text,suggestions.placePrediction.placeId,suggestions.placePrediction.structuredFormat,suggestions.queryPrediction.text'
      },
      body: JSON.stringify(body)
    })
    .then(function(response) {
      if (!response.ok) {
        throw new Error('HTTP ' + response.status);
      }
      return response.json();
    })
    .then(function(data) {
      var suggestions = data.suggestions || [];
      var out = suggestions.map(function(s) {
        var pred = s.placePrediction || s.queryPrediction || {};
        var text = '';
        if (pred.text && pred.text.text) {
          text = pred.text.text;
        } else if (pred.structuredFormat && pred.structuredFormat.mainText && pred.structuredFormat.mainText.text) {
          text = pred.structuredFormat.mainText.text;
        }
        return text;
      });
      onSuccess(out);
    })
    .catch(function(err) {
      onError({
        'status': false,
        'error_code': 'request_failed',
        'error_message': err.message || 'UNKNOWN_ERROR'
      });
    });
  }
};


require('cordova/exec/proxy').add('PluginLocationService', module.exports);
