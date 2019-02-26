//
//  NetPing.h
//
//  Created by 赵磊 on 2018/12/3.
//  Copyright © 2018 leizhao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDSimplePing.h"


/*
 * @protocal NetPingDelegate监测Ping命令的的输出到日志变量；
 *
 */
@protocol NetPingDelegate <NSObject>
- (void)appendPingLog:(NSString *)pingLog;
- (void)netPingDidEnd;
@end


/*
 * @class NetPing ping监控
 * 主要是通过模拟shell命令ping的过程，监控目标主机是否连通
 * 连续执行五次，因为每次的速度不一致，可以观察其平均速度来判断网络情况
 */
@protocol SimplePingDelegate;
@interface NetPing : NSObject <SimplePingDelegate> {
}

@property (nonatomic, weak, readwrite) id<NetPingDelegate> delegate;

/**
 * 通过hostname 进行ping诊断
 */
- (void)runWithHostName:(NSString *)hostName normalPing:(BOOL)normalPing;

/**
 * 停止当前ping动作
 */
- (void)stopPing;

@end
