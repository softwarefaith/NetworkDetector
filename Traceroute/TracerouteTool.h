//
//  TracerouteTool.h
//
//  Created by 赵磊 on 2018/12/3.
//  Copyright © 2018 leizhao. All rights reserved.
//

#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <arpa/inet.h>

// ICMP数据报结构
typedef struct ICMPPacket {
    uint8_t     type;
    uint8_t     code;
    uint16_t    checksum;
    uint16_t    identifier;
    uint16_t    sequenceNumber;
    // data...
} ICMPPacket;

// ICMPv4报文类型
typedef enum ICMPv4Type {
    kICMPv4TypeEchoReply = 0, // 回显应答
    kICMPv4TypeEchoRequest = 8, // 回显请求
    kICMPv4TypeTimeOut = 11, // 超时
}ICMPv4Type;

// ICMPv6报文类型
typedef enum ICMPv6Type {
    kICMPv6TypeEchoReply = 129, // 回显应答
    kICMPv6TypeEchoRequest = 128, // 回显请求
    kICMPv6TypeTimeOut = 3, // 超时
}ICMPv6Type;

#pragma mark - TracerouteTool

@interface TracerouteTool : NSObject

/**
 计算ICMP数据包的校验码

 @param buffer    数据包的内容
 @param bufferLen 数据包长度
 @return 校验码
 */
+ (uint16_t)makeChecksumFor:(const void *)buffer len:(size_t)bufferLen;


/**
 创建一个ICMP数据包

 @param identifier ID
 @param seq        序号
 @param isICMPv6   是否为ICMPv6
 @return 返回创建的数据包，NSData类型
 */
+ (NSData *)makeICMPPacketWithID:(uint16_t)identifier
                        sequence:(uint16_t)seq
                        isICMPv6:(BOOL)isICMPv6;

/**
 判断是否为ICMP应答回显数据包

 @param packet IP数据包
 @param len    数据包长度
 @param isIPv6 是否为IPv6
 @return 是否收到回显应答
 */
+ (BOOL)isEchoReplyPacket:(char *)packet len:(int)len isIPv6:(BOOL)isIPv6;

/**
 判断数据包是否为ICMP超时数据包

 @param packet  IP数据包
 @param len     长度
 @param isIPv6  是否为IPv6
 @return 是否为超时
 */
+ (BOOL)isTimeoutPacket:(char *)packet len:(int)len isIPv6:(BOOL)isIPv6;

@end
