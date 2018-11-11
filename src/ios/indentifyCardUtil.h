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
    
    NSString* discoverPeripherialCallbackId;
    NSString* discoverPeripheralCallbackId;
    NSString* getIDCardMessageCallbackId;
    NSMutableDictionary* connectCallbacks;
    NSMutableDictionary *readRSSICallbacks;
    NSMutableDictionary* getIDCardMessageCallbacks;
    
}

@property (strong, nonatomic) NSMutableSet *peripherals;
@property (strong, nonatomic) CBCentralManager *manager;
@property (nonatomic,retain) STMyPeripheral *linkedPeripheral;

//读卡操作
- (void)getMessage:(CDVInvokedUrlCommand *)command;
//开始扫描
- (void)startScan:(CDVInvokedUrlCommand *)command;
- (void)stopScan;
//蓝牙连接
- (void)connect:(CDVInvokedUrlCommand *)command;
- (void)connectPeripher:(STMyPeripheral *)peripheral;
- (void)disConnectPeripher:(STMyPeripheral *)peripheral;

@end

@protocol BlueManagerDelegate <NSObject>
//蓝牙扫描回调
- (void)didFindNewPeripheral:(STMyPeripheral *)periperal;

@end
