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
    NSString *macId;
    STIDCardReader *scaleManager;
    NSMutableDictionary *IDCardInfo;
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
@synthesize linkedPeripheral;
@synthesize connectTimer= _connectTimer;

- (void)pluginInitialize{
    [super pluginInitialize];
    peripherals = [NSMutableSet new];
    IDCardInfo = [[NSMutableDictionary alloc] init];
    connectCallbacks = [NSMutableDictionary new];
    bluetoothStates = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"unknown", @(CBCentralManagerStateUnknown),
                       @"resetting", @(CBCentralManagerStateResetting),
                       @"unsupported", @(CBCentralManagerStateUnsupported),
                       @"unauthorized", @(CBCentralManagerStateUnauthorized),
                       @"off", @(CBCentralManagerStatePoweredOff),
                       @"on", @(CBCentralManagerStatePoweredOn),
                       nil];
    manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:@{CBCentralManagerOptionShowPowerAlertKey: @NO}];

    scaleManager = [STIDCardReader instance];

}

#pragma mark - Cordova PLugin Methods
- (void)getMessage:(CDVInvokedUrlCommand *)command{
    NSLog(@"getMessage:开始读卡啦！");
    // 设置IPServer
    if(UDValue(SERVER)== nil){
        SETUDValue(@"senter-online.cn", SERVER);
    }

    if(UDValue(PORT) == nil){
        SETUDValue(@"10002", PORT);
    }
    STIDCardReader *scaleManager;
    scaleManager = [STIDCardReader instance];
    scaleManager.delegate = (id)self;
    [scaleManager setServerIp:UDValue(SERVER) andPort:[UDValue(PORT) intValue]];

    getIDCardMessageCallbackId = [command.callbackId copy];
    // 获取参数
    macId = [command.arguments objectAtIndex:0];
    NSString* other = curConnectPeripheral.mac;
    BOOL isexit = NO;

    NSLog(@"myPeripherali other: %@, macId: %@", other, macId);

    if(curConnectPeripheral != nil){
        if([macId isEqualToString:other]){
            isexit = YES;
            if(self.linkedPeripheral == nil){
                NSLog(@"请先选中要连接的蓝牙设备!");
            }else{
                if(self.linkedPeripheral.peripheral.state != CBPeripheralStateConnected){
                    NSLog(@"蓝牙处于未连接状态,先连接蓝牙!");
                    [self connectPeripher:self.linkedPeripheral];
                }else{
                    NSLog(@"蓝牙处在连接状态,直接进行读卡的操作!");
                    [scaleManager setDelegate:(id)self];
                    [scaleManager startScaleCard];
                }
            }
        }
    }
}

//开始扫描
-(void)startScan:(CDVInvokedUrlCommand*)command {
    NSLog(@"开始扫描蓝牙");

    discoverPeripherialCallbackId = [command.callbackId copy];
    NSNumber *timeoutSeconds = [command.arguments objectAtIndex:0];

    //    [manager scanForPeripheralsWithServices:nil options:nil];
    [manager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey: [NSNumber numberWithBool:NO]}];

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

    if (discoverPeripherialCallbackId) {
        discoverPeripherialCallbackId = nil;
    }
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {

    [peripherals addObject:peripheral];
    //    [peripheral setAdvertisementData:advertisementData RSSI:RSSI];

    NSString *mac = [self macTrans:[advertisementData objectForKey:@"kCBAdvDataManufacturerData"]];
    NSLog(@"Did discover peripheral %@  mac is %@", peripheral.name,mac);
    STMyPeripheral *newMyPerip = [[STMyPeripheral alloc] initWithCBPeripheral:peripheral];
    newMyPerip.advName = peripheral.name;
    newMyPerip.mac = mac;
    [self didFindNewPeripheral:newMyPerip];

    if (discoverPeripherialCallbackId) {
        CDVPluginResult *pluginResult = nil;

        // 构建新的字典返回给ionic端
        NSDictionary *corodvaPerip = [newMyPerip.peripheral asDictionary];
        NSArray *arr = [corodvaPerip allKeys];
        NSMutableDictionary *corodvaNewPerip = [[NSMutableDictionary alloc] initWithObjectsAndKeys:newMyPerip.mac,@"id",nil];
        for (NSInteger i = 0; i < arr.count; i++) {
            if ([arr[i] isEqualToString:@"id"]) {
                [corodvaNewPerip setValue:[corodvaPerip objectForKey:arr[i]] forKey:@"uuid"];
            } else{
                [corodvaNewPerip setValue:[corodvaPerip objectForKey:arr[i]] forKey:arr[i]];
            }
            NSLog(@"%@ : %@", arr[i]  , [corodvaPerip objectForKey:arr[i]]);
        }

        NSLog(@"corodvaNewPerip %@", corodvaNewPerip);

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:corodvaNewPerip];
        [pluginResult setKeepCallbackAsBool:TRUE];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:discoverPeripherialCallbackId];
    }
}

//蓝牙扫描回保存到设备列表
- (void)didFindNewPeripheral:(STMyPeripheral *)periperal{

    if([periperal.mac isEqualToString:@""] || periperal.advName == nil) {
        return;
    }
    if(deviceList == nil){
        deviceList = [[NSMutableArray alloc] init];
    }
    if(deviceList != nil){
        if([deviceList count] == 0 ){
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
}

// 调用蓝牙连接
- (void)connect:(CDVInvokedUrlCommand *)command{
    NSLog(@"开始连接蓝牙");
    if (self.linkedPeripheral == nil &&self.linkedPeripheral.peripheral.state != CBPeripheralStateConnected){
        discoverPeripheralCallbackId = [command.callbackId copy];
        macId = [command.arguments objectAtIndex:0];
        STMyPeripheral *device_ = [self findPeripheralByID:macId];

        [self connectPeripher:device_];
    }
}

//开始蓝牙连接
-(void)connectPeripher:(STMyPeripheral *)peripheral{
    if(peripheral && self.curConnectPeripheral == nil){
        self.curConnectPeripheral = peripheral;
        self.linkedPeripheral = peripheral;
        [self.manager connectPeripheral:peripheral.peripheral options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey: [NSNumber numberWithBool:YES]}];

        //        self.connectTimer = [NSTimer scheduledTimerWithTimeInterval:20.0f target:self selector:@selector(connectTimeout:) userInfo:peripheral repeats:NO];
        //self.connectTimer = [NSTimer scheduledTimerWithTimeInterval:20.0f target:self selector:@selector(connectTimeout:) userInfo:nil repeats:NO];
    }
}


- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)aPeripheral{

    NSLog(@"蓝牙设备: %@ 已连接", aPeripheral.name);

    NSArray *uuids = [NSArray arrayWithObjects:[CBUUID UUIDWithString:UUIDSTR_DEVICE_INFO_SERVICE], [CBUUID UUIDWithString:UUIDSTR_ISSC_PROPRIETARY_SERVICE], nil];

    aPeripheral.delegate = (id)self;
    [aPeripheral discoverServices:uuids];
}

/*
 Invoked whenever an existing connection with the peripheral is torn down.
 Reset local variables
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error{

    if(self.curConnectPeripheral && self.curConnectPeripheral.peripheral == aPeripheral){

    }

}

#pragma mark - CBPeripheral delegate methods
/*
 Invoked upon completion of a -[discoverServices:] request.
 Discover available characteristics on interested services
 */
- (void) peripheral:(CBPeripheral *)aPeripheral didDiscoverServices:(NSError *)error{

    for (CBService *aService in aPeripheral.services){
        NSLog(@"找到Service: %@", aService.UUID);
        //查找蓝牙的特征值 （读写）
        [aPeripheral discoverCharacteristics:nil forService:aService];
    }
}

- (void) peripheral:(CBPeripheral *)aPeripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{

    if ([service.UUID isEqual:[CBUUID UUIDWithString:UUIDSTR_ISSC_PROPRIETARY_SERVICE]]) {

        for (CBCharacteristic *aChar in service.characteristics){
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:UUIDSTR_ISSC_TRANS_RX]]) {
                [self.curConnectPeripheral setTransparentDataWriteChar:aChar];

                NSLog(@"found TRANS_RX");

            }else if ([aChar.UUID isEqual:[CBUUID UUIDWithString:UUIDSTR_ISSC_TRANS_TX]]) {

                NSLog(@"found TRANS_TX");
                [self.curConnectPeripheral setTransparentDataReadChar:aChar];
            }
        }

        //连接成功
        if(self.curConnectPeripheral.transparentDataReadChar && self.curConnectPeripheral.transparentDataWriteChar){

            if(self.curConnectPeripheral && self.curConnectPeripheral.peripheral == aPeripheral){
                [self connectPeripher:self.curConnectPeripheral];
                [[STIDCardReader instance] setLisentPeripheral:self.curConnectPeripheral];          //设置SDK的监听蓝牙设备

                NSString *msg = [NSString stringWithFormat:@"已连接上 %@",curConnectPeripheral.advName];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:msg delegate:self cancelButtonTitle:@"确定" otherButtonTitles: nil];

                [alert show];
                if(self.connectTimer){
                    [self.connectTimer invalidate];//停止连接超时处理
                }

                if (discoverPeripheralCallbackId) {
                    CDVPluginResult *pluginResult = nil;
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[self.curConnectPeripheral.peripheral asDictionary]];
                    [pluginResult setKeepCallbackAsBool:TRUE];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:discoverPeripheralCallbackId];
                }
            }

        }
    }
}

/*
 Invoked whenever the central manager fails to create a connection with the peripheral.
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error{

    NSLog(@"连接蓝牙错误: %@ with error = %@", aPeripheral, [error localizedDescription]);

    if(self.curConnectPeripheral && self.curConnectPeripheral.peripheral == aPeripheral){
        NSString *msg = [NSString stringWithFormat:@"蓝牙连接失败: %@", aPeripheral.name];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:msg delegate:self cancelButtonTitle:@"确定" otherButtonTitles: nil];
        [alert show];
    }
}


- (void)stopScan{
    if(self.manager){
        [self.manager stopScan];
    }
}

- (void)connectTimeout:(STMyPeripheral *)peripher{
    NSError *error = [NSError errorWithDomain:@"蓝牙连接超时" code:-1 userInfo:nil];
    NSLog(@"蓝牙连接超时%@", error);
    NSString *msg = [NSString stringWithFormat:@"蓝牙连接超时"];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:msg delegate:self cancelButtonTitle:@"确定" otherButtonTitles: nil];
    [alert show];
}





- (void)disConnectPeripher:(STMyPeripheral *)peripheral{

    if(peripheral && peripheral.peripheral){
        [self.manager cancelPeripheralConnection: peripheral.peripheral];
    }

}


///蓝牙delegate
- (void) centralManagerDidUpdateState:(CBCentralManager *)central{
    NSString * state = nil;
    BOOL isOk = NO;
    switch ([self.manager state]){
        case CBCentralManagerStateUnsupported:
            state = @"设备未提供蓝牙服务.";
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"软件未打开蓝牙后台执行.";
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"蓝牙设备关闭状态.";
            break;
        case CBCentralManagerStatePoweredOn:
            state = @"设备已打开";
            isOk =  YES;
            break;
        case CBCentralManagerStateUnknown:
        default:
            state = @"未知错误.";
            break;

    }

    if(!isOk){
        NSLog(@"蓝牙不可用");
    }else{
        NSLog(@"蓝牙设备状态%@",state);
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


//连接设备的回调，成功 error为nil
- (void)connectperipher:(STMyPeripheral *)peripheral withError:(NSError *)error{
    if(error){
        NSString *errMsg = [NSString stringWithFormat:@"错误代码:%ld,错误信息:%@!", (long)[error code], [error localizedDescription]];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:errMsg delegate:nil cancelButtonTitle:@"确定" otherButtonTitles: nil];
        [alert show];

    }else{
        NSLog(@"已连接上 %@",peripheral.advName);
        [scaleManager setLisentPeripheral:peripheral];          //设置SDK的监听蓝牙设备
        //        lb_endtime = [self getTimeNow];
        NSString *msg = [NSString stringWithFormat:@"已连接上 %@",peripheral.advName];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:msg delegate:self cancelButtonTitle:@"确定" otherButtonTitles: nil];

        [alert show];

        //dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        //   [self leftNavBarClick:nil];
        //});

    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

    });
}

- (NSString*)getTimeNow{
    NSString* date;

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"YYYY-MM-dd hh:mm:ss:SSS"];
    date = [formatter stringFromDate:[NSDate date]];
    NSString * timeNow = [[NSString alloc] initWithFormat:@"%@", date];

    return timeNow;
}


- (void)disconnectDevice {

    NSLog(@"进入关闭蓝牙练级的方法");
    //取消超时处理
    if(self.connectTimer && [self.connectTimer isValid]){
        [self.connectTimer  invalidate];
        self.connectTimer = nil;
    }
    [self.manager cancelPeripheralConnection: self.curConnectPeripheral.peripheral];

}



#pragma ScaleDelegate
- (void)failedBack:(STMyPeripheral *)peripheral withError:(NSError *)error{
    if(error){
        NSString *errMsg = [NSString stringWithFormat:@"错误代码:%ld,错误信息:%@!", (long)[error code], [error localizedDescription]];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:errMsg delegate:nil cancelButtonTitle:@"确定" otherButtonTitles: nil];
        [alert show];

        //        if (getIDCardMessageCallbackId) {
        //            CDVPluginResult *pluginResult = nil;
        //            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageToErrorObject:error];
        //            [pluginResult setKeepCallbackAsBool:TRUE];
        //            [self.commandDelegate sendPluginResult:pluginResult callbackId:getIDCardMessageCallbackId];
        //        }
    }
}

- (void)successBack:(STMyPeripheral *)peripheral withData:(id)data{
    NSLog(@"==========>1 %@", IDCardInfo);
    if(data && [data isKindOfClass:[NSDictionary class]]){

        //--新增 flag == 49 说明是外国人永久居住身份证
        if([[data objectForKey:@"flag"]  isEqual: @"49"]){
            //-----外国人永久居留身份证----
        }else if ([[data objectForKey:@"flag"]  isEqual: @"4A"]){//通行证号码
        }else{
            [IDCardInfo addEntriesFromDictionary:data];
        }

    }else if (data &&[data isKindOfClass:[NSData class]]){
        UIImage *originImage = [UIImage imageWithData:data];
        NSData *data = UIImageJPEGRepresentation(originImage, 1.0f);
        NSString *encodedImageStr = [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
        [IDCardInfo setValue:encodedImageStr forKey:@"photo"];
    }

    NSLog(@"==========>2 %@", IDCardInfo);
    if (getIDCardMessageCallbackId && [IDCardInfo objectForKey: @"photo"]) {
        CDVPluginResult *pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:IDCardInfo];
        [pluginResult setKeepCallbackAsBool:TRUE];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:getIDCardMessageCallbackId];
    }

}

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
        NSString* other = myPeripherali.mac;
        NSLog(@"myPeripherali other %@", other);
        NSLog(@"myPeripherali id %@", id);
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
