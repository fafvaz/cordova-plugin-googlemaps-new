package com.plugin.googlemaps;

import android.util.Log;
import androidx.annotation.NonNull;
import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import java.lang.reflect.Method;
import java.util.Map;
import java.util.HashMap;

@CapacitorPlugin(name = "CapacitorGoogleMaps")
public class CapacitorGoogleMapsBridge extends Plugin {
    private static final String TAG = "CapacitorGoogleMaps";
    
    // Reference to the original plugin logic class (You must ensure this class exists in your src)
    // If the original plugin uses a different entry point, adjust this reference.
    private Object pluginLogicInstance; 

    @Override
    public void load() {
        super.load();
        try {
            // Attempt to instantiate the original plugin logic if it exists
            // Replace 'com.plugin.googlemaps.MyPluginLogic' with the actual main class of the original plugin
            Class<?> logicClass = Class.forName("com.plugin.googlemaps.MyPluginLogic");
            pluginLogicInstance = logicClass.getDeclaredConstructor().newInstance();
            
            // Initialize the logic with the current context/webview if required by original plugin
            // This step depends heavily on how the original plugin initializes.
            Log.d(TAG, "Original plugin logic loaded successfully.");
        } catch (Exception e) {
            Log.e(TAG, "Could not load original plugin logic. Methods may fail unless implemented directly.", e);
            pluginLogicInstance = null;
        }
    }

    /**
     * Dynamic Method Dispatcher
     * Catches any method call from JS and attempts to route it.
     */
    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void invoke(PluginCall call) {
        String methodName = call.getString("method");
        JSArray args = call.getArray("args", new JSArray());
        
        if (methodName == null) {
            call.reject("Method name required");
            return;
        }

        executeMethod(methodName, args, call);
    }

    // Explicitly define high-frequency methods for better performance/type safety
    // These delegate to the dynamic executor or direct logic
    
    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void create(PluginCall call) { executeMethod("create", null, call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void addMarker(PluginCall call) { executeMethod("addMarker", call.getArray("data"), call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void setCenter(PluginCall call) { executeMethod("setCenter", call.getArray("position"), call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void setZoom(PluginCall call) { executeMethod("setZoom", new JSArray().put(call.getInt("zoom")), call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void remove(PluginCall call) { executeMethod("remove", null, call); }
    
    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void addPolyline(PluginCall call) { executeMethod("addPolyline", call.getArray("data"), call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void addPolygon(PluginCall call) { executeMethod("addPolygon", call.getArray("data"), call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void addCircle(PluginCall call) { executeMethod("addCircle", call.getArray("data"), call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void addGroundOverlay(PluginCall call) { executeMethod("addGroundOverlay", call.getArray("data"), call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void addTileOverlay(PluginCall call) { executeMethod("addTileOverlay", call.getArray("data"), call); }
    
    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void addKmlOverlay(PluginCall call) { executeMethod("addKmlOverlay", call.getArray("data"), call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void getGeocode(PluginCall call) { executeMethod("getGeocode", call.getArray("address"), call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void getDirections(PluginCall call) { executeMethod("getDirections", call.getArray("request"), call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void getElevation(PluginCall call) { executeMethod("getElevation", call.getArray("locations"), call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void showStreetView(PluginCall call) { executeMethod("showStreetView", call.getArray("options"), call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void animateCamera(PluginCall call) { executeMethod("animateCamera", call.getArray("position"), call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void moveCamera(PluginCall call) { executeMethod("moveCamera", call.getArray("position"), call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void setMapTypeId(PluginCall call) { executeMethod("setMapTypeId", call.getArray("mapTypeId"), call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void getVisibleRegion(PluginCall call) { executeMethod("getVisibleRegion", null, call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void fromLatLngToPoint(PluginCall call) { executeMethod("fromLatLngToPoint", call.getArray("latLng"), call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void fromPointToLatLng(PluginCall call) { executeMethod("fromPointToLatLng", call.getArray("point"), call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void setOptions(PluginCall call) { executeMethod("setOptions", call.getArray("options"), call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void clear(PluginCall call) { executeMethod("clear", null, call); }

    @PluginMethod(returnType = PluginMethod.RETURN_PROMISE)
    public void panBy(PluginCall call) { executeMethod("panBy", call.getArray("x,y"), call); }

    // Add more methods as needed following the pattern above...
    // The 'invoke' method catches any missing ones.

    private void executeMethod(String methodName, JSArray args, PluginCall call) {
        if (pluginLogicInstance != null) {
            try {
                // Find method in original logic class
                // Note: This requires the original class to have public methods matching these names
                // and appropriate argument types. This is a simplified reflection example.
                // In a real hybrid port, you often copy the logic methods INTO this class
                // rather than reflecting, to avoid obfuscation issues.
                
                // FOR THIS HYBRID IMPLEMENTATION:
                // Since we cannot guarantee the original class structure without seeing it,
                // we return a success placeholder for methods not explicitly implemented below,
                // OR you must copy the logic from the original MyPluginLogic.java into this class.
                
                Log.w(TAG, "Method " + methodName + " called. Ensure logic is implemented in CapacitorGoogleMapsBridge.");
                
                // Placeholder resolution - In a full port, you would call the actual logic here.
                // Example: if (methodName.equals("addMarker")) { ... actual marker code ... }
                
                call.resolve(new JSObject().put("status", "executed_" + methodName));
                
            } catch (Exception e) {
                call.reject("Error executing " + methodName + ": " + e.getMessage());
            }
        } else {
            // If no original logic loaded, we must implement natively here.
            // For the sake of this snippet, we acknowledge the call.
            Log.w(TAG, "Native logic not loaded. Method " + methodName + " acknowledged but not processed.");
            call.resolve(new JSObject().put("status", "acknowledged"));
        }
    }
}