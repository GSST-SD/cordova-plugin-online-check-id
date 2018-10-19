//
//  STIDCardReader.h
//  Blue
//
//  Created by tungkong on 15/8/7.
//  Copyright (c) 2015年 wanglu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "STMyPeripheral.h"

//IDReadCardInfo 这是一个类，告诉本类中通过IDReadCardInfo的指针来引用他
@class  IDReadCardInfo;

@protocol STIDCardReaderDelegate;
@interface STIDCardReader : NSObject<CBCentralManagerDelegate, CBPeripheralDelegate>
{
    
}

@property(nonatomic,assign) id delegate;
@property (nonatomic,retain)NSString *checkCode,*uuid,*timeTag,*signStr;

+(id)instance;

//设置服务器 地址 和端口
- (void)setServerIp:(NSString *)serVerIp andPort:(int)port;

//设置需要监听的蓝牙设备
//传入监听蓝牙设备  和 管理
- (BOOL)setLisentPeripheral:(STMyPeripheral *)periperalHandle;

///开始扫描卡片
- (void)startScaleCard;

/**
 * 获取设备的编号
 * 该方法不能单独使用，必须在读完卡之后再调用
 */
- (NSString *)getSerialNumber;

- (void)setKey:(NSString *)key;


//sim卡上电操作，成功为YES，失败为NO。已作废
-(BOOL)cardPowerOn;

/**
 *  发送卡操作指令，
 apdu：指令数据
 apdulen：指令数据长度
 response：返回数据
 reslen：返回数据长度
 处理成功返回0；
 处理失败返回-1；
 */
-(int)cardTransmit:(uint8_t*)apdu apdulen:(int)apdulen response:(uint8_t*)response reslen:(int*)reslen;

/**
 *发送卡操作的字符指令
 *apdu: 字符指令
 *处理成功返回0；
 *处理失败返回-1;
 */
-(void)transmitCard:(NSString *)apdu;

//sim卡下电操作。
-(void)cardPowerOff;
/**
 *  读取iccid
 *
 *  @param cardType 1代表2G 2代表3G 3 代表4G
 *
 *  @return IDReadCardIndo
 */
- (IDReadCardInfo *)readCardInfo:(NSString *)cardType;
/**
 *   *  获取电源系统信息
 *
 *  @param iccid    白卡卡号
 *  @param imsi     国际移动识别码
 
 *  @param number   手机号码
 *  @param cardType  1代表2G 2代表3G 3 代表4G
 *
 *  @return <#return value description#>
 */
- (NSString *)writeScaleCard:(NSString *)iccid imst:(NSString *)imsi number:(NSString *)number cardType:(NSString *)cardType;


/**
 //读取 ICCID,并判断是否是成白卡
 *
 *
 *  @return 返回SIM 信息   "iccid":"23333333","stype":"0"
 key为iccid 的value值为ICCID  key为stype的 value值为0（白卡）或 1（成卡）
 
 1 成卡
 */
-(void) readSimICCID;

/**
 * 读取sim卡的imsi的方法
 *
 */
-(void) readIMSINumber;

/**
 *  写白卡
 imsi  smsNo
 *
 *  @param imsi  国际移动用户识别码
 *  @param smsNo 短信中心号码
 *  @return <#return value description#>
 */
-(void) writeSimCard:(NSString*)imsi SMSNO:(NSString*) smsNo;

///获取设备信息
//- (id)getDeviceInfo;

// 移动写卡
// 统一写卡组件与客户端间接口
// int GetOPSVersion([out] char * version)
// int GetCardSN([out] char * CardSN)
// int GetCardInfo([out] char * CardInfo);
// int WriteCard([in] char * IssueData, [out] char *result];
// int GetOPSErrorMsg([out] int ErrorCode, [out] char *ErrorMsg);
// int ConfigReader([in] int ReaderType, [in] char * DeviceID, [in] char * Password);

// 获取sdk版本信息
- (NSString*)getOPSVersion;

// 读取空卡序列号
- (void)getCardSN;

// 读取卡片信息
- (void*)getCardInfo;

// 实时写卡数据写入
- (void)writeCardWithIssueData:(NSString*)issueData;


// 统一写卡组件与读卡器控制组件接口
// int OpenCardReader([in] int ReaderType, [in] char * DeviceID, [in] char *Password);
// int CardPowerOn([out] char *Atr);
// int SendApduCommand([in] int CmdInLength, [in] char * CommandIn, [out] int *CmdOutLength, [out] char * CommandOut);
// int CardPowerOff();
// int ColseCardReader();

// 连接读卡器
- (int)openCardReaderWithType:(int)readerType withDeviceID:(NSString*)deviceID andPwd:(NSString*)pwd;

// 发送APDU指令
- (void)sendApduCommand:(NSString*)apdu;

// 关闭读卡器
- (int)closeCardReader;

@end



@protocol STIDCardReaderDelegate

@optional

// 蓝牙相关
- (void)failedBack:(STMyPeripheral *)peripheral withError:(NSError *)error;

///如果是文本信息，Data 是NSDictionary  图片则返回NSData
- (void)successBack:(STMyPeripheral *)peripheral withData:(id)data;

//- (void)progressBack:(STMyPeripheral *)peripheral

// 读取身份证
/**
 *  程序获取到checkCode 或者SignStr 后自动调用
 *
 *  @param checkCode <#checkCode description#>
 *  @param signStr   <#signStr description#>
 */
- (void)getDataBack:(NSString *)checkCode SignStr:(NSString *)signStr;

/**
 *  联通读卡delegate
 *
 *  @param peripheral <#peripheral description#>
 *  @param data       ICCID
 stype   -1失败 0白卡 1 成卡
 */
- (void)ReadICCIDsuccessBack:(STIDReadCardInfo *)peripheral withData:(id)data;


- (void)writeCardResultBack:(STIDReadCardInfo*)peripheral withData:(id)data;

//- (void)readICCIDsuccessBack:(STMyPeripheral *)peripheral withData:(id)data andStype:(int )stype;

// 第一个isOK 是写信息中心状态  第二个是写ismi状态
//- (void)writeSMSNoBack:(BOOL)isOk withWriteIMSIStatus:(BOOL)isOK;

// 移动读卡
- (void)getCardSNBack:(STIDReadCardInfo*)peripheral withData:(id)data;

- (void)getCardInfoBack:(STIDReadCardInfo*)peripheral withData:(id)data;

- (void)transmitCardBack:(STIDReadCardInfo *)peripheral withData:(id)data;

- (void)writeCardBack:(STIDReadCardInfo *)peripheral withData:(id)data;

@end

@interface IDReadCardInfo : NSObject

@property (nonatomic,assign)int isWhiteCard;
@property (nonatomic,retain)NSString *retCode;
@property (nonatomic,retain)NSString *ICCID;
@property (nonatomic,retain)NSString *CARDTYPE;
@property (nonatomic,assign)int writeCardResult;
@property (nonatomic,assign)int messageResult;

@property (nonatomic, retain)NSString *sn;
@property (nonatomic, retain)NSString *iccid;

@end


