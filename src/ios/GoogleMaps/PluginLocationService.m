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

    NSLog(@"[getSuggestionsFromLocations] called with input=%@, country=%@, language=%@, types=%@", opts[@"input"] ?: @"(null)", opts[@"country"] ?: @"(null)", opts[@"language"] ?: @"(null)", opts[@"types"] ?: @"(null)");

    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    [body setObject:opts[@"input"] forKey:@"input"];

    if (opts[@"language"]) {
        [body setObject:opts[@"language"] forKey:@"languageCode"];
    }
    if (opts[@"types"]) {
        [body setObject:opts[@"types"] forKey:@"includedPrimaryTypes"];
    }
    if (opts[@"country"]) {
        [body setObject:opts[@"country"] forKey:@"regionCode"];
    } else if (opts[@"region"]) {
        [body setObject:opts[@"region"] forKey:@"regionCode"];
    }
    if (opts[@"locationBias"]) {
        [body setObject:opts[@"locationBias"] forKey:@"locationBias"];
    }
    if (opts[@"locationRestriction"]) {
        [body setObject:opts[@"locationRestriction"] forKey:@"locationRestriction"];
    }
    if (opts[@"origin"]) {
        [body setObject:opts[@"origin"] forKey:@"origin"];
    }
    if (opts[@"inputOffset"]) {
        [body setObject:opts[@"inputOffset"] forKey:@"inputOffset"];
    }
    if (opts[@"sessionToken"]) {
        [body setObject:opts[@"sessionToken"] forKey:@"sessionToken"];
    }

    __autoreleasing NSError *jsonError = nil;
    NSData *jsonBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
    if (jsonError || !jsonBody) {
        NSLog(@"[getSuggestionsFromLocations] failed to serialize JSON body: %@", jsonError);
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"JSON_SERIALIZE_ERROR"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    NSLog(@"[getSuggestionsFromLocations] request body: %@", [[NSString alloc] initWithData:jsonBody encoding:NSUTF8StringEncoding]);

    NSURL *url = [NSURL URLWithString:@"https://places.googleapis.com/v1/places:autocomplete"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setHTTPBody:jsonBody];

    NSString *apiKey = [((CDVViewController *)self.viewController).settings
        objectForKey:@"google_maps_ios_api_key"];
    if (apiKey.length == 0) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                            messageAsString:@"GOOGLE_MAPS_IOS_API_KEY is missing"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    [request setValue:apiKey forHTTPHeaderField:@"X-Goog-Api-Key"];

    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleId.length == 0) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                            messageAsString:@"IOS_BUNDLE_IDENTIFIER_UNAVAILABLE"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    [request setValue:bundleId forHTTPHeaderField:@"X-Ios-Bundle-Identifier"];
    NSLog(@"[getSuggestionsFromLocations] iOS Bundle ID: %@", bundleId);

    [request setValue:@"suggestions.placePrediction.text,suggestions.placePrediction.placeId,suggestions.placePrediction.structuredFormat" forHTTPHeaderField:@"X-Goog-FieldMask"];

    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
    NSURLSessionDataTask *postTask = [session dataTaskWithRequest:request
                                              completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                  [session finishTasksAndInvalidate];

                                                  NSString *responseString = nil;
                                                  if (data) {
                                                      responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                                                  }

                                                  if (error) {
                                                      NSLog(@"[getSuggestionsFromLocations] network error = %@", error.description);
                                                      CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"NETWORK_ERROR: %@", error.description]];
                                                      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                                                      return;
                                                  }

                                                  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                                  if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
                                                      NSLog(@"[getSuggestionsFromLocations] HTTP error: %ld, body: %@", (long)httpResponse.statusCode, responseString ?: @"(empty)");
                                                      NSString *errorMsg = [NSString stringWithFormat:@"HTTP_%ld", (long)httpResponse.statusCode];
                                                      if (responseString) {
                                                          NSError *parseError = nil;
                                                          NSDictionary *errJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
                                                          if (errJson && [errJson objectForKey:@"error"]) {
                                                              NSDictionary *err = [errJson objectForKey:@"error"];
                                                              if ([err objectForKey:@"message"]) {
                                                                  errorMsg = [NSString stringWithFormat:@"%@: %@", [err objectForKey:@"status"] ?: @"REQUEST_DENIED", [err objectForKey:@"message"]];
                                                              }
                                                          } else {
                                                              errorMsg = [NSString stringWithFormat:@"%@: %@", errorMsg, responseString];
                                                          }
                                                      }
                                                      CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMsg];
                                                      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                                                      return;
                                                  }

                                                  NSDictionary *json = nil;
                                                  if (data) {
                                                      NSError *__autoreleasing localError = nil;
                                                      json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&localError];
                                                      if (localError) {
                                                          NSLog(@"[getSuggestionsFromLocations] JSON parse error: %@", localError.description);
                                                          CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"JSON_PARSE_ERROR: %@", localError.description]];
                                                          [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                                                          return;
                                                      }
                                                  }

                                                  CDVPluginResult* pluginResult;
                                                  if (!json) {
                                                      NSLog(@"[getSuggestionsFromLocations] json is nil after 2xx response (no data or parse issue)");
                                                      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"NO_RESPONSE_DATA"];
                                                  } else {
                                                      NSArray *suggestions = [json objectForKey:@"suggestions"];
                                                      NSMutableArray *out = [NSMutableArray array];
                                                      for (NSDictionary *suggestion in suggestions) {
                                                          NSDictionary *pred = [suggestion objectForKey:@"placePrediction"];
                                                          if (pred) {
                                                              NSString *description = @"";
                                                              NSDictionary *textObj = [pred objectForKey:@"text"];
                                                              if (textObj) {
                                                                  description = [textObj objectForKey:@"text"] ?: @"";
                                                              }
                                                              if ([description isEqualToString:@""]) {
                                                                  NSDictionary *sf = [pred objectForKey:@"structuredFormat"];
                                                                  if (sf) {
                                                                      NSDictionary *mainText = [sf objectForKey:@"mainText"];
                                                                      if (mainText) {
                                                                          description = [mainText objectForKey:@"text"] ?: @"";
                                                                      }
                                                                  }
                                                              }
                                                              [out addObject:description];
                                                          }
                                                      }
                                                      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:out];
                                                      NSLog(@"[getSuggestionsFromLocations] success: %lu suggestions returned", (unsigned long)out.count);
                                                  }
                                                  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                                              }];
    [postTask resume];
}

@end
