//
//  indentifyCardUtil.h
//  STIDCardDemoApp
//
//  Created by star diao on 2018/9/4.
//

#import <Cordova/CDV.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <STIDCardReader/STIDCardReader.h>
#import <STIDCardReader/STMyPeripheral.h>
#import "CBPeripheral+Extensions.h"

@interface indentifyCardUtil : CDVPlugin <CBCentralManagerDelegate, CBPeripheralDelegate>{
    NSString* discoverPeripheralCallbackId;
    NSMutableDictionary* connectCallbacks;
    NSString* stateCallbackId;
    NSMutableDictionary *stopNotificationCallbacks;
    NSMutableDictionary *connectCallbackLatches;
    NSMutableDictionary *readRSSICallbacks;
    NSMutableDictionary* getIDCardMessageCallbacks;
    STIDCardReader *scaleManager;
    
}

@property (strong, nonatomic) NSMutableSet *peripherals;
@property (strong, nonatomic) CBCentralManager *manager;
@property (nonatomic,retain) STMyPeripheral *linkedPeripheral;

- (void)getMessage:(CDVInvokedUrlCommand *)command;
- (void)startScan:(CDVInvokedUrlCommand *)command;
- (void)connect:(CDVInvokedUrlCommand *)command;

@end
