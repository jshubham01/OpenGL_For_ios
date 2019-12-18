//
//  MyView.m
//  Window
//
//  Created by shubham_at_astromedicomp on 18/12/19.
//

#import "MyView.h"

@implementation MyView
{
    NSString *centralText;
}

- (id)initWithFrame:(CGRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if(self)
    {
        // Initialization code here

        [self setBackgroundColor: [UIColor whiteColor]];

        centralText = @"Hello World !!!";

        UITapGestureRecognizer *singleTapGestureRecognizer=
          [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector
            (onSingleTap:)];

        [singleTapGestureRecognizer setNumberOfTapsRequired:1];
        [singleTapGestureRecognizer setNumberOfTouchesRequired:1];
        [singleTapGestureRecognizer setDelegate:self];
        [self addGestureRecognizer:singleTapGestureRecognizer];

        UITapGestureRecognizer *doubleTapGestureRecognizer=
          [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector
            (onDoubleTap:)];

        [doubleTapGestureRecognizer setNumberOfTapsRequired:2];
        [doubleTapGestureRecognizer setNumberOfTouchesRequired:1];

        [doubleTapGestureRecognizer setDelegate:self];
        [self addGestureRecognizer:doubleTapGestureRecognizer];

        [singleTapGestureRecognizer requireGestureRecognizerToFail:doubleTapGestureRecognizer];

        UISwipeGestureRecognizer *swipeGestureRecognizer
          = [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(onSwipe:)];

        [self addGestureRecognizer:swipeGestureRecognizer];

        // long-press gesture
        UILongPressGestureRecognizer *longPressGestureRecognizer =
          [[UILongPressGestureRecognizer alloc]initWithTarget:self
          action:@selector(onLongPress:)];

        [self addGestureRecognizer:longPressGestureRecognizer];
    }

    return(self);
}

- (void)drawRect:(CGRect)rect
{
    // black background
    UIColor *fillColor = [UIColor blackColor];
    [fillColor set];
    UIRectFill(rect);

    // dictionary with kvc
    NSDictionary *dictionaryForTextAttributes = [NSDictionary
              dictionaryWithObjectsAndKeys:
                              [UIFont fontWithName:@"Helvetica"
                size:24], NSFontAttributeName,
                              [UIColor greenColor],
                NSForegroundColorAttributeName,
                    nil];

    CGSize textSize = [centralText sizeWithAttributes:dictionaryForTextAttributes];

    CGPoint point;
    point.x = (rect.size.width/2)-(textSize.width/2);
    point.y = (rect.size.height/2)-(textSize.height/2) + 12;

    [centralText drawAtPoint:point withAttributes:dictionaryForTextAttributes];
}


-(BOOL)acceptsFirstResponder
{
    // code
    return(YES);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{

}

- (void)onSingleTap:(UITapGestureRecognizer *)gr
{
    // code
    centralText = @"'onSingleTap' Event Occured";
    [self setNeedsDisplay]; // repainting
}

- (void)onDoubleTap:(UITapGestureRecognizer *)gr
{
    // code
    centralText = @"'onDoubleTap' Event Occured";
    [self setNeedsDisplay]; // repainting
}

- (void)onSwipe:(UISwipeGestureRecognizer *)gr
{
    // code
    [self release];
    exit(0);
}

- (void)onLongPress:(UILongPressGestureRecognizer *)gr
{
    // code
    centralText = @"'onLongPress' Event Occured";
    [self setNeedsDisplay]; // repainting
}

- (void)dealloc
{
    [super dealloc];
}

@end

