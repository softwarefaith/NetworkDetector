//
//  NetTraceRouteICMP.h
//
//  Created by 赵磊 on 2018/12/3.
//  Copyright © 2018 leizhao. All rights reserved.
//

#import <Foundation/Foundation.h>

static const int TRACEROUTE_PORT = 20000;
static const int TRACEROUTE_MAX_TTL = 30;
static const int TRACEROUTE_ATTEMPTS = 3;
static const int TRACEROUTE_TIMEOUT = 5000000;

/*
 * @protocal 输出到日志；
 *
 */
@protocol NetTraceRouteDelegate <NSObject>
- (void)appendRouteLog:(NSString *)routeLog;
- (void)traceRouteDidEnd;
@end


/*
 * @ class NetTraceRoute TraceRoute网络监控
 * 通过模拟 shell 命令 traceRoute 的过程，监控网络站点间的跳转
 * 默认执行20转，每转进行三次发送测速
 */
@interface NetTraceRouteICMP : NSObject {
    int udpPort;      //执行端口
    int maxTTL;       //执行转数
    int readTimeout;  //每次发送时间的timeout
    int maxAttempts;  //每转的发送次数
    NSString *running;
    bool isrunning;
    NSString *ipAddr0;
}

@property (nonatomic, weak) id<NetTraceRouteDelegate> delegate;

/**
 * 初始化
 */
- (NetTraceRoute *)initWithMaxTTL:(int)ttl
                            timeout:(int)timeout
                        maxAttempts:(int)attempts
                               port:(int)port;

- (Boolean)doTraceRoute:(NSString *)host;

@end
