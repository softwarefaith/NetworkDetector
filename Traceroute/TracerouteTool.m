//
//  TracerouteTool.m
//
//  Created by 赵磊 on 2018/12/3.
//  Copyright © 2018 leizhao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AssertMacros.h>
#import "TracerouteTool.h"

// IPv4数据报结构
typedef struct IPv4Header {
    uint8_t versionAndHeaderLength; // 版本和首部长度
    uint8_t serviceType; // 服务类型
    uint16_t totalLength; // 数据包长度
    uint16_t identifier;
    uint16_t flagsAndFragmentOffset;
    uint8_t timeToLive;
    uint8_t protocol; // 协议类型，1表示ICMP: https://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml
    uint16_t checksum;
    uint8_t sourceAddress[4];
    uint8_t destAddress[4];
    // options...
    // data...
} IPv4Header;

// IPv6数据包结构
typedef struct IPv6Header {
    uint32_t padding; // 版本 + 通信量等级 + 流标签
    uint16_t payloadLength; // 有效载荷大小
    uint8_t nextHeader; // 表示类型，58为ICMPv6
    uint8_t hopLimit; // 跳限制
    uint8_t sourceAddress[16]; // 128位源地址
    uint8_t destAddress[16]; //128目标地址
    // data
} IPv6Header;

@implementation TracerouteTool

#pragma mark - Public

// 官方示例：https://developer.apple.com/library/content/samplecode/SimplePing/Introduction/Intro.html
+ (uint16_t)makeChecksumFor:(const void *)buffer len:(size_t)bufferLen {
    size_t bytesLeft;
    int32_t sum;
    const uint16_t *cursor;
    union {
        uint16_t us;
        uint8_t uc[2];
    } last;
    uint16_t answer;
    
    bytesLeft = bufferLen;
    sum = 0;
    cursor = buffer;
    
    /*
     * Our algorithm is simple, using a 32 bit accumulator (sum), we add
     * sequential 16 bit words to it, and at the end, fold back all the
     * carry bits from the top 16 bits into the lower 16 bits.
     */
    while (bytesLeft > 1) {
        sum += *cursor;
        cursor += 1;
        bytesLeft -= 2;
    }
    
    /* mop up an odd byte, if necessary */
    if (bytesLeft == 1) {
        last.uc[0] = *(const uint8_t *)cursor;
        last.uc[1] = 0;
        sum += last.us;
    }
    
    /* add back carry outs from top 16 bits to low 16 bits */
    sum = (sum >> 16) + (sum & 0xffff); /* add hi 16 to low 16 */
    sum += (sum >> 16); /* add carry */
    answer = (uint16_t)~sum; /* truncate to 16 bits */
    
    return answer;
}

+ (NSData *)makeICMPPacketWithID:(uint16_t)identifier
                        sequence:(uint16_t)seq
                        isICMPv6:(BOOL)isICMPv6 {
    NSMutableData *packet;
    ICMPPacket *icmpPtr;
    
    packet = [NSMutableData dataWithLength:sizeof(*icmpPtr)];
    
    icmpPtr = packet.mutableBytes;
    icmpPtr->type = isICMPv6 ? kICMPv6TypeEchoRequest : kICMPv4TypeEchoRequest;
    icmpPtr->code = 0;
    
    if (isICMPv6) {
        icmpPtr->identifier     = 0;
        icmpPtr->sequenceNumber = 0;
    } else {
        icmpPtr->identifier     = OSSwapHostToBigInt16(identifier);
        icmpPtr->sequenceNumber = OSSwapHostToBigInt16(seq);
    }
    
    // ICMPv6的校验和由内核计算
    if (!isICMPv6) {
        icmpPtr->checksum = 0;
        icmpPtr->checksum = [TracerouteTool makeChecksumFor:packet.bytes len:packet.length];
    }
    
    return packet;
}

+ (BOOL)isEchoReplyPacket:(char *)packet len:(int)len isIPv6:(BOOL)isIPv6 {
    ICMPPacket *icmpPacket = NULL;
    
    if (isIPv6) {
        icmpPacket = [TracerouteTool unpackICMPv6Packet:packet len:len];
        if (icmpPacket != NULL && icmpPacket->type == kICMPv6TypeEchoReply) {
            return YES;
        }
    } else {
        icmpPacket = [TracerouteTool unpackICMPv4Packet:packet len:len];
        if (icmpPacket != NULL && icmpPacket->type == kICMPv4TypeEchoReply) {
            return YES;
        }
    }
    
    return NO;
}

+ (BOOL)isTimeoutPacket:(char *)packet len:(int)len isIPv6:(BOOL)isIPv6 {
    ICMPPacket *icmpPacket = NULL;
    
    if (isIPv6) {
        icmpPacket = [TracerouteTool unpackICMPv6Packet:packet len:len];
        if (icmpPacket != NULL && icmpPacket->type == kICMPv6TypeTimeOut) {
            return YES;
        }
    } else {
        icmpPacket = [TracerouteTool unpackICMPv4Packet:packet len:len];
        if (icmpPacket != NULL && icmpPacket->type == kICMPv4TypeTimeOut) {
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - Helper

// 从IPv4数据包中解析出ICMP
+ (ICMPPacket *)unpackICMPv4Packet:(char *)packet len:(int)len {
    if (len < (sizeof(IPv4Header) + sizeof(ICMPPacket))) {
        return NULL;
    }
    const struct IPv4Header *ipPtr = (const IPv4Header *)packet;
    if ((ipPtr->versionAndHeaderLength & 0xF0) != 0x40 || // IPv4
        ipPtr->protocol != 1) { //ICMP
        return NULL;
    }
    
    size_t ipHeaderLength = (ipPtr->versionAndHeaderLength & 0x0F) * sizeof(uint32_t); // IPv4头部长度
    if (len < ipHeaderLength + sizeof(ICMPPacket)) {
        return NULL;
    }
    
    return (ICMPPacket *)((char *)packet + ipHeaderLength);
}

// 从IPv6数据包中解析出ICMP
+ (ICMPPacket *)unpackICMPv6Packet:(char *)packet len:(int)len {
   if (len < (sizeof(IPv6Header) + sizeof(ICMPPacket))) {
       return NULL;
   }
   const struct IPv6Header *ipPtr = (const IPv6Header *)packet;
   if (ipPtr->nextHeader != 58) { // ICMPv6
       return NULL;
   }

   size_t ipHeaderLength = sizeof(uint8_t) * 40; // IPv6头部长度为固定的40字节
   if (len < ipHeaderLength + sizeof(ICMPPacket)) {
       return NULL;
   }

   return (ICMPPacket *)((char *)packet + ipHeaderLength);
}

+ (NSString *)formatIPv6Address:(struct in6_addr)ipv6Addr {
    NSString *address = nil;
    
    char dstStr[INET6_ADDRSTRLEN];
    char srcStr[INET6_ADDRSTRLEN];
    memcpy(srcStr, &ipv6Addr, sizeof(struct in6_addr));
    if(inet_ntop(AF_INET6, srcStr, dstStr, INET6_ADDRSTRLEN) != NULL){
        address = [NSString stringWithUTF8String:dstStr];
    }
    
    return address;
}

+ (NSString *)formatIPv4Address:(struct in_addr)ipv4Addr {
    NSString *address = nil;
    
    char dstStr[INET_ADDRSTRLEN];
    char srcStr[INET_ADDRSTRLEN];
    memcpy(srcStr, &ipv4Addr, sizeof(struct in_addr));
    if(inet_ntop(AF_INET, srcStr, dstStr, INET_ADDRSTRLEN) != NULL) {
        address = [NSString stringWithUTF8String:dstStr];
    }
    
    return address;
}

@end
