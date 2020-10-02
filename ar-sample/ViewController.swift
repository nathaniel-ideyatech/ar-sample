//
//  ViewController.swift
//  ar-sample
//
//  Created by Nath on 10/2/20.
//  Copyright © 2020 MLSG. All rights reserved.
//

// https://pusher.com/tutorials/realtime-geolocation-arkit-corelocation

import UIKit
import SceneKit
import ARKit
import CoreLocation

class ViewController: UIViewController, ARSCNViewDelegate, CLLocationManagerDelegate {

    let locationManager = CLLocationManager()
    var userLocation = CLLocation()
    var modelNode: SCNNode!
    let rootNodeName = "shipMesh"
    var originalTransform: SCNMatrix4!
    
    var heading = 0.0
    var distance = 0.0
    
    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    func getOrigin() -> CLLocationCoordinate2D {
        let origin = CLLocationCoordinate2D(latitude: 14.687758, longitude: 120.955859)
        return origin
    }
    
    func getDestination() -> CLLocationCoordinate2D {
        let destination = CLLocationCoordinate2D(latitude: 14.686450, longitude: 120.956937)
        return destination
    }
    
    func middlePointOfListMarkers(listCoords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {

        var x = 0.0
        var y = 0.0
        var z = 0.0

        for coordinate in listCoords{
            let lat = degreesToRadians(degrees: coordinate.latitude)
            let lon = radiansToDegrees(radians: coordinate.longitude)
            x = x + cos(lat) * cos(lon)
            y = y + cos(lat) * sin(lon)
            z = z + sin(lat)
        }

        x = x/Double(listCoords.count)
        y = y/Double(CGFloat(listCoords.count))
        z = z/Double(listCoords.count)

        let resultLon = atan2(y, x)
        let resultHyp = sqrt(x*x+y*y)
        let resultLat = atan2(z, resultHyp)

        let newLat = radiansToDegrees(radians: resultLat)
        let newLon = radiansToDegrees(radians: resultLon)
        let result = CLLocationCoordinate2D(latitude: newLat, longitude: newLon)

        return result

    }
    
    func degreesToRadians(degrees: Double) -> Double { return degrees * .pi / 180.0 }
    func radiansToDegrees(radians: Double) -> Double { return radians * 180.0 / .pi }

    func getBearingBetweenTwoPoints1(point1 : CLLocationCoordinate2D, point2 : CLLocationCoordinate2D) -> Double {
        
        let lat1 = degreesToRadians(degrees: point1.latitude)
        let lon1 = degreesToRadians(degrees: point1.longitude)

        let lat2 = degreesToRadians(degrees: point2.latitude)
        let lon2 = degreesToRadians(degrees: point2.longitude)

        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)

        return radiansToDegrees(radians: radiansBearing)
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            locationManager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            userLocation = location
            updateLocation()
        }
    }
    
    func updateLocation() {
        let middlePoint = middlePointOfListMarkers(listCoords: [getOrigin(), getDestination()])
        let location = CLLocation(latitude: middlePoint.latitude, longitude: middlePoint.longitude)
        self.distance = location.distance(from: userLocation)
        
        if self.modelNode == nil {
            let modelScene = SCNScene(named: "art.scnassets/ship.scn")
            self.modelNode = modelScene?.rootNode.childNode(withName: rootNodeName, recursively: true)
            let (minBox, maxBox) = self.modelNode.boundingBox
            self.modelNode.pivot = SCNMatrix4MakeTranslation(0, (maxBox.y - minBox.y)/2, 0)
            self.originalTransform = self.modelNode.transform
            
            positionModel(location)
            
            sceneView.scene.rootNode.addChildNode(self.modelNode)
        } else {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.0
            positionModel(location)
            
            SCNTransaction.commit()
        }
    }
    
    func positionModel(_ location: CLLocation) {
        // Rotate
        self.modelNode.transform = rotateNode(Float(-1 * degreesToRadians(degrees: self.heading - 180)), self.originalTransform)
        
        // Translate
        self.modelNode.position = translateNode(location)
        
        // Scale
        self.modelNode.scale = scaleNode(location)
        
    }
    
    func rotateNode(_ angleInRadians: Float, _ transform: SCNMatrix4) -> SCNMatrix4 {
        let rotation = SCNMatrix4MakeRotation(angleInRadians, 0, 1, 0)
        return SCNMatrix4Mult(transform, rotation)
    }
    
    func translateNode(_ location: CLLocation) -> SCNVector3 {
        let locationTransform = transformMatrix(matrix_identity_float4x4, userLocation, location)
        return positionFromTransform(locationTransform)
    }
    
    func positionFromTransform(_ transform: simd_float4x4) -> SCNVector3 {
        return SCNVector3Make(
            transform.columns.3.x, transform.columns.3.y, transform.columns.3.z
        )
    }
    
    func scaleNode(_ location: CLLocation) ->SCNVector3 {
        let scale = min(max(Float(1000/distance), 1.5), 3)
        return SCNVector3(x: scale, y: scale, z: scale)
    }
    
    func transformMatrix(_ matrix: simd_float4x4, _ originLocation: CLLocation, _ driverLocation: CLLocation) -> simd_float4x4 {
        let bearing = bearingBetweenLocations(userLocation, driverLocation)
        let rotationMatrix = rotateAroundY(matrix_identity_float4x4, Float(bearing))

        let position = simd_float4(x: 0.0, y: 0.0, z: Float(-distance), w: 0.0)
        let translationMatrix = getTranslationMatrix(matrix_identity_float4x4, position)

        let transformMatrix = simd_mul(rotationMatrix, translationMatrix)

        return simd_mul(matrix, transformMatrix)
    }

    func getTranslationMatrix(_ matrix: simd_float4x4, _ translation : simd_float4) -> simd_float4x4 {
        var matrix = matrix
        matrix.columns.3 = translation
        return matrix
    }

    func rotateAroundY(_ matrix: simd_float4x4, _ degrees: Float) -> simd_float4x4 {
        var matrix = matrix

        matrix.columns.0.x = cos(degrees)
        matrix.columns.0.z = -sin(degrees)

        matrix.columns.2.x = sin(degrees)
        matrix.columns.2.z = cos(degrees)
        return matrix.inverse
    }

    func bearingBetweenLocations(_ originLocation: CLLocation, _ driverLocation: CLLocation) -> Double {
        let lat1 = degreesToRadians(degrees: originLocation.coordinate.latitude)
        let lon1 = degreesToRadians(degrees: originLocation.coordinate.longitude)

        let lat2 = degreesToRadians(degrees: driverLocation.coordinate.latitude)
        let lon2 = degreesToRadians(degrees: driverLocation.coordinate.longitude)

        let longitudeDiff = lon2 - lon1

        let y = sin(longitudeDiff) * cos(lat2);
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(longitudeDiff);

        return atan2(y, x)
    }
}
