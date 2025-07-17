#ifndef GEOLOCATION_H
#define GEOLOCATION_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {
	
	class Geolocation : public Node {
		GDCLASS(Geolocation, Node)
			
	public:
			enum GeolocationAuthorizationStatus {
				PERMISSION_STATUS_UNKNOWN,
				PERMISSION_STATUS_DENIED,
				PERMISSION_STATUS_ALLOWED,
			};
			
			enum GeolocationErrorCodes {
				ERROR_DENIED,
				ERROR_NETWORK,
				ERROR_HEADING_FAILURE,
				ERROR_LOCATION_UNKNOWN,
				ERROR_UNKNOWN,
			};
			
	private:
		void *location_manager;
		void *location_delegate;
		
		bool is_updating_location;
		bool is_updating_heading;
		
		GeolocationAuthorizationStatus to_godot_authorization_status(int native_status);
		
	protected:
		static void _bind_methods();
		
	public:
		Geolocation();
		~Geolocation();
		
		void start_updating_location();
		void stop_updating_location();
		void request_permission();
		GeolocationAuthorizationStatus get_authorization_status();
		bool is_updating_location_getter() const;
		bool is_updating_heading_getter() const;
		
		void handle_location_update(void *location_ptr);
		void handle_error(void *error_ptr);
		void handle_authorization_change(int native_status);
		void handle_heading_update(void *heading_ptr);
	};
	
}

VARIANT_ENUM_CAST(godot::Geolocation::GeolocationAuthorizationStatus);
VARIANT_ENUM_CAST(godot::Geolocation::GeolocationDesiredAccuracyConstants);
VARIANT_ENUM_CAST(godot::Geolocation::GeolocationErrorCodes);

#endif
