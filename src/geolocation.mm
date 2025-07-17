#import "geolocation.h"
#import <CoreLocation/CoreLocation.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

@interface GeolocationDelegate : NSObject <CLLocationManagerDelegate>
@property (nonatomic, assign) Geolocation *owner;
@end

@implementation GeolocationDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    if (self.owner && locations.lastObject) {
        self.owner->handle_location_update(locations.lastObject);
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    if (self.owner) {
        self.owner->handle_error(error);
    }
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    if (self.owner) {
        CLAuthorizationStatus status;
        if (@available(iOS 14.0, *)) {
            status = manager.authorizationStatus;
        } else {
            status = [CLLocationManager authorizationStatus];
        }
        self.owner->handle_authorization_change(status);
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
    if (self.owner) {
        self.owner->handle_heading_update(newHeading);
    }
}
@end


Geolocation::Geolocation() {
    location_manager = CFBridgingRetain([[CLLocationManager alloc] init]);
    location_delegate = CFBridgingRetain([[GeolocationDelegate alloc] init]);
    
    CLLocationManager *manager = (__bridge CLLocationManager *)location_manager;
    GeolocationDelegate *delegate = (__bridge GeolocationDelegate *)location_delegate;
    
    manager.delegate = delegate;
    delegate.owner = this;
    
    is_updating_location = false;
    is_updating_heading = false;
    
    godot::UtilityFunctions::print("Geolocation GDExtension Initialized.");
}

Geolocation::~Geolocation() {
    CLLocationManager *manager = (__bridge CLLocationManager *)location_manager;
    manager.delegate = nil;
    
    CFRelease(location_manager);
    CFRelease(location_delegate);
    
    godot::UtilityFunctions::print("Geolocation GDExtension Deinitialized.");
}

void Geolocation::_bind_methods() {
    ClassDB::bind_method(D_METHOD("start_updating_location"), &Geolocation::start_updating_location);
    ClassDB::bind_method(D_METHOD("stop_updating_location"), &Geolocation::stop_updating_location);
    ClassDB::bind_method(D_METHOD("request_permission"), &Geolocation::request_permission);
    ClassDB::bind_method(D_METHOD("get_authorization_status"), &Geolocation::get_authorization_status);
    
    ClassDB::bind_method(D_METHOD("is_updating_location"), &Geolocation::is_updating_location_getter);
    ClassDB::bind_method(D_METHOD("is_updating_heading"), &Geolocation::is_updating_heading_getter);
    
    ADD_SIGNAL(MethodInfo("location_updated", PropertyInfo(Variant::DICTIONARY, "location_data")));
    ADD_SIGNAL(MethodInfo("authorization_changed", PropertyInfo(Variant::INT, "status")));
    ADD_SIGNAL(MethodInfo("error_occurred", PropertyInfo(Variant::INT, "error_code"), PropertyInfo(Variant::STRING, "error_message")));
    ADD_SIGNAL(MethodInfo("heading_updated", PropertyInfo(Variant::DICTIONARY, "heading_data")));
    
    BIND_ENUM_CONSTANT(PERMISSION_STATUS_UNKNOWN);
    BIND_ENUM_CONSTANT(PERMISSION_STATUS_DENIED);
    BIND_ENUM_CONSTANT(PERMISSION_STATUS_ALLOWED);
    
    BIND_ENUM_CONSTANT(ERROR_DENIED);
    BIND_ENUM_CONSTANT(ERROR_NETWORK);
    BIND_ENUM_CONSTANT(ERROR_HEADING_FAILURE);
    BIND_ENUM_CONSTANT(ERROR_LOCATION_UNKNOWN);
    BIND_ENUM_CONSTANT(ERROR_UNKNOWN);
}

void Geolocation::start_updating_location() {
    CLLocationManager *manager = (__bridge CLLocationManager *)location_manager;
    [manager startUpdatingLocation];
    is_updating_location = true;
}

void Geolocation::stop_updating_location() {
    CLLocationManager *manager = (__bridge CLLocationManager *)location_manager;
    [manager stopUpdatingLocation];
    is_updating_location = false;
}

void Geolocation::request_permission() {
    CLLocationManager *manager = (__bridge CLLocationManager *)location_manager;
    if ([manager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [manager requestWhenInUseAuthorization];
    }
}

Geolocation::GeolocationAuthorizationStatus Geolocation::get_authorization_status() {
    CLAuthorizationStatus status;
    if (@available(iOS 14.0, *)) {
        CLLocationManager *manager = (__bridge CLLocationManager *)location_manager;
        status = manager.authorizationStatus;
    } else {
        status = [CLLocationManager authorizationStatus];
    }
    return to_godot_authorization_status(status);
}

bool Geolocation::is_updating_location_getter() const {
    return is_updating_location;
}

bool Geolocation::is_updating_heading_getter() const {
    return is_updating_heading;
}

void Geolocation::handle_location_update(void *location_ptr) {
    CLLocation *location = (__bridge CLLocation *)location_ptr;
    
    Dictionary data;
    data["latitude"] = location.coordinate.latitude;
    data["longitude"] = location.coordinate.longitude;
    data["altitude"] = location.altitude;
    data["accuracy"] = location.horizontalAccuracy;
    data["speed"] = location.speed;
    data["timestamp"] = (int64_t)location.timestamp.timeIntervalSince1970;

    emit_signal("location_updated", data);
}

void Geolocation::handle_error(void *error_ptr) {
    NSError *error = (__bridge NSError *)error_ptr;
    GeolocationErrorCodes godot_error_code = ERROR_UNKNOWN;
    
    switch (error.code) {
        case kCLErrorDenied: godot_error_code = ERROR_DENIED; break;
        case kCLErrorNetwork: godot_error_code = ERROR_NETWORK; break;
        case kCLErrorHeadingFailure:
            godot_error_code = ERROR_HEADING_FAILURE;
            is_updating_heading = false;
            break;
        case kCLErrorLocationUnknown: godot_error_code = ERROR_LOCATION_UNKNOWN; break;
        default: godot_error_code = ERROR_UNKNOWN; break;
    }
    
    is_updating_location = false;
    emit_signal("error_occurred", (int)godot_error_code, [error.localizedDescription UTF8String]);
}

void Geolocation::handle_authorization_change(int native_status) {
    GeolocationAuthorizationStatus status = to_godot_authorization_status(native_status);
    emit_signal("authorization_changed", (int)status);
}

void Geolocation::handle_heading_update(void *heading_ptr) {
    CLHeading *heading = (__bridge CLHeading *)heading_ptr;

    Dictionary data;
    data["magnetic_heading"] = heading.magneticHeading;
    data["true_heading"] = heading.trueHeading;
    data["accuracy"] = heading.headingAccuracy;
    data["timestamp"] = (int64_t)heading.timestamp.timeIntervalSince1970;

    emit_signal("heading_updated", data);
}

Geolocation::GeolocationAuthorizationStatus Geolocation::to_godot_authorization_status(int native_status) {
    switch (native_status) {
        case kCLAuthorizationStatusNotDetermined: return PERMISSION_STATUS_UNKNOWN;
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse: return PERMISSION_STATUS_ALLOWED;
        case kCLAuthorizationStatusRestricted:
        case kCLAuthorizationStatusDenied:
        default: return PERMISSION_STATUS_DENIED;
    }
}
