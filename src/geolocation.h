#ifndef GEOLOCATION_H
#define GEOLOCATION_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#ifdef __OBJC__
@class GodotGeolocation;
#else
typedef void GodotGeolocation;
#endif


namespace godot {
	
	class Geolocation : public Node {
		GDCLASS(Geolocation, Node)
			
	public:
			enum GeolocationAuthorizationStatus {
				PERMISSION_STATUS_UNKNOWN,
				PERMISSION_STATUS_DENIED,
				PERMISSION_STATUS_ALLOWED,
			};
			
			enum GeolocationDesiredAccuracyConstants {
				ACCURACY_BEST_FOR_NAVIGATION,
				ACCURACY_BEST,
				ACCURACY_NEAREST_TEN_METERS,
				ACCURACY_HUNDRED_METERS,
				ACCURACY_KILOMETER,
				ACCURACY_THREE_KILOMETER,
				ACCURACY_REDUCED,
			};
			
			enum GeolocationErrorCodes {
				ERROR_DENIED,
				ERROR_NETWORK,
				ERROR_HEADING_FAILURE,
				ERROR_LOCATION_UNKNOWN,
				ERROR_TIMEOUT,
				ERROR_UNSUPPORTED,
				ERROR_LOCATION_DISABLED,
				ERROR_UNKNOWN,
			};
			
	protected:
		static void _bind_methods();
		
	private:
		GodotGeolocation *godot_geolocation_instance;
		bool sendDebugLog;
		
	public:
		Geolocation();
		~Geolocation();
		
		// General
		bool supports(String methodName);
		
		// Permissions
		void request_permission();
		GeolocationAuthorizationStatus authorization_status();
		bool allows_full_accuracy();
		bool can_request_permissions();
		void request_location_capabilty();
		bool should_show_permission_requirement_explanation();
		bool should_check_location_capability();
		
		// State
		bool is_updating_location();
		bool is_updating_heading();
		
		// Settings
		void set_update_interval(int seconds);
		void set_max_wait_time(int seconds);
		void set_auto_check_location_capability(bool autocheck);
		void set_distance_filter(float distance);
		void set_desired_accuracy(GeolocationDesiredAccuracyConstants desiredAccuracy);
		void set_return_string_coordinates(bool returnStringCoordinates);
		void set_debug_log_signal(bool send);
		void set_failure_timeout(int seconds);
		
		// Actions
		void request_location();
		void start_updating_location();
		void stop_updating_location();
		void start_updating_heading();
		void stop_updating_heading();
		
		// Signals
		void send_log_signal(String message, float number = 0.0);
		void send_error_signal(GeolocationErrorCodes errorCode);
		void send_authorization_changed_signal(GeolocationAuthorizationStatus status);
		void send_location_update_signal(Dictionary locationData);
		void send_heading_update_signal(Dictionary headingData);
		void send_location_capability_result(bool capable);
	};
	
}

VARIANT_ENUM_CAST(godot::Geolocation::GeolocationAuthorizationStatus);
VARIANT_ENUM_CAST(godot::Geolocation::GeolocationDesiredAccuracyConstants);
VARIANT_ENUM_CAST(godot::Geolocation::GeolocationErrorCodes);

#endif
