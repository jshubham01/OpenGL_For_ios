#import "AppDelegate.h"
#import "ViewController.h"
#import "MyView.h"

@implementation AppDelegate
{
@private
    UIWindow *mainWindow;
    ViewController *mainViewController;
    MyView *myView;
}

- (BOOL)application:(UIApplication *)application applicationDidFinishLaunching:
(NSNotification *)aNotification
