//
//  NetTraceRouteICMP.m
//  NetCheckServiceDemo
//
//  Created by 赵磊 on 2018/12/3.
//  Copyright © 2018 leizhao. All rights reserved.
//

#include <netdb.h>
#include <arpa/inet.h>
#include <sys/time.h>

#import "NetTimer.h"
#import "NetGetAddress.h"
#import "TracerouteCommon.h"

@implementation NetTraceRouteICMP

- (NetTraceRouteICMP *)initWithMaxTTL:(int)ttl
                            timeout:(int)timeout
                        maxAttempts:(int)attempts
                               port:(int)port
{
    self = [super init];
    if (self) {
        maxTTL = ttl;
        udpPort = port;
        readTimeout = timeout;
        maxAttempts = attempts;
    }

    return self;
}

// 执行 traceRoute
- (Boolean)doTraceRoute:(NSString *)host
{
    //从name server获取server主机的地址
    NSArray *serverDNSs = [NetGetAddress getDNSsWithDormain:host];
    if (!serverDNSs || serverDNSs.count <= 0) {
        if (_delegate != nil) {
            [_delegate appendRouteLog:@"TraceRoute>>> Could not get host address"];
            [_delegate traceRouteDidEnd];
        }
        return false;
    }
    
    ipAddr0 = [serverDNSs objectAtIndex:0];
    //设置server主机的套接口地址
    struct sockaddr *remoteAddr;
    BOOL isIPv6 = NO;
    if ([ipAddr0 rangeOfString:@":"].location == NSNotFound) {
        isIPv6 = NO;
        struct sockaddr_in nativeAddr4;
        memset(&nativeAddr4, 0, sizeof(nativeAddr4));
        nativeAddr4.sin_len = sizeof(nativeAddr4);
        nativeAddr4.sin_family = AF_INET;
        nativeAddr4.sin_port = htons(udpPort);
        inet_pton(AF_INET, ipAddr0.UTF8String, &nativeAddr4.sin_addr.s_addr);
        remoteAddr = (struct sockaddr *) [[NSData dataWithBytes:&nativeAddr4 length:sizeof(nativeAddr4)] bytes];
    } else {
        isIPv6 = YES;
        struct sockaddr_in6 nativeAddr6;
        memset(&nativeAddr6, 0, sizeof(nativeAddr6));
        nativeAddr6.sin6_len = sizeof(nativeAddr6);
        nativeAddr6.sin6_family = AF_INET6;
        nativeAddr6.sin6_port = htons(udpPort);
        inet_pton(AF_INET6, ipAddr0.UTF8String, &nativeAddr6.sin6_addr);
        remoteAddr = (struct sockaddr *) [[NSData dataWithBytes:&nativeAddr6 length:sizeof(nativeAddr6)] bytes];
    }
    
    if (remoteAddr == NULL) {
        return false;
    }
    
    // 创建套接字
    int send_sock;
    if ((send_sock = socket(remoteAddr->sa_family,
                            SOCK_DGRAM,
                            isIPv6 ? IPPROTO_ICMPV6 : IPPROTO_ICMP)) < 0) {
        if (_delegate != nil) {
            [_delegate appendRouteLog:@"TraceRoute>>> Could not create xmit socket"];
            [_delegate traceRouteDidEnd];
        }
        return false;
    }
    
    // 超时时间3秒
    struct timeval timeout;
    timeout.tv_sec = 3;
    timeout.tv_usec = 0;
    setsockopt(send_sock, SOL_SOCKET, SO_RCVTIMEO, (char *)&timeout, sizeof(timeout));
    
    int ttl = 1;
    BOOL succeed = NO;
    
    do {
        // 设置数据包TTL，依次递增
        if (setsockopt(send_sock,
                       isIPv6 ? IPPROTO_IPV6 : IPPROTO_IP,
                       isIPv6 ? IPV6_UNICAST_HOPS : IP_TTL,
                       &ttl,
                       sizeof(ttl)) < 0) {
            NSLog(@"setsockopt失败");
        }
        succeed = [self sendAndRecv:send_sock addr:remoteAddr ttl:ttl isIPv6:isIPv6];
    } while (++ttl <= maxTTL && !succeed);
    
    close(send_sock);

    [_delegate traceRouteDidEnd];
    return true;
}

/**
 向指定目标连续发送3个数据包
 
 @param sendSock 发送用的socket
 @param addr     地址
 @param ttl      TTL大小
 @return 如果找到目标服务器则返回YES，否则返回NO
 */
- (BOOL)sendAndRecv:(int)sendSock
               addr:(struct sockaddr *)addr
                ttl:(int)ttl
             isIPv6:(BOOL)isIPv6 {

    char buff[200];
    BOOL finished = NO;
    long startTime;
    long delta;
    socklen_t addrLen = isIPv6 ? sizeof(struct sockaddr_in6) : sizeof(struct sockaddr_in);
    
    // 构建icmp报文
    uint16_t identifier = (uint16_t)ttl;
    NSData *packetData = [TracerouteCommon makeICMPPacketWithID:identifier
                                                       sequence:ttl
                                                       isICMPv6:isIPv6];
    NSMutableString *traceTTLLog = [[NSMutableString alloc] initWithCapacity:20];
    
    // 连续发送3个ICMP报文，记录往返时长
    for (int try = 0; try < maxAttempts; try ++) {
        startTime = [NetTimer getMicroSeconds];
        // 发送icmp报文
        ssize_t sent = sendto(sendSock,
                              packetData.bytes,
                              packetData.length,
                              0,
                              addr,
                              addrLen);
        if (sent < 0) {
            NSLog(@"发送失败: %s", strerror(errno));
            if (try == 0) {
                [traceTTLLog appendString: [NSString stringWithFormat:@"%d\t********\t", ttl]];
            }
            [traceTTLLog appendFormat:@"-----ms\t"];
            continue;
        }
        
        // 接收icmp数据
        struct sockaddr remoteAddr;
        ssize_t resultLen = recvfrom(sendSock, buff, sizeof(buff), 0, (struct sockaddr*)&remoteAddr, &addrLen);
        if (resultLen < 0) {
            // fail
            if (try == 0) {
                [traceTTLLog appendString: [NSString stringWithFormat:@"%d\t********\t", ttl]];
            }
            [traceTTLLog appendFormat:@"-----ms\t"];
            continue;
        } else {
            delta = [NetTimer computeDurationSince:startTime];
            
            // 解析IP地址
            NSString* remoteAddress = nil;
            if (!isIPv6) {
                char ip[INET_ADDRSTRLEN] = {0};
                inet_ntop(AF_INET, &((struct sockaddr_in *)&remoteAddr)->sin_addr.s_addr, ip, sizeof(ip));
                remoteAddress = [NSString stringWithUTF8String:ip];
            } else {
                char ip[INET6_ADDRSTRLEN] = {0};
                inet_ntop(AF_INET6, &((struct sockaddr_in6 *)&remoteAddr)->sin6_addr, ip, INET6_ADDRSTRLEN);
                remoteAddress = [NSString stringWithUTF8String:ip];
            }
            
            // 结果判断
            if ([TracerouteCommon isTimeoutPacket:buff len:(int)resultLen isIPv6:isIPv6]) {
                // ICMP 超时：到达中间节点
                if (try == 0) {
                    [traceTTLLog appendFormat:@"%d\t%@\t\t", ttl, remoteAddress];
                }
                [traceTTLLog appendFormat:@"%0.2fms\t", (float)delta / 1000];
            } else if ([TracerouteCommon isEchoReplyPacket:buff len:(int)resultLen isIPv6:isIPv6] && [remoteAddress isEqualToString:ipAddr0]) {
                // ICMP 回显应答： 到达目标服务器
                if (try == 0) {
                    [traceTTLLog appendFormat:@"%d\t%@\t\t", ttl, remoteAddress];
                }
                [traceTTLLog appendFormat:@"%0.2fms\t", (float)delta / 1000];
                finished = YES;
            } else {
                // 失败
                if (try == 0) {
                    [traceTTLLog appendString: [NSString stringWithFormat:@"%d\t********\t", ttl]];
                }
                [traceTTLLog appendFormat:@"-----ms\t"];
            }
        }
    }
    
    [self.delegate appendRouteLog:traceTTLLog];
    
    return finished;
}

@end
