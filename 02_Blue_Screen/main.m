//
//  main.m
//  Window
//
//  Created by Shubham_at_astromedicomp on 12/21/19.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

int main(int argc, char * argv[]) {
    int ret;

    NSString * appDelegateClassName;
    
    NSAutoreleasePool *pPool = [[NSAutoreleasePool alloc]init];
    
    appDelegateClassName = NSStringFromClass([AppDelegate class]);
    ret = UIApplicationMain(argc, argv, nil, appDelegateClassName);
    
    [pPool release];
    return ret;
}
