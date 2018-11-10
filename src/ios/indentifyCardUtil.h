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

}

@property (strong, nonatomic) NSMutableSet *peripherals;
@property (strong, nonatomic) CBCentralManager *manager;
@property (nonatomic,retain) STMyPeripheral *linkedPeripheral;

- (void)getMessage:(CDVInvokedUrlCommand *)command;
//开始扫描
- (void)startScan;
- (void)stopScan;

- (void)connectPeripher:(STMyPeripheral *)peripheral;
- (void)disConnectPeripher:(STMyPeripheral *)peripheral;

@end


@protocol BlueManagerDelegate <NSObject>
//蓝牙扫描回调
- (void)didFindNewPeripheral:(STMyPeripheral *)periperal;

//连接设备的回调，成功 error为nil
//- (void)connectperipher:(STMyPeripheral *)peripheral withError:(NSError *)error;

@end
