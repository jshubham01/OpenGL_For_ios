//
//  GLView.m
//  Window
//
//  Created by user159339 on 12/21/19.
//

#import "GLESView.h"

@implementation GLESView{
    EAGLContext *eaglContext;

    GLuint defaultFrameBuffer;
    GLuint colorRenderBuffer;
    GLuint depthRenderBuffer;

    id displayLink;
    NSInteger animationFrameInterval;
    BOOL isAnimating;
}

-(id)initWithFrame:(CGRect)frame
{
    // code
    self = [super initWithFrame:frame];

    if(self)
    {
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)super.layer;

        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties=[NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithBool:FALSE],
            kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8,
             kEAGLDrawablePropertyColorFormat, nil];

        eaglLayer = [[EAGLContext alloc]initWithAPI:kEAGLRenderingAPIOpenGLES3];
        if(nil == eaglLayer)
        {
            [self release];
            return(nil);
        }

        [EAGLContext setCurrentContext:eagleContext];

        glGenFramebuffers(1, &defaultFramebuffer);
        glBindFrameBuffer(GL_FRAMEBUFFER, defaultFrameBuffer);

        glGenRenderbuffers(1, &colorRenderBuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);

        [eaglContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:eaglLayer];

        glFramebufferRenderbuffer(
            GL_FRAMEBUFFER,
            GL_COLOR_ATTACHMENT0,
            GL_RENDERBUFFER,
            colorRenderbuffer);

        GLuint backingWidth;
        GLuint backingHeight;
        glGetRenderbufferParameteriv(
            GL_RENDERBUFFER,
            GL_RENDERBUFFER_WIDTH,
            &backingWidth
        );

        glGetRenderbufferParameteriv(
            GL_RENDERBUFFER,
            GL_RENDERBUFFER_HEIGHT,
            &backingHeight
        );

        glGenRenderbuffers(1, &depthRenderBuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, depthRenderBuffer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, backingWidth, backingHeight);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderBuffer);

        if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        {
            printf("Failed to create complete framebuffer object: %s \n",
                glCheckFramebufferStatus(GL_FRAMEBUFFER));
            glDeleteFramebuffers(1, &defaultFrameBuffer);
            glDeleteRenderbuffers(1, &colorRenderbuffer);
            glDeleteRenderbuffers(1, &depthRenderBuffer);

            return(nil);
        }

        printf("Renderer: %s | GL Version : %s | GLSL Version : %s\n",
            glGetString(GL_RENDERER), glGetString(GL_VERSION), glGetString(GL_SHADING_LANGUAGE_VERSION));

        isAnimating = NO;
        animationFrameInterval = 60; // default since iOS 8.2

        // Clear Color
        glClearColor(0.0f, 0.0f, 1.0f, 1.0f); // blue

        // GESTURE RECOGNITION
        // Tap gesture code
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

        // swipe gesture
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

+(Class)layerClass
{
    // code
    return([CAEAGLLayer class]);
}

-(void)drawView:(id)sender
{
    [EAGLContext setCurrentContext:eaglContext];

    glBindFrameBuffer(GL_FRAMEBUFFER, defaultFrameBuffer);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    [eaglContext presentRenderBuffer:GL_RENDERBUFFER];
}

-(void)layoutSubviews // this is like redraw
{
    GLint width;
    GLint height;

    // code
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderBuffer);
    [eaglContext renderbufferStorage:GL_RENDERBUFFER, fromDrawable:(CAEAGLLayer *)self.layer];

    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &height);

    glGenRenderbuffers(1, &depthRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, depthRenderBuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, width, height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderBuffer);

    glViewport(0, 0, width, height);
    if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        printf("Failed To Create Complete Framebuffer Object %x\n",
            glCheckFramebufferStatus(GL_FRAMEBUFFER));
    }

    [self drawView:nil];
}

-(void)startAnimation
{
    if(!isAnimating)
    {
        displayLink = [
            NSClassFromString(@"CADisplayLink") displayLinkWithTarget:self selector:@selector(drawView:);
            [displayLink setPreferredFramesPerSecond:animationFrameInterval];
            [displayLink addToRunLoop:[NSRunLoop] currentRunLoop] forMode:NSDefaultRunLoopMode];

            isAnimating:YES;
        ]
    }
}

-(void)stopAnimation
{
    if(isAnimating)
    {
        [displayLink invalidate];
        displayLink = nil;

        isAnimating = NO;
    }
}

//

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
    [self setNeedsDisplay]; // repainting
}

- (void)onDoubleTap:(UITapGestureRecognizer *)gr
{
    // code
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
    [self setNeedsDisplay]; // repainting
}

- (void)dealloc
{
    if(depthRenderBuffer)
    {
        glDeleteRenderbuffers(1, &depthRenderBuffer);
        depthRenderBuffer = 0;
    }

    if(colorRenderBuffer)
    {
        glDeleteRenderbuffers(1, &colorRenderBuffer);
        colorRenderBuffer = 0;
    }

    if(defaultFrameBuffer)
    {
        glDeleteFramebuffers(1, &defaultFrameBuffer);
        defaultFrameBuffer = 0;
    }

    if([EAGLContext currentContext] == eaglContext)
    {
        [EAGLContext setCurrentContext:nil];
    }

    [eagleContext release];
    eagleContext = nil;

    [super dealloc];
}

@end
