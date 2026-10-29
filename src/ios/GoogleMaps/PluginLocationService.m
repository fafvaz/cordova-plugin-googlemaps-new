//
//  PluginLocationService.m
//  cordova-googlemaps-plugin v2
//
//  Created by Masashi Katsumata.
//
//

#import "PluginLocationService.h"

@implementation PluginLocationService

- (void)pluginInitialize {
    self.locationCommandQueue = [[NSMutableArray alloc] init];
    self.lastLocation = nil;
}

/**
 * Return 1 if the app has geolocation permission
 */
- (void)hasPermission:(CDVInvokedUrlCommand*)command {
    CLAuthorizationStatus authorizationStatus = [self getAuthorizationStatus];

    // Result for the callback
    int result =
        authorizationStatus == kCLAuthorizationStatusDenied ||
        authorizationStatus == kCLAuthorizationStatusRestricted ? 0 : 1;
    
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                                messageAsInt:result]
                                callbackId:command.callbackId];

}

/**
 * Return the current position based on GPS
 */
-(void)getMyLocation:(CDVInvokedUrlCommand *)command {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Obtain the authorizationStatus
        CLAuthorizationStatus status = [self getAuthorizationStatus];
        
        if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
            NSDictionary *resultData = @{
                @"status": [NSNumber numberWithBool:NO],
                @"error_message": [PluginUtil PGM_LOCALIZATION:@"LOCATION_IS_DENIED_MESSAGE"],
                @"error_code": @"service_denied"
            };

            [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                                 messageAsDictionary:resultData]
                                        callbackId:command.callbackId];
        
        /**
         * kCLAuthorizationStatusNotDetermined
         * kCLAuthorizationStatusAuthorized
         * kCLAuthorizationStatusAuthorizedAlways
         * kCLAuthorizationStatusAuthorizedWhenInUse
         */
        } else {
            if (self.locationManager == nil) self.locationManager = [CLLocationManager new];
            self.locationManager.delegate = self;
            
            CLLocationAccuracy locationAccuracy = kCLLocationAccuracyNearestTenMeters;
            NSDictionary *opts = [command.arguments objectAtIndex:0];
            BOOL isEnabledHighAccuracy = NO;
            
            if ([opts objectForKey:@"enableHighAccuracy"]) {
                isEnabledHighAccuracy = [[opts objectForKey:@"enableHighAccuracy"] boolValue];
            }

            if (isEnabledHighAccuracy == YES) {
                locationAccuracy = kCLLocationAccuracyBestForNavigation;
                self.locationManager.distanceFilter = 5;
            } else {
                self.locationManager.distanceFilter = 10;
            }
            
            self.locationManager.desiredAccuracy = locationAccuracy;

            // http://stackoverflow.com/questions/24268070/ignore-ios8-code-in-xcode-5-compilation
            [self.locationManager requestWhenInUseAuthorization];

            if (self.lastLocation && -[self.lastLocation.timestamp timeIntervalSinceNow] < 2) {
              //---------------------------------------------------------------------
              // If the user requests the location in two seconds from the last time,
              // return the last result in order to save battery usage.
              // (Don't request the device location too much! Save battery usage!)
              //---------------------------------------------------------------------
              CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:self.lastResult];
              [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
              return;
            }

            if (self.locationCommandQueue.count == 0) {
              // Executes getMyLocation() first time
              [self.locationManager stopUpdatingLocation];

              // Why do I have to still support iOS9?
              [NSTimer scheduledTimerWithTimeInterval:6000
                                               target:self
                                             selector:@selector(locationFailed)
                                             userInfo:nil
                                              repeats:NO];
            
              [self.locationManager startUpdatingLocation];
            }
            
            [self.locationCommandQueue addObject:command];

            //CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            //[pluginResult setKeepCallbackAsBool:YES];
            //[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    });
}

-(void)locationFailed {
    if (self.lastLocation != nil) return;

    // Timeout
    [self.locationManager stopUpdatingLocation];

    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    [json setObject:[NSNumber numberWithBool:NO] forKey:@"status"];
    NSString *error_code = @"error";
    NSString *error_message = [PluginUtil PGM_LOCALIZATION:@"CAN_NOT_GET_LOCATION_MESSAGE"];
    [json setObject:[NSString stringWithString:error_message] forKey:@"error_message"];
    [json setObject:[NSString stringWithString:error_code] forKey:@"error_code"];

    for (CDVInvokedUrlCommand *command in self.locationCommandQueue) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:json];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    [self.locationCommandQueue removeAllObjects];
}

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    self.lastLocation = self.locationManager.location;

    NSMutableDictionary *latLng = [NSMutableDictionary dictionary];
    [latLng setObject:[NSNumber numberWithDouble:self.locationManager.location.coordinate.latitude] forKey:@"lat"];
    [latLng setObject:[NSNumber numberWithDouble:self.locationManager.location.coordinate.longitude] forKey:@"lng"];

    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    [json setObject:[NSNumber numberWithBool:YES] forKey:@"status"];

    [json setObject:latLng forKey:@"latLng"];
    [json setObject:[NSNumber numberWithFloat:[self.locationManager.location speed]] forKey:@"speed"];
    [json setObject:[NSNumber numberWithFloat:[self.locationManager.location altitude]] forKey:@"altitude"];

    //todo: calcurate the correct accuracy based on horizontalAccuracy and verticalAccuracy
    [json setObject:[NSNumber numberWithFloat:[self.locationManager.location horizontalAccuracy]] forKey:@"accuracy"];
    [json setObject:[NSNumber numberWithDouble:[self.locationManager.location.timestamp timeIntervalSince1970]] forKey:@"time"];
    [json setObject:[NSNumber numberWithInteger:[self.locationManager.location hash]] forKey:@"hashCode"];
    self.lastResult = json;

    for (CDVInvokedUrlCommand *command in self.locationCommandQueue) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:json];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }

    [self.locationCommandQueue removeAllObjects];
    [self.locationManager stopUpdatingLocation];
    //self.locationManager.delegate = nil;
    //self.locationManager = nil;
}
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    self.lastLocation = nil;
    self.lastResult = nil;

    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    [json setObject:[NSNumber numberWithBool:NO] forKey:@"status"];
    NSString *error_code = @"error";
    NSString *error_message = [PluginUtil PGM_LOCALIZATION:@"CAN_NOT_GET_LOCATION_MESSAGE"];
    if (error.code == kCLErrorDenied) {
        error_code = @"service_denied";
        error_message = [PluginUtil PGM_LOCALIZATION:@"LOCATION_REJECTED_BY_USER_MESSAGE"];
    }

    [json setObject:[NSString stringWithString:error_message] forKey:@"error_message"];
    [json setObject:[NSString stringWithString:error_code] forKey:@"error_code"];

    for (CDVInvokedUrlCommand *command in self.locationCommandQueue) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:json];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    [self.locationCommandQueue removeAllObjects];

}

/**
 * Extra method to get authorizationStatus from CLLocationManager depending on the iOS Version.
 * - On iOS 13 and older it gets it by [CLLocationManager authorizationStatus]
 * - On iOS 14 and newer it gets it by [CLLocationManager new].authorizationStatus
 */
- (CLAuthorizationStatus) getAuthorizationStatus {
    // Since iOS 14, authorizationStatus have to get from a CLLocationManager instance
    if (@available(iOS 14, *)) {
        return [CLLocationManager new].authorizationStatus;
        
        // iOS 13 and older
    } else {
        // Suppress deprecation warning of using authorizationStatus in the old way
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return [CLLocationManager authorizationStatus];
        #pragma clang diagnostic pop
    }
}

/**
 * Get location suggestions (autocomplete) using the Google Places API.
 * Expected input: { input: "search text", language?: "en", types?: "establishment", country?: "us" }
 * Returns: array of { place_id, description, structured_formatting }
 */
- (void)getSuggestionsFromLocations:(CDVInvokedUrlCommand *)command {
    NSDictionary *opts = [command.arguments objectAtIndex:0];
    
    if (!opts[@"input"] || [[opts objectForKey:@"input"] isEqualToString:@""]) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Missing required parameter: input"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    NSString *input = [opts objectForKey:@"input"];
    NSString *encodedInput = [input stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    
    NSString *urlStr = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/place/autocomplete/json?input=%@", encodedInput];
    
    NSUserDefaults *myDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"cordova.plugin.googlemaps"];
    NSString *apiKey = [myDefaults objectForKey:@"GOOGLE_MAPS_API_KEY"];
    if (apiKey) {
        urlStr = [urlStr stringByAppendingFormat:@"&key=%@", apiKey];
    }
    
    if (opts[@"language"]) {
        urlStr = [urlStr stringByAppendingFormat:@"&language=%@", opts[@"language"]];
    }
    if (opts[@"types"]) {
        urlStr = [urlStr stringByAppendingFormat:@"&types=%@", opts[@"types"]];
    }
    if (opts[@"country"]) {
        urlStr = [urlStr stringByAppendingFormat:@"&components=country:%@", opts[@"country"]];
    }
    
    [self.executeQueue addOperationWithBlock:^{
        [PluginUtil getJsonWithURL:[NSURL URLWithString:urlStr] completionBlock:^(BOOL succeeded, NSDictionary *response, NSString *error) {
            CDVPluginResult* pluginResult;
            if (!succeeded) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error ?: @"UNKNOWN_ERROR"];
            } else {
                NSString *status = [response objectForKey:@"status"];
                if ([@"OK" isEqualToString:status]) {
                    NSArray *predictions = [response objectForKey:@"predictions"];
                    NSMutableArray *suggestions = [NSMutableArray array];
                    for (NSDictionary *pred in predictions) {
                        [suggestions addObject:pred[@"description"]];
                    }
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:suggestions];
                } else {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:status];
                }
            }
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    }];
}

@end
