import CoreLocation
import Foundation

protocol LocationProviding: AnyObject {
    var authorizationState: LocationService.AuthorizationState { get }
    var canRecordInBackground: Bool { get }
    var lastLocation: CLLocation? { get }
    var onLocationUpdate: ((CLLocation) -> Void)? { get set }
    func requestPermission()
    func startLowPowerMonitoring()
    func startTracking()
    func stopTracking()
}

extension LocationService: LocationProviding {}

protocol MotionProviding: AnyObject {
    var isAutomotive: Bool { get }
    var isAuthorized: Bool { get }
    var onAutomotiveChanged: ((Bool) -> Void)? { get set }
    func startMonitoring()
    func stopMonitoring()
    func refreshAuthorizationStatus()
    func requestPermission()
}

extension MotionActivityService: MotionProviding {}
