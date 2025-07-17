#import "geolocation.h"
#import <CoreLocation/CoreLocation.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#if VERSION_MAJOR == 4
typedef PackedByteArray GodotByteArray;
#define GODOT_FLOAT_VARIANT_TYPE Variant::FLOAT
#define GODOT_BYTE_ARRAY_VARIANT_TYPE Variant::PACKED_BYTE_ARRAY
#else
typedef PoolByteArray GodotByteArray;
#define GODOT_FLOAT_VARIANT_TYPE Variant::REAL
#define GODOT_BYTE_ARRAY_VARIANT_TYPE Variant::POOL_BYTE_ARRAY
#endif


/*
 * Geolocation Objective C Class
 */

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
        if (@available(iOS 14.0, *)) {
            self.owner->handle_authorization_change(manager.authorizationStatus);
        } else {
            self.owner->handle_authorization_change([CLLocationManager authorizationStatus]);
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
    if (self.owner) {
        self.owner->handle_heading_update(newHeading);
    }
}
@end

- (void)initialize;

- (bool)supportsMethod:(String)methodName;

- (Geolocation::GeolocationAuthorizationStatus)authorizationStatus;

- (void)requestLocation;
- (void)startWatch;

- (void)sendLocationUpdate:(CLLocation *) location;

// LocationManager Delegate methods
- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations;
- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error;
- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager;
- (void)locationManager:(CLLocationManager *)manager
       didUpdateHeading:(CLHeading *)newHeading;

- (void)startFailureTimeout; // -timeout
- (void)stopFailureTimeout; // -timeout
- (void)onFailureTimeout; // -timeout
//- (void)setFailureTimeout; // -timeout

@end


// Construcutor

Geolocation::Geolocation() {
	location_manager = [[CLLocationManager alloc] init];
	location_delegate = [[GeolocationDelegate alloc] init];
	
	CLLocationManager *manager = (__bridge CLLocationManager *)location_manager;
	GeolocationDelegate *delegate = (__bridge GeolocationDelegate *)location_delegate;
	
	manager.delegate = delegate;
	delegate.owner = this;
	
	is_updating_location = false;
	is_updating_heading = false;
	return_coordinates_as_string = false;
	only_send_latest_location = true;
	send_debug_log = false;
	
	godot::UtilityFunctions::print("Geolocation GDExtension Initialized.");
}

Geolocation::~Geolocation() {
	CLLocationManager *manager = (__bridge_transfer CLLocationManager *)location_manager;
	__bridge_transfer GeolocationDelegate *delegate;
	
	manager.delegate = null;
	
	godot::UtilityFunctions::print("Geolocation GDExtension Deinitialized.");
}

void Geolocation::_bind_methods() {
	// Methods
	ClassDB::bind_method(D_METHOD("Start_updating_location"), &Geolocation::start_updating_location);
	ClassDB::bind_method(D_METHOD("Stop_updating_location"), &Geolocation::stop_updating_location);
	ClassDB::bind_method(D_METHOD("request_permission"), &Geolocation::request_permission);
	ClassDB::bind_method(D_METHOD("get_authorization_status"), &Geolocation::get_authorization_status);
	
	// Getters for the state
	ClassDB::bind_method(D_METHOD("is_updating_location"), &Geolocation::is_updating_location_getter);
	ClassDB::bind_method(D_METHOD("is_updating_heading"), &Geolocation::is_updating_heading_getter);
	
	// Signals
	ADD_SIGNAL(MethodInfo("location_updated", PropertyInfo(Variant::DICTIONARY, "location_data")));
	ADD_SIGNAL(MethodInfo("authorization_changed", PropertyInfo(Variant::INT, "status")));
	ADD_SIGNAL(MethodInfo("error_occurred", PropertyInfo(Variant::INT, "error_code"), PropertyInfo(Variant::STRING, "error_message")));
	ADD_SIGNAL(MethodInfo("heading_updated", PropertyInfo(Variant::DICTIONARY, "heading_data")));
	ADD_SIGNAL(MethodInfo("log_message", PropertyInfo(Variant::STRING, "message")));
	
	// ENUMS
	BIND_ENUM_CONSTANT(PERMISSION_STATUS_UNKNOWN);
	BIND_ENUM_CONSTANT(PERMISSION_STATUS_DENIED);
	BIND_ENUM_CONSTANT(PERMISSION_STATUS_ALLOWED);
    
	BIND_ENUM_CONSTANT(ERROR_DENIED);
	BIND_ENUM_CONSTANT(ERROR_NETWORK);
	BIND_ENUM_CONSTANT(ERROR_HEADING_FAILURE);
	BIND_ENUM_CONSTANT(ERROR_LOCATION_UNKNOWN);
	BIND_ENUM_CONSTANT(ERROR_UNKNOWN);

/*
 * Bind plugin's public interface
 */
void Geolocation::_bind_methods() {
    
    ClassDB::bind_method(D_METHOD("supports"), &Geolocation::supports);
    // authorization
    ClassDB::bind_method(D_METHOD("request_permission"), &Geolocation::request_permission);
    ClassDB::bind_method(D_METHOD("authorization_status"), &Geolocation::authorization_status);
    ClassDB::bind_method(D_METHOD("allows_full_accuracy"), &Geolocation::allows_full_accuracy);
    ClassDB::bind_method(D_METHOD("can_request_permissions"), &Geolocation::can_request_permissions);
    ClassDB::bind_method(D_METHOD("is_updating_location"), &Geolocation::is_updating_location);
    ClassDB::bind_method(D_METHOD("is_updating_heading"), &Geolocation::is_updating_heading);
    
    ClassDB::bind_method(D_METHOD("request_location_capabilty"), &Geolocation::request_location_capabilty);
    ClassDB::bind_method(D_METHOD("should_show_permission_requirement_explanation"), &Geolocation::should_show_permission_requirement_explanation);
    ClassDB::bind_method(D_METHOD("should_check_location_capability"), &Geolocation::should_check_location_capability);
    
    // options
    ClassDB::bind_method(D_METHOD("set_update_interval","seconds"), &Geolocation::set_update_interval); // not supported, noop
    ClassDB::bind_method(D_METHOD("set_max_wait_time","seconds"), &Geolocation::set_max_wait_time); // not supported, noop
    ClassDB::bind_method(D_METHOD("set_auto_check_location_capability","autocheck"), &Geolocation::set_auto_check_location_capability); // not supported, noop
    

    ClassDB::bind_method(D_METHOD("set_distance_filter","meters"), &Geolocation::set_distance_filter);
    ClassDB::bind_method(D_METHOD("set_desired_accuracy","accuracy"), &Geolocation::set_desired_accuracy);
    // return value configuration (also possible in info.plist so this might be not needed
    ClassDB::bind_method(D_METHOD("set_return_string_coordinates", "value"), &Geolocation::set_return_string_coordinates);
    
    ClassDB::bind_method(D_METHOD("set_debug_log_signal","send"), &Geolocation::set_debug_log_signal);
    ClassDB::bind_method(D_METHOD("set_failure_timeout","seconds"), &Geolocation::set_failure_timeout);
    
    // location
    ClassDB::bind_method(D_METHOD("request_location"), &Geolocation::request_location);
    ClassDB::bind_method(D_METHOD("start_updating_location"), &Geolocation::start_updating_location);
    ClassDB::bind_method(D_METHOD("stop_updating_location"), &Geolocation::stop_updating_location);
    
    //heading
    ClassDB::bind_method(D_METHOD("start_updating_heading"), &Geolocation::start_updating_heading);
    ClassDB::bind_method(D_METHOD("stop_updating_heading"), &Geolocation::stop_updating_heading);
    
    //ClassDB::bind_method(D_METHOD("get_return_string_coordinates"), &Geolocation::get_return_string_coordinates);
    //ADD_PROPERTY(PropertyInfo(Variant::BOOL, "return_string_coordinates"), "set_return_string_coordinates", "get_return_string_coordinates");
    
    // signals
    ADD_SIGNAL(MethodInfo("log", PropertyInfo(Variant::STRING, "message"), PropertyInfo(Variant::REAL, "number")));
    ADD_SIGNAL(MethodInfo("error", PropertyInfo(Variant::INT, "errorCode")));
    ADD_SIGNAL(MethodInfo("location_update", PropertyInfo(Variant::DICTIONARY, "locationData")));
    ADD_SIGNAL(MethodInfo("authorization_changed", PropertyInfo(Variant::INT, "status")));
    ADD_SIGNAL(MethodInfo("heading_update", PropertyInfo(Variant::DICTIONARY, "headingData")));
    
    ADD_SIGNAL(MethodInfo("location_capability_result", PropertyInfo(Variant::BOOL, "capable")));
        
    // Enums / Constants
    
    // Authorization
    BIND_ENUM_CONSTANT(PERMISSION_STATUS_UNKNOWN);
    BIND_ENUM_CONSTANT(PERMISSION_STATUS_DENIED);
    BIND_ENUM_CONSTANT(PERMISSION_STATUS_ALLOWED);
    
    // Accuracy Authorization (get only)
    //BIND_ENUM_CONSTANT(AUTHORIZATION_FULL_ACCURACY);
    //BIND_ENUM_CONSTANT(AUTHORIZATION_REDUCED_ACCURACY);
    
    // Accuracy (set only)
    BIND_ENUM_CONSTANT(ACCURACY_BEST_FOR_NAVIGATION);
    BIND_ENUM_CONSTANT(ACCURACY_BEST);
    BIND_ENUM_CONSTANT(ACCURACY_NEAREST_TEN_METERS);
    BIND_ENUM_CONSTANT(ACCURACY_HUNDRED_METERS);
    BIND_ENUM_CONSTANT(ACCURACY_KILOMETER);
    BIND_ENUM_CONSTANT(ACCURACY_THREE_KILOMETER);
    BIND_ENUM_CONSTANT(ACCURACY_REDUCED);
    
    // Error Codes
    BIND_ENUM_CONSTANT(ERROR_DENIED);
    BIND_ENUM_CONSTANT(ERROR_NETWORK);
    BIND_ENUM_CONSTANT(ERROR_HEADING_FAILURE);
    BIND_ENUM_CONSTANT(ERROR_LOCATION_UNKNOWN);
    BIND_ENUM_CONSTANT(ERROR_TIMEOUT);
    BIND_ENUM_CONSTANT(ERROR_UNSUPPORTED);
    BIND_ENUM_CONSTANT(ERROR_LOCATION_DISABLED);
    BIND_ENUM_CONSTANT(ERROR_UNKNOWN);
    
};

bool Geolocation::supports(String methodName)
{
    return [godot_geolocation supportsMethod:methodName];
}

void Geolocation::request_permission() {
    // if we can't request permission anymore, at least trigger authorization_changed
    // so we get any answer
    if(can_request_permissions())
    {
        [godot_geolocation.locationManager requestAlwaysAuthorization];
    } else
    {
        //send_log_signal("a request_permission not possible send denied");
        send_authorization_changed_signal([godot_geolocation authorizationStatus]);
    }
};

Geolocation::GeolocationAuthorizationStatus Geolocation::authorization_status() {
    return [godot_geolocation authorizationStatus];
};

bool Geolocation::allows_full_accuracy()
{
    if (@available(iOS 14.0, *)) {
        switch(godot_geolocation.locationManager.accuracyAuthorization)
        {
            case CLAccuracyAuthorizationFullAccuracy:
                return true;
            case CLAccuracyAuthorizationReducedAccuracy:
                return false;
        }
    } else {
        return false; // just say no on iOS < 14
    }
}

void Geolocation::request_location_capabilty()
{
    // execute async because it blocks main thread (and is async on Android anyway)
    send_log_signal("a request_location_capabilty");
        
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void){
        //Background Thread
        bool capable = [CLLocationManager locationServicesEnabled];
        dispatch_async(dispatch_get_main_queue(), ^(void){
            //Run UI Updates
            send_location_capability_result(capable);
        });
    });
}

bool Geolocation::can_request_permissions()
{
    return ([godot_geolocation authorizationStatus] == PERMISSION_STATUS_UNKNOWN);
}


bool Geolocation::should_show_permission_requirement_explanation()
{
    // should send error, that this is not suppported?
    send_log_signal("a should_show_permission_requirement_explanation NOT SUPPORTED");
    return false;
}

bool Geolocation::should_check_location_capability()
{
    // not needed on ios, because authorization will be "denied" when locartion services are disabled
    return false;
}

bool Geolocation::is_updating_location()
{
    return godot_geolocation.isUpdatingLocation;
}

bool Geolocation::is_updating_heading()
{
    return godot_geolocation.isUpdatingHeading;
}


void Geolocation::set_update_interval(int seconds)
{
    send_log_signal("a set_update_interval NOT SUPPORTED");
    // not implemented on iOS
}

void Geolocation::set_max_wait_time(int seconds)
{
    send_log_signal("a set_max_wait_time NOT SUPPORTED");
    // not implemented on iOS
}

void Geolocation::set_auto_check_location_capability(bool autocheck)
{
    send_log_signal("a set_auto_check_location_capability NOT SUPPORTED");
    // not implemented on iOS
}

void Geolocation::set_distance_filter(float distance)
{
    [godot_geolocation setDistanceFilter:distance];
    //emit_signal("log", "new Distance set", distance);
}

void Geolocation::set_desired_accuracy(Geolocation::GeolocationDesiredAccuracyConstants desiredAccuracy)
{
    switch(desiredAccuracy)
    {
        case ACCURACY_BEST_FOR_NAVIGATION:
            [godot_geolocation.locationManager setDesiredAccuracy:kCLLocationAccuracyBestForNavigation];
            break;
        case ACCURACY_BEST:
            [godot_geolocation.locationManager setDesiredAccuracy:kCLLocationAccuracyBest];
            break;
        case ACCURACY_NEAREST_TEN_METERS:
            [godot_geolocation.locationManager setDesiredAccuracy:kCLLocationAccuracyNearestTenMeters];
            break;
        case ACCURACY_HUNDRED_METERS:
            [godot_geolocation.locationManager setDesiredAccuracy:kCLLocationAccuracyHundredMeters];
            break;
        case ACCURACY_KILOMETER:
            [godot_geolocation.locationManager setDesiredAccuracy:kCLLocationAccuracyKilometer];
            break;
        case ACCURACY_THREE_KILOMETER:
            [godot_geolocation.locationManager setDesiredAccuracy:kCLLocationAccuracyThreeKilometers];
            break;
        case ACCURACY_REDUCED:
            if (@available(iOS 14.0, *)) {
                [godot_geolocation.locationManager setDesiredAccuracy:kCLLocationAccuracyReduced];
            } else {
                [godot_geolocation.locationManager setDesiredAccuracy:kCLLocationAccuracyThreeKilometers];
            }
            break;
    }
}

void Geolocation::set_return_string_coordinates(bool returnStringCoordinates)
{
    godot_geolocation.returnCoordinatesAsString = returnStringCoordinates;
}

//bool Geolocation::get_return_string_coordinates()
//{
//    return godot_geolocation.returnCoordinatesAsString;
//}

void Geolocation::set_debug_log_signal(bool send)
{
    sendDebugLog = send;
    send_log_signal("a set_debug_log_signal set");
}

void Geolocation::set_failure_timeout(int seconds)
{
    send_log_signal("a set_failure_timeout");
    godot_geolocation.failureTimeout = seconds; // is setter method
    
    //godot_geolocation.failureTimeout = (double)seconds;
    //godot_geolocation.useFailureTimeout = (seconds > 0);
    
}

void Geolocation::request_location() {
    //[godot_geolocation.locationManager requestLocation];
    [godot_geolocation requestLocation];
};

void Geolocation::start_updating_location() {
    //[godot_geolocation.locationManager startUpdatingLocation];
    [godot_geolocation startWatch];
};

void Geolocation::stop_updating_location() {
    [godot_geolocation.locationManager stopUpdatingLocation];
    godot_geolocation.isUpdatingLocation = false;
};

void Geolocation::start_updating_heading() {
    [godot_geolocation.locationManager  startUpdatingHeading];
    godot_geolocation.isUpdatingHeading = true;
};

void Geolocation::stop_updating_heading() {
    [godot_geolocation.locationManager  stopUpdatingHeading];
    godot_geolocation.isUpdatingHeading = false;
};


// signals

void Geolocation::send_log_signal(String message, float number) {
    if(!sendDebugLog) return; // only log when enabled
    emit_signal("log", message, number);
};

void Geolocation::send_error_signal(Geolocation::GeolocationErrorCodes errorCode) {
    emit_signal("error", errorCode);
};

void Geolocation::send_authorization_changed_signal(Geolocation::GeolocationAuthorizationStatus status) {
    emit_signal("authorization_changed", status);
};

void Geolocation::send_location_update_signal(Dictionary locationData) {
    emit_signal("location_update", locationData);
};

void Geolocation::send_heading_update_signal(Dictionary headingData) {
    emit_signal("heading_update", headingData);
};

void Geolocation::send_location_capability_result(bool capable) {
    emit_signal("location_capability_result", capable);
};

Geolocation::Geolocation() {
    godot_geolocation = [[GodotGeolocation alloc] init];
    [godot_geolocation initialize];
    
    sendDebugLog = false;
    
    NSLog(@"initialize object");
}

Geolocation::~Geolocation() {
    NSLog(@"deinitialize object");
    godot_geolocation = nil;
}
