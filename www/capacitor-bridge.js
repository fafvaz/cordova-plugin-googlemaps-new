var CapacitorGoogleMapsBridge = (function() {
    var _isCapacitor = false;
    var _Capacitor = null;
    var _Plugins = null;
    var _PluginInstance = null;

    function init() {
        if (typeof window !== 'undefined') {
            _Capacitor = window.Capacitor;
            if (_Capacitor && _Capacitor.Plugins) {
                _isCapacitor = true;
                _Plugins = _Capacitor.Plugins;
                _PluginInstance = _Plugins.CapacitorGoogleMaps;
            }
        }
    }

    function isCapacitor() {
        return _isCapacitor;
    }

    /**
     * Universal Exec Function
     * Intercepts ALL methods from the original plugin and routes them to Capacitor.
     * 
     * @param {Function} success - Success callback
     * @param {Function} error - Error callback
     * @param {String} service - Service name (e.g., 'plugin.google.maps')
     * @param {String} action - Method name (e.g., 'addMarker', 'remove', 'setCenter')
     * @param {Array} args - Arguments array
     */
    function exec(success, error, service, action, args) {
        // Only intercept if running in Capacitor and targeting our map service
        if (!_isCapacitor || !_PluginInstance || service !== 'plugin.google.maps') {
            // Fallback to Cordova if not capacitor or wrong service
            if (window.cordova && window.cordova.exec) {
                return window.cordova.exec(success, error, service, action, args);
            }
            if (error) error("Capacitor not detected or Cordova exec missing");
            return;
        }

        // Check if the method exists on the native plugin
        if (typeof _PluginInstance[action] !== 'function') {
            // If specific method missing, try generic 'invoke' if implemented, else error
            if (typeof _PluginInstance.invoke === 'function') {
                _PluginInstance.invoke({ method: action, args: args })
                    .then(function(result) { if (success) success(result); })
                    .catch(function(err) { if (error) error(err); });
            } else {
                if (error) error("Method " + action + " not found in CapacitorGoogleMaps plugin");
            }
            return;
        }

        // Prepare arguments: Convert Array to Object for Capacitor
        // The original plugin passes an array. Capacitor prefers an object.
        // We map common patterns or pass the whole array as 'params'
        var options = {};
        
        if (args && args.length > 0) {
            // Heuristic mapping for common signatures
            if (action === 'create') {
                options = { 'div': args[0], 'options': args[1] || {} };
            } else if (action === 'addMarker' || action === 'addPolyline' || action === 'addPolygon' || action === 'addCircle') {
                options = { 'data': args[0] };
            } else if (action === 'setCenter' || action === 'animateCamera') {
                options = { 'position': args[0] };
            } else if (action === 'setZoom') {
                options = { 'zoom': args[0] };
            } else if (action === 'setMapTypeId') {
                options = { 'mapTypeId': args[0] };
            } else if (action === 'getVisibleRegion') {
                options = {}; // No args
            } else {
                // Generic fallback: pass the first arg as options, rest as extra
                options = typeof args[0] === 'object' ? args[0] : { 'value': args[0] };
                if (args.length > 1) options['_extraArgs'] = args.slice(1);
            }
        }

        // Execute the native method
        _PluginInstance[action](options)
            .then(function(result) {
                // Capacitor returns a Promise. Resolve the Cordova-style callback.
                // Handle specific result transformations if needed here
                if (success) {
                    // If result is a simple value, pass it. If it's a complex object, ensure it's JSObject compatible
                    success(result);
                }
            })
            .catch(function(err) {
                if (error) error(err);
            });
    }

    init();

    return {
        isCapacitor: isCapacitor,
        exec: exec
    };
})();

// Auto-inject into cordova.exec if possible
(function() {
    if (typeof module !== 'undefined' && module.exports) {
        module.exports = CapacitorGoogleMapsBridge;
    }
    // Expose globally
    window.CapacitorGoogleMapsBridge = CapacitorGoogleMapsBridge;
})();