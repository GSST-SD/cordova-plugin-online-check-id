//
//  indentifyCardUtil.m
//  STIDCardDemoApp
//
//  Created by star diao on 2018/9/4.
//

#import "indentifyCardUtil.h"
#import <Cordova/CDV.h>


//Device Info service
#define UUIDSTR_DEVICE_INFO_SERVICE             @"180A"
#define UUIDSTR_MANUFACTURE_NAME_CHAR           @"2A29"
#define UUIDSTR_MODEL_NUMBER_CHAR               @"2A24"
#define UUIDSTR_SERIAL_NUMBER_CHAR              @"2A25"
#define UUIDSTR_HARDWARE_REVISION_CHAR          @"2A27"
#define UUIDSTR_FIRMWARE_REVISION_CHAR          @"2A26"
#define UUIDSTR_SOFTWARE_REVISION_CHAR          @"2A28"
#define UUIDSTR_SYSTEM_ID_CHAR                  @"2A23"

#define UUIDSTR_ISSC_PROPRIETARY_SERVICE        @"49535343-FE7D-4AE5-8FA9-9FAFD205E455"
#define UUIDSTR_CONNECTION_PARAMETER_CHAR       @"49535343-6DAA-4D02-ABF6-19569ACA69FE"
#define UUIDSTR_AIR_PATCH_CHAR                  @"49535343-ACA3-481C-91EC-D85E28A60318"
#define UUIDSTR_ISSC_TRANS_TX                   @"49535343-1E4D-4BD9-BA61-23C647249616"
#define UUIDSTR_ISSC_TRANS_RX                   @"49535343-8841-43F4-A8D4-ECBE34729BB3"

//CBCentralManagerOptionRestoreIdentifierKey
#define ISSC_RestoreIdentifierKey               @"ISSC_RestoreIdentifierKey"


//#define ERROR
#define UDValue(key) [[NSUserDefaults standardUserDefaults]objectForKey:key]
#define SETUDValue(value,key) [[NSUserDefaults standardUserDefaults] setObject:value forKey:key]

#define SERVER @"SERVERIP"  //@"192.168.1.10"//@"222.134.70.138" //
#define PORT @"SERVERPORT" //10002//8088 //

@interface indentifyCardUtil() {
    NSDictionary *bluetoothStates;
    NSMutableArray *deviceList;
}
- (CBPeripheral *)findPeripheralByUUID:(NSString *)uuid;
- (STMyPeripheral*)findPeripheralByID:(NSString*)id;
- (void)stopScanTimer:(NSTimer *)timer;
@property (nonatomic,retain)NSTimer *connectTimer;
@property (nonatomic,retain)STMyPeripheral *curConnectPeripheral;
@end

@implementation indentifyCardUtil

@synthesize manager;
@synthesize peripherals;
@synthesize curConnectPeripheral;
@synthesize connectTimer= _connectTimer;

- (void)pluginInitialize{
    [super pluginInitialize];
    
    peripherals = [NSMutableSet new];
    connectCallbacks = [NSMutableDictionary new];
    connectCallbackLatches = [NSMutableDictionary new];
    stopNotificationCallbacks = [NSMutableDictionary new];
    bluetoothStates = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"unknown", @(CBCentralManagerStateUnknown),
                       @"resetting", @(CBCentralManagerStateResetting),
                       @"unsupported", @(CBCentralManagerStateUnsupported),
                       @"unauthorized", @(CBCentralManagerStateUnauthorized),
                       @"off", @(CBCentralManagerStatePoweredOff),
                       @"on", @(CBCentralManagerStatePoweredOn),
                       nil];
    getIDCardMessageCallbacks = [NSMutableDictionary new];
    manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:@{CBCentralManagerOptionShowPowerAlertKey: @NO}];
    
    /**
     *  Description
     */
    if(UDValue(SERVER)== nil){
        SETUDValue(@"senter-online.cns", SERVER);
    }
    
    if(UDValue(PORT) == nil){
        SETUDValue(@"10002", PORT);
    }
    
    scaleManager = [STIDCardReader instance];
    scaleManager.delegate = (id)self;
    [scaleManager setServerIp:UDValue(SERVER) andPort:[UDValue(PORT) intValue]];
    
    if(UDValue(@"sdkKey")){
        [scaleManager setKey:UDValue(@"sdkKey")];
    }
    
}

- (void)startScan:(CDVInvokedUrlCommand *)command{
    NSLog(@"scan");
    discoverPeripheralCallbackId = [command.callbackId copy];
    
    //    NSArray<NSString *> *serviceUUIDStrings = [command argumentAtIndex:0];
    NSNumber *timeoutSeconds = [NSNumber numberWithInt:5];
    
    [manager scanForPeripheralsWithServices:nil options:nil];
    
    [NSTimer scheduledTimerWithTimeInterval:[timeoutSeconds floatValue]
                                     target:self
                                   selector:@selector(stopScanTimer:)
                                   userInfo:[command.callbackId copy]
                                    repeats:NO];
}

#pragma mark - timers
-(void)stopScanTimer:(NSTimer *)timer {
    NSLog(@"stopScanTimer");
    [manager stopScan];
    
    if (discoverPeripheralCallbackId) {
        discoverPeripheralCallbackId = nil;
    }
}


// TODO add timeout
- (void)connect:(CDVInvokedUrlCommand *)command {
    NSLog(@"connect");
    //    NSString *uuid = [command argumentAtIndex:0];
    NSString *uuid = @"88:1B:99:0E:C9:5F";
    
    STMyPeripheral *peripheral = [self findPeripheralByID:uuid];
    self.curConnectPeripheral = peripheral;
    self.linkedPeripheral = peripheral;
    
    if(peripheral){
        [connectCallbacks setObject:[command.callbackId copy] forKey:[peripheral.peripheral uuidAsString]];
        [manager connectPeripheral:peripheral.peripheral options:nil];
        
        [scaleManager setLisentPeripheral:peripheral];
        
    }else {
        NSString *error = [NSString stringWithFormat:@"Could not find peripheral %@.", uuid];
        NSLog(@"%@", error);
        CDVPluginResult *pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

//蓝牙扫描回调
- (void)didFindNewPeripheral:(STMyPeripheral *)periperal{
    if([periperal.mac isEqualToString:@""] || periperal.advName == nil) {
        
        return;
    }
    if(deviceList == nil){
        deviceList = [[NSMutableArray alloc] init];
    }
    if(deviceList != nil){
        if([deviceList count] == 0){
            [deviceList addObject:periperal];
        }else{
            BOOL isexit = NO;
            for (uint8_t i = 0; i < [deviceList count]; i++) {
                STMyPeripheral *myPeripherali = [deviceList objectAtIndex:i];
                if(myPeripherali != nil){
                    if([periperal.advName isEqualToString:myPeripherali.advName] && [periperal.mac isEqualToString:myPeripherali.mac]){
                        isexit = YES;
                        break;
                    }
                }
            }
            if(!isexit){
                [deviceList addObject:periperal];
            }
        }
    }
    NSLog(@"deviceList %@", deviceList);
    
}


#pragma mark - Cordova PLugin Methods
- (void)getMessage:(CDVInvokedUrlCommand *)command{
    NSLog(@"getMessage");
    manager.delegate = (id)self;
    if(self.linkedPeripheral == nil){
        NSLog(@"请先选中要连接的蓝牙设备!");
    }else{
        if(self.linkedPeripheral.peripheral.state != CBPeripheralStateConnected){
            NSLog(@"蓝牙处于未连接状态,先连接蓝牙!");
            //            [[BlueManager instance] connectPeripher:bmanager.linkedPeripheral];
        }else{
            NSLog(@"蓝牙处在连接状态,直接进行读卡的操作!");
            //            [scaleManager setDelegate:(id)self];
            scaleManager.delegate = (id)self;
            [scaleManager startScaleCard];
        }
    }
}

#pragma ScaleDelegate
- (void)failedBack:(STMyPeripheral *)peripheral withError:(NSError *)error{
    if(error){
        NSString *errMsg = [NSString stringWithFormat:@"错误代码:%ld,错误信息:%@!", (long)[error code], [error localizedDescription]];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:errMsg delegate:nil cancelButtonTitle:@"确定" otherButtonTitles: nil];
        [alert show];
    }
}

- (void)successBack:(STMyPeripheral *)peripheral withData:(id)data{
    
    if(data && [data isKindOfClass:[NSDictionary class]]){
        
        //--新增 flag == 49 说明是外国人永久居住身份证
        if([[data objectForKey:@"flag"]  isEqual: @"49"]){
            //-----外国人永久居留身份证----
            //[lb_name setText:[data objectForKey:@"EnglishName"]];       //英文名字
            //[lb_name setText:[data objectForKey:@"chinaname"]];         //中文名字
            
            //            NSString *allname = [NSString stringWithFormat:@"%@-%@",[data objectForKey:@"EnglishName"],[data objectForKey:@"chinaname"]];
            
        }
        
        //        NSString *date = [NSString stringWithFormat:@"%@-%@",[data objectForKey:@"EffectedDate"],[data objectForKey:@"ExpiredDate"]];
        
        //bu_readcard.userInteractionEnabled = YES;
        //bu_readcard.alpha = 1.0;
        
        NSString *devnum = [[STIDCardReader instance] getSerialNumber];
        NSLog(@"获取到的设备的序列号: %@",devnum);
        
    }else if (data &&[data isKindOfClass:[NSData class]]){
        
        //        UIImage *img = [UIImage imageWithData:data];
        NSLog(@"读卡成功!");
    }
    
}

- (NSString *)macTrans:(NSData *)data{
    NSString *result = nil;
    if(data){
        NSString *mStr = [data description];
        mStr = [mStr stringByReplacingOccurrencesOfString:@" " withString:@""];
        mStr = [mStr stringByReplacingOccurrencesOfString:@">" withString:@""];
        mStr = [mStr stringByReplacingOccurrencesOfString:@"<" withString:@""];
        
        NSMutableArray *macArray = [NSMutableArray array];
        
        for(int i= 4;i<mStr.length;i +=2){
            [macArray addObject:[mStr substringWithRange:NSMakeRange(i, 2)]];
            
        }
        result = [[macArray componentsJoinedByString:@":"] uppercaseString];
    }
    
    return result ==nil?@"":result;
}

#pragma mark - CBCentralManagerDelegate
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    
    //    [peripherals addObject:peripheral];
    [peripheral setAdvertisementData:advertisementData RSSI:RSSI];
    
    NSString *mac = [self macTrans:[advertisementData objectForKey:@"kCBAdvDataManufacturerData"]];
    NSLog(@"Did discover peripheral %@  mac is %@", peripheral.name,mac);
    STMyPeripheral *newMyPerip = [[STMyPeripheral alloc] initWithCBPeripheral:peripheral];
    newMyPerip.advName = peripheral.name;
    newMyPerip.mac = mac;
    
    [self didFindNewPeripheral:newMyPerip];
    
    if (discoverPeripheralCallbackId) {
        CDVPluginResult *pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[peripheral asDictionary]];
        NSLog(@"Discovered %@", peripheral);
        [pluginResult setKeepCallbackAsBool:TRUE];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:discoverPeripheralCallbackId];
    }
    
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"Status of CoreBluetooth central manager changed %ld %@", (long)central.state, [self centralManagerStateToString: central.state]);
    
    if (central.state == CBCentralManagerStateUnsupported)
    {
        NSLog(@"=============================================================");
        NSLog(@"WARNING: This hardware does not support Bluetooth Low Energy.");
        NSLog(@"=============================================================");
    }
    
    if (stateCallbackId != nil) {
        CDVPluginResult *pluginResult = nil;
        NSString *state = [bluetoothStates objectForKey:@(central.state)];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:state];
        [pluginResult setKeepCallbackAsBool:TRUE];
        NSLog(@"Report Bluetooth state \"%@\" on callback %@", state, stateCallbackId);
        [self.commandDelegate sendPluginResult:pluginResult callbackId:stateCallbackId];
    }
    
    // check and handle disconnected peripherals
    for (CBPeripheral *peripheral in peripherals) {
        if (peripheral.state == CBPeripheralStateDisconnected) {
            [self centralManager:central didDisconnectPeripheral:peripheral error:nil];
        }
    }
}

- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)aPeripheral{
    
    NSLog(@"蓝牙设备: %@ 已连接", aPeripheral.name);
    aPeripheral.delegate = self;
    
    // NOTE: it's inefficient to discover all services
    [aPeripheral discoverServices:nil];
    
    // NOTE: not calling connect success until characteristics are discovered
    
    //    if(self.connectTimer){
    //        [self.connectTimer invalidate];//停止连接超时处理
    //    }
    
    //    NSArray *uuids = [NSArray arrayWithObjects:[CBUUID UUIDWithString:UUIDSTR_DEVICE_INFO_SERVICE], [CBUUID UUIDWithString:UUIDSTR_ISSC_PROPRIETARY_SERVICE], nil];
    //
    //    aPeripheral.delegate = (id)self;
    //    [aPeripheral discoverServices:uuids];
}


- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"didDisconnectPeripheral");
    
    NSString *connectCallbackId = [connectCallbacks valueForKey:[peripheral uuidAsString]];
    [connectCallbacks removeObjectForKey:[peripheral uuidAsString]];
    [self cleanupOperationCallbacks:peripheral withResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Peripheral disconnected"]];
    
    if (connectCallbackId) {
        
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[peripheral asDictionary]];
        
        // add error info
        [dict setObject:@"Peripheral Disconnected" forKey:@"errorMessage"];
        if (error) {
            [dict setObject:[error localizedDescription] forKey:@"errorDescription"];
        }
        // remove extra junk
        [dict removeObjectForKey:@"rssi"];
        [dict removeObjectForKey:@"advertising"];
        [dict removeObjectForKey:@"services"];
        
        CDVPluginResult *pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dict];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:connectCallbackId];
    }
}



- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"didFailToConnectPeripheral");
    
    NSString *connectCallbackId = [connectCallbacks valueForKey:[peripheral uuidAsString]];
    [connectCallbacks removeObjectForKey:[peripheral uuidAsString]];
    [self cleanupOperationCallbacks:peripheral withResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Peripheral disconnected"]];
    
    CDVPluginResult *pluginResult = nil;
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:[peripheral asDictionary]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:connectCallbackId];
}

#pragma mark CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    NSLog(@"didDiscoverServices");
    
    // save the services to tell when all characteristics have been discovered
    NSMutableSet *servicesForPeriperal = [NSMutableSet new];
    [servicesForPeriperal addObjectsFromArray:peripheral.services];
    [connectCallbackLatches setObject:servicesForPeriperal forKey:[peripheral uuidAsString]];
    
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:service]; // discover all is slow
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    NSLog(@"didDiscoverCharacteristicsForService");
    
    NSString *peripheralUUIDString = [peripheral uuidAsString];
    NSString *connectCallbackId = [connectCallbacks valueForKey:peripheralUUIDString];
    NSMutableSet *latch = [connectCallbackLatches valueForKey:peripheralUUIDString];
    
    [latch removeObject:service];
    
    if ([latch count] == 0) {
        // Call success callback for connect
        if (connectCallbackId) {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[peripheral asDictionary]];
            [pluginResult setKeepCallbackAsBool:TRUE];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:connectCallbackId];
        }
        [connectCallbackLatches removeObjectForKey:peripheralUUIDString];
    }
    
    NSLog(@"Found characteristics for service %@", service);
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"Characteristic %@", characteristic);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSLog(@"didUpdateValueForCharacteristic");
    NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
}





- (void)peripheral:(CBPeripheral*)peripheral didReadRSSI:(NSNumber*)rssi error:(NSError*)error {
    NSLog(@"didReadRSSI %@", rssi);
    NSString *key = [peripheral uuidAsString];
    NSString *readRSSICallbackId = [readRSSICallbacks objectForKey: key];
    [peripheral setSavedRSSI:rssi];
    if (readRSSICallbackId) {
        CDVPluginResult* pluginResult = nil;
        if (error) {
            NSLog(@"%@", error);
            pluginResult = [CDVPluginResult
                            resultWithStatus:CDVCommandStatus_ERROR
                            messageAsString:[error localizedDescription]];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                messageAsInt: (int) [rssi integerValue]];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId: readRSSICallbackId];
        [readRSSICallbacks removeObjectForKey:readRSSICallbackId];
    }
}

#pragma mark - internal implemetation

#pragma mark - internal implemetation

- (CBPeripheral*)findPeripheralByUUID:(NSString*)uuid {
    CBPeripheral *peripheral = nil;
    
    for (CBPeripheral *p in peripherals) {
        
        NSString* other = p.identifier.UUIDString;
        
        if ([uuid isEqualToString:other]) {
            peripheral = p;
            break;
        }
    }
    return peripheral;
}

- (STMyPeripheral*)findPeripheralByID:(NSString*)id {
    BOOL isexit = NO;
    for (uint8_t i = 0; i < [deviceList count]; i++) {
        STMyPeripheral *myPeripherali = [deviceList objectAtIndex:i];
        //        NSLog(@"identifier %@", myPeripherali.peripheral.identifier);
        NSString* other = myPeripherali.mac;
        if(myPeripherali != nil){
            if([id isEqualToString:other]){
                isexit = YES;
                return  myPeripherali;
                break;
            }
        }
    }
    return nil;
}

// RedBearLab
-(CBService *) findServiceFromUUID:(CBUUID *)UUID p:(CBPeripheral *)p {
    for(int i = 0; i < p.services.count; i++) {
        CBService *s = [p.services objectAtIndex:i];
        if ([self compareCBUUID:s.UUID UUID2:UUID])
            return s;
    }
    
    return nil; //Service not found on this peripheral
}

// Find a characteristic in service with a specific property
-(CBCharacteristic *) findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service prop:(CBCharacteristicProperties)prop {
    NSLog(@"Looking for %@ with properties %lu", UUID, (unsigned long)prop);
    for(int i=0; i < service.characteristics.count; i++)
    {
        CBCharacteristic *c = [service.characteristics objectAtIndex:i];
        if ((c.properties & prop) != 0x0 && [c.UUID.UUIDString isEqualToString: UUID.UUIDString]) {
            return c;
        }
    }
    return nil; //Characteristic with prop not found on this service
}

// Find a characteristic in service by UUID
-(CBCharacteristic *) findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service {
    NSLog(@"Looking for %@", UUID);
    for(int i=0; i < service.characteristics.count; i++)
    {
        CBCharacteristic *c = [service.characteristics objectAtIndex:i];
        if ([c.UUID.UUIDString isEqualToString: UUID.UUIDString]) {
            return c;
        }
    }
    return nil; //Characteristic not found on this service
}

// RedBearLab
-(int) compareCBUUID:(CBUUID *) UUID1 UUID2:(CBUUID *)UUID2 {
    char b1[16];
    char b2[16];
    [UUID1.data getBytes:b1 length:16];
    [UUID2.data getBytes:b2 length:16];
    
    if (memcmp(b1, b2, UUID1.data.length) == 0)
        return 1;
    else
        return 0;
}

-(NSString *) keyForPeripheral: (CBPeripheral *)peripheral andCharacteristic:(CBCharacteristic *)characteristic {
    return [NSString stringWithFormat:@"%@|%@|%@", [peripheral uuidAsString], [characteristic.service UUID], [characteristic UUID]];
}

+(BOOL) isKey: (NSString *)key forPeripheral:(CBPeripheral *)peripheral {
    NSArray *keyArray = [key componentsSeparatedByString: @"|"];
    return [[peripheral uuidAsString] compare:keyArray[0]] == NSOrderedSame;
}

-(void) cleanupOperationCallbacks: (CBPeripheral *)peripheral withResult:(CDVPluginResult *) result {
    
}

#pragma mark - util

- (NSString*) centralManagerStateToString: (int)state {
    switch(state)
    {
        case CBCentralManagerStateUnknown:
            return @"State unknown (CBCentralManagerStateUnknown)";
        case CBCentralManagerStateResetting:
            return @"State resetting (CBCentralManagerStateUnknown)";
        case CBCentralManagerStateUnsupported:
            return @"State BLE unsupported (CBCentralManagerStateResetting)";
        case CBCentralManagerStateUnauthorized:
            return @"State unauthorized (CBCentralManagerStateUnauthorized)";
        case CBCentralManagerStatePoweredOff:
            return @"State BLE powered off (CBCentralManagerStatePoweredOff)";
        case CBCentralManagerStatePoweredOn:
            return @"State powered up and ready (CBCentralManagerStatePoweredOn)";
        default:
            return @"State unknown";
    }
    
    return @"Unknown state";
}

- (NSArray<CBUUID *> *) uuidStringsToCBUUIDs: (NSArray<NSString *> *)uuidStrings {
    NSMutableArray *uuids = [NSMutableArray new];
    for (int i = 0; i < [uuidStrings count]; i++) {
        CBUUID *uuid = [CBUUID UUIDWithString:[uuidStrings objectAtIndex: i]];
        [uuids addObject:uuid];
    }
    return uuids;
}

- (NSArray<NSUUID *> *) uuidStringsToNSUUIDs: (NSArray<NSString *> *)uuidStrings {
    NSMutableArray *uuids = [NSMutableArray new];
    for (int i = 0; i < [uuidStrings count]; i++) {
        NSUUID *uuid = [[NSUUID alloc]initWithUUIDString:[uuidStrings objectAtIndex: i]];
        [uuids addObject:uuid];
    }
    return uuids;
}


@end
