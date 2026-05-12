import Foundation
import Capacitor
import GoogleMaps
import GoogleMapsUtils

@objc(CapacitorGoogleMapsBridge)
public class CapacitorGoogleMapsBridge: CAPPlugin, GMSMapViewDelegate {
    
    private var mapView: GMSMapView?
    private var markers: [String: GMSMarker] = [:]
    private var polylines: [String: GMSPolyline] = [:]
    private var polygons: [String: GMSPolygon] = [:]
    private var circles: [String: GMSCircle] = [:]
    private var overlays: [String: GMSGroundOverlay] = [:]
    
    // MARK: - Dynamic Method Handling
    
    override public func load() {
        super.load()
        // Initialization logic
    }
    
    // Define explicit methods for type safety and completion handling
    @objc func create(_ call: CAPPluginCall) {
        let options = call.getObject("options") ?? [:]
        let divId = options["div"] as? String ?? "map_canvas"
        
        // Setup MapView
        let camera = GMSCameraPosition.camera(withLatitude: -33.86, longitude: 151.20, zoom: 12.0)
        let frame = CGRect(x: 0, y: 0, width: self.bridge?.webView?.bounds.width ?? 300, height: self.bridge?.webView?.bounds.height ?? 300)
        
        self.mapView = GMSMapView(frame: frame)
        self.mapView?.camera = camera
        self.mapView?.delegate = self
        self.mapView?.autoAdjustInsets = false
        
        // Note: Adding to WebView hierarchy requires accessing private APIs or using a Capacitor View Plugin approach
        // For standard hybrid, we assume the view is managed externally or via a custom UIView plugin pattern
        // Here we just confirm creation
        call.resolve(["status": "created", "mapId": divId])
    }
    
    @objc func addMarker(_ call: CAPPluginCall) {
        guard let data = call.getObject("data") else {
            call.reject("No marker data")
            return
        }
        
        let lat = data["lat"] as? Double ?? 0.0
        let lng = data["lng"] as? Double ?? 0.0
        let title = data["title"] as? String
        let iconUrl = data["icon"] as? String
        
        let marker = GMSMarker(position: CLLocationCoordinate2D(latitude: lat, longitude: lng))
        marker.title = title
        if let iconUrl = iconUrl {
            // Load icon from URL (implementation omitted for brevity)
        }
        marker.map = self.mapView
        
        let markerId = UUID().uuidString
        self.markers[markerId] = marker
        
        call.resolve(["id": markerId, "hash": markerId])
    }
    
    @objc func addPolyline(_ call: CAPPluginCall) {
        guard let data = call.getObject("data") else { call.reject("No data"); return }
        let pointsData = data["points"] as? [[String: Any]] ?? []
        
        var path = GMSMutablePath()
        for point in pointsData {
            let lat = point["lat"] as? Double ?? 0.0
            let lng = point["lng"] as? Double ?? 0.0
            path.add(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        
        let polyline = GMSPolyline(path: path)
        polyline.strokeColor = UIColor.blue
        polyline.strokeWidth = 3.0
        polyline.map = self.mapView
        
        let lineId = UUID().uuidString
        self.polylines[lineId] = polyline
        call.resolve(["id": lineId])
    }
    
    @objc func addPolygon(_ call: CAPPluginCall) {
        guard let data = call.getObject("data") else { call.reject("No data"); return }
        let pointsData = data["points"] as? [[String: Any]] ?? []
        
        var path = GMSMutablePath()
        for point in pointsData {
            let lat = point["lat"] as? Double ?? 0.0
            let lng = point["lng"] as? Double ?? 0.0
            path.add(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        
        let polygon = GMSPolygon(path: path)
        polygon.fillColor = UIColor.blue.withAlphaComponent(0.3)
        polygon.strokeColor = UIColor.blue
        polygon.strokeWidth = 2.0
        polygon.map = self.mapView
        
        let polyId = UUID().uuidString
        self.polygons[polyId] = polygon
        call.resolve(["id": polyId])
    }
    
    @objc func addCircle(_ call: CAPPluginCall) {
        guard let data = call.getObject("data") else { call.reject("No data"); return }
        let lat = data["center"]?["lat"] as? Double ?? 0.0
        let lng = data["center"]?["lng"] as? Double ?? 0.0
        let radius = data["radius"] as? CLLocationDistance ?? 100.0
        
        let circle = GMSCircle(position: CLLocationCoordinate2D(latitude: lat, longitude: lng), radius: radius)
        circle.strokeColor = UIColor.red
        circle.fillColor = UIColor.red.withAlphaComponent(0.2)
        circle.map = self.mapView
        
        let circleId = UUID().uuidString
        self.circles[circleId] = circle
        call.resolve(["id": circleId])
    }
    
    @objc func setCenter(_ call: CAPPluginCall) {
        guard let position = call.getObject("position") else { call.reject("No position"); return }
        let lat = position["lat"] as? Double ?? 0.0
        let lng = position["lng"] as? Double ?? 0.0
        
        let camera = GMSCameraPosition.camera(withLatitude: lat, longitude: lng, zoom: self.mapView?.camera.zoom ?? 1.0)
        self.mapView?.animate(to: camera)
        call.resolve()
    }
    
    @objc func setZoom(_ call: CAPPluginCall) {
        let zoom = Float(call.getInt("zoom") ?? 1)
        let camera = GMSCameraPosition.camera(withLatitude: self.mapView?.camera.target.latitude ?? 0.0, 
                                              longitude: self.mapView?.camera.target.longitude ?? 0.0, 
                                              zoom: zoom)
        self.mapView?.animate(to: camera)
        call.resolve()
    }
    
    @objc func setMapTypeId(_ call: CAPPluginCall) {
        let typeId = call.getString("mapTypeId") ?? "normal"
        switch typeId {
            case "satellite": self.mapView?.mapType = .satellite
            case "hybrid": self.mapView?.mapType = .hybrid
            case "terrain": self.mapView?.mapType = .terrain
            default: self.mapView?.mapType = .normal
        }
        call.resolve()
    }
    
    @objc func getVisibleRegion(_ call: CAPPluginCall) {
        guard let bounds = self.mapView?.projection.visibleRegion().bounds else {
            call.reject("Could not get visible region")
            return
        }
        
        let result: [String: Any] = [
            "northeast": ["lat": bounds.northeast.latitude, "lng": bounds.northeast.longitude],
            "southwest": ["lat": bounds.southwest.latitude, "lng": bounds.southwest.longitude]
        ]
        call.resolve(result as PluginCallResultData)
    }
    
    @objc func remove(_ call: CAPPluginCall) {
        self.mapView?.removeFromSuperview()
        self.mapView = nil
        self.markers.removeAll()
        self.polylines.removeAll()
        self.polygons.removeAll()
        self.circles.removeAll()
        call.resolve()
    }
    
    @objc func clear(_ call: CAPPluginCall) {
        self.markers.forEach { $0.value.map = nil }
        self.markers.removeAll()
        self.polylines.forEach { $0.value.map = nil }
        self.polylines.removeAll()
        self.polygons.forEach { $0.value.map = nil }
        self.polygons.removeAll()
        self.circles.forEach { $0.value.map = nil }
        self.circles.removeAll()
        call.resolve()
    }

    // Generic Invoke for any other method not explicitly defined
    @objc func invoke(_ call: CAPPluginCall) {
        let methodName = call.getString("method") ?? ""
        let args = call.getArray("args") ?? []
        
        // Log and resolve for unimplemented methods to prevent crashes
        print("Method invoked: \(methodName) with args: \(args)")
        call.resolve(["status": "invoked", "method": methodName])
    }
    
    // MARK: - Delegate Methods (Event Emitters)
    
    public func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
        guard let id = findId(for: marker, in: markers) else { return false }
        notifyListeners("onMarkerClick", data: ["markerId": id])
        return false // Allow default behavior
    }
    
    public func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
        notifyListeners("onMapClick", data: ["lat": coordinate.latitude, "lng": coordinate.longitude])
    }
    
    public func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
        let data: [String: Any] = [
            "lat": position.target.latitude,
            "lng": position.target.longitude,
            "zoom": position.zoom,
            "bearing": position.bearing,
            "tilt": position.viewingAngle
        ]
        notifyListeners("onCameraChange", data: data)
    }
    
    // Helper to find ID
    private func findId<T>(for object: T, in dict: [String: T]) -> String? {
        for (key, value) in dict {
            if value === object { return key }
        }
        return nil
    }
}