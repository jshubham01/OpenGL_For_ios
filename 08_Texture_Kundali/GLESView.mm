//
//  Created by shubham_at_astromedicomp on 12/21/19.
//  2D B&B
//

#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#import "GLESView.h"

#import "vmath.h"

enum
{
    AMC_ATTRIBUTE_POSITION = 0,
    AMC_ATTRIBUTE_COLOR,
    AMC_ATTRIBUTE_NORMAL,
    AMC_ATTRIBUTE_TEXTURE0
};

GLfloat fanglePyramid = 0.0f;
GLfloat fangleCube = 0.0f;

@implementation GLESView
{
    EAGLContext *eaglContext;

    GLuint defaultFramebuffer;
    GLuint colorRenderbuffer;
    GLuint depthRenderbuffer;

    GLuint vertexShaderObject;
    GLuint fragmentShaderObject;
    GLuint shaderProgramObject;

    GLuint vao_pyramid;
    GLuint vao_cube;
    GLuint vbo_pyramid_position;
    GLuint vbo_pyramid_texture;
    GLuint vbo_cube_position;
    GLuint vbo_cube_texture;

    GLuint pyramid_texture;
    GLuint cube_texture;
    GLuint texture_sampler_uniform;

    GLuint mvpUniform;
    vmath:: mat4 perspectiveProjectionMatrix;

    id displayLink;
    NSInteger animationFrameInterval;
    BOOL isAnimating;

    GLint width;
    GLint height;
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

        eaglContext = [[EAGLContext alloc]initWithAPI:kEAGLRenderingAPIOpenGLES3];
        if(nil == eaglContext)
        {
            [self release];
            return(nil);
        }

        [EAGLContext setCurrentContext:eaglContext];

        glGenFramebuffers(1, &defaultFramebuffer);
        glGenRenderbuffers(1, &colorRenderbuffer);

        glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);

        [eaglContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:eaglLayer];

        glFramebufferRenderbuffer(
            GL_FRAMEBUFFER,
            GL_COLOR_ATTACHMENT0,
            GL_RENDERBUFFER,
            colorRenderbuffer);

        GLint backingHeight;
        GLint backingWidth;

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

        glGenRenderbuffers(1, &depthRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, backingWidth, backingHeight);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);

        if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        {
            printf("Failed to create complete framebuffer object:  %x   \n",
                glCheckFramebufferStatus(GL_FRAMEBUFFER));
            glDeleteFramebuffers(1, &defaultFramebuffer);
            glDeleteRenderbuffers(1, &colorRenderbuffer);
            glDeleteRenderbuffers(1, &depthRenderbuffer);

            return(nil);
        }

        printf("Renderer: %s | GL Version : %s | GLSL Version : %s\n",
            glGetString(GL_RENDERER), glGetString(GL_VERSION), glGetString(GL_SHADING_LANGUAGE_VERSION));

        isAnimating = NO;
        animationFrameInterval = 60; // default since iOS 8.2
        /*************************************************/

        vertexShaderObject = glCreateShader(GL_VERTEX_SHADER);

        const GLchar *vertexShaderSourceCode =
            "#version 300 es" \
            "\n" \
            "in vec4 vPosition;" \
            "in vec2 vTexture0_coord;" \
            "out vec2 out_texture0_coord;" \
            "uniform mat4 u_mvp_matrix;" \
            "void main(void)" \
            "{" \
                "gl_Position = u_mvp_matrix * vPosition;" \
                "out_texture0_coord = vTexture0_coord;" \
            "}";

        // specify above code of shader to vertext shader object
        glShaderSource(vertexShaderObject,
            1,
            (const GLchar**)(&vertexShaderSourceCode),
            NULL);

        glCompileShader(vertexShaderObject);

        // catching shader related errors if there are any
        GLint iShaderCompileStatus = 0;
        GLint iInfoLogLength = 0;
        GLchar *szInfoLog = NULL;

        // getting compile status code
        glGetShaderiv(vertexShaderObject,
            GL_COMPILE_STATUS,
            &iShaderCompileStatus);

        if(GL_FALSE == iShaderCompileStatus)
        {
            glGetShaderiv(vertexShaderObject, GL_INFO_LOG_LENGTH,
                &iInfoLogLength);
            if(iInfoLogLength > 0)
            {
                szInfoLog = (GLchar *)malloc(iInfoLogLength);
                if(NULL != szInfoLog)
                {
                    GLsizei written;

                    glGetShaderInfoLog(
                        vertexShaderObject,
                        iInfoLogLength,
                        &written,
                        szInfoLog
                    );

                    printf("VERTEX SHADER FATAL ERROR: %s\n", szInfoLog);
                    free(szInfoLog);
                    [self release];
                }
            }
        }

        // ***  Fragment Shader
        // re-initialize
        // catching shader related errors if there are any
        iShaderCompileStatus = 0;
        iInfoLogLength = 0;
        szInfoLog = NULL;

        fragmentShaderObject = glCreateShader(GL_FRAGMENT_SHADER);
        const GLchar *pcFragmentShaderSourceCode = 
        "#version 300 es" \
        "\n" \
        "precision highp float;" \
        "in vec2 out_texture0_coord;" \
        "uniform sampler2D u_texture0_sampler;" \
        "out vec4 vFragColor;" \
        "void main(void)" \
        "{" \
            "vec3 tex = vec3(texture(u_texture0_sampler, out_texture0_coord));" \
            "vFragColor = vec4(tex, 1.0f);" \
        "}";

        // specify above code of shader to vertext shader object
        glShaderSource(fragmentShaderObject,
            1,
            (const GLchar**)&pcFragmentShaderSourceCode,
            NULL);

        // compile the vertext shader
        glCompileShader(fragmentShaderObject);

        // getting compile status code
        glGetShaderiv(fragmentShaderObject,
            GL_COMPILE_STATUS,
            &iShaderCompileStatus);

        if (GL_FALSE == iShaderCompileStatus)
        {
            glGetShaderiv(fragmentShaderObject,
            GL_INFO_LOG_LENGTH,
            &iInfoLogLength);

        if (iInfoLogLength > 0)
        {
                szInfoLog = (GLchar *)malloc(iInfoLogLength);
                if (NULL != szInfoLog)
                {
                    GLsizei written;

                    glGetShaderInfoLog(
                            fragmentShaderObject,
                            iInfoLogLength,
                            &written,
                            szInfoLog
                        );

                    printf( ("FRAGMENT SHADER FATAL COMPILATION ERROR: %s\n"), szInfoLog);
                    free(szInfoLog);
                    [self release];
                }
            }
        }

        // create shader program objects
        shaderProgramObject = glCreateProgram();

        // attach fragment shader to shader program
        glAttachShader(shaderProgramObject, vertexShaderObject);
        glAttachShader(shaderProgramObject, fragmentShaderObject);

        // Before Prelinking bind binding our no to vertex attribute
        glBindAttribLocation(shaderProgramObject,
            AMC_ATTRIBUTE_POSITION,
            "vPosition");

        glBindAttribLocation(shaderProgramObject,
            AMC_ATTRIBUTE_TEXTURE0,
            "vTexture0_coord");

        // link the shader
        glLinkProgram(shaderProgramObject);

        GLint iShaderProgramLinkStatus = 0;
        iInfoLogLength = 0;

        glGetProgramiv(shaderProgramObject, GL_LINK_STATUS, &iShaderProgramLinkStatus);

        if(GL_FALSE == iShaderProgramLinkStatus)
        {
            glGetProgramiv(shaderProgramObject, GL_LINK_STATUS,
                &iInfoLogLength);

            if(iInfoLogLength > 0)
            {
                szInfoLog = NULL;
                szInfoLog = (char *)malloc(iInfoLogLength);
                if(NULL != szInfoLog)
                {
                    GLsizei written;
                    glGetProgramInfoLog(shaderProgramObject, iInfoLogLength,
                        &written, szInfoLog);
                    printf("Shader Program Link Log: %s \n", szInfoLog);
                    free(szInfoLog);
                    [self release];
                }
            }
        }

        // now this is rule: attribute binding should happen before linking program and
        // uniforms binding should happen after linking
        mvpUniform = glGetUniformLocation(
            shaderProgramObject,
            "u_mvp_matrix"
        );

        texture_sampler_uniform = glGetUniformLocation(
            shaderProgramObject, "u_texture0_sampler");

    pyramid_texture = [self loadTextureFromBMPFile:@"Stone.bmp" :@"bmp"];

    cube_texture = [self loadTextureFromBMPFile:@"Vijay_Kundali.bmp" :@"bmp"];

        const GLfloat fpyramidVertices[] = {
                    0.0f, 1.0f, 0.0f,
                    -1.0f, -1.0f, 1.0f,
                    1.0f, -1.0f, 1.0f,

                    0.0f, 1.0f, 0.0f,
                    1.0f, -1.0f, 1.0f,
                    1.0f, -1.0f, -1.0f,

                    0.0f, 1.0f, 0.0f,
                    1.0f, -1.0f, -1.0f ,
                    -1.0f, -1.0f, -1.0f ,

                    0.0f, 1.0f, 0.0f,
                    -1.0f, -1.0f, -1.0f,
                    -1.0f, -1.0f, 1.0f
            };


    const GLfloat pyramidTexCoords[] = {
                0.5f, 1.0f, // front top
                0.0f, 0.0f, // front left
                1.0f, 1.0f, // front right

                0.5f, 1.0f, // right-top
                0.0f, 0.0f, // right-left
                1.0f, 1.0f, // right-right

                0.5f, 1.0f, // back-top
                0.0f, 0.0f, // back-left
                1.0f, 1.0f, // back-right

                0.5f, 1.0f, // left-top
                0.0f, 0.0f, // left-left
                1.0f, 1.0f // left-right
        };

        glGenVertexArrays(1, &vao_pyramid);
        glBindVertexArray(vao_pyramid);

        glGenBuffers(1, &vbo_pyramid_position);
        glBindBuffer(GL_ARRAY_BUFFER, vbo_pyramid_position);
        glBufferData(GL_ARRAY_BUFFER,
                sizeof(fpyramidVertices),
                fpyramidVertices,
                GL_STATIC_DRAW);

        glVertexAttribPointer(
                AMC_ATTRIBUTE_POSITION,
                3,
                GL_FLOAT,
                GL_FALSE,
                0,
                NULL
            );

        glEnableVertexAttribArray(AMC_ATTRIBUTE_POSITION);

        glBindBuffer(GL_ARRAY_BUFFER, 0);

        //
        // working on texture
        //
        glGenBuffers(1, &vbo_pyramid_texture);
        glBindBuffer(GL_ARRAY_BUFFER,
            vbo_pyramid_texture);

        glBufferData(GL_ARRAY_BUFFER,
            sizeof(pyramidTexCoords),
            pyramidTexCoords,
            GL_STATIC_DRAW);

        glVertexAttribPointer(AMC_ATTRIBUTE_TEXTURE0,
            2,
            GL_FLOAT,
            GL_FALSE,
            0,
            NULL);

        glEnableVertexAttribArray(AMC_ATTRIBUTE_TEXTURE0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);

        glBindVertexArray(0);

        //
        // Kundali Cube
        //

        GLfloat fcubeVertices[] = {
                1.0f, 1.0f, -1.0f,
                -1.0f, 1.0f, -1.0f,
                -1.0f, 1.0f, 1.0f,
                1.0f, 1.0f, 1.0f,

                1.0f, -1.0f, -1.0f ,
                -1.0f, -1.0f, -1.0f,
                -1.0f, -1.0f, 1.0f,
                1.0f, -1.0f, 1.0f,

                1.0f, 1.0f, 1.0f,
                -1.0f, 1.0f, 1.0f,
                -1.0f, -1.0f, 1.0f,
                1.0f, -1.0f, 1.0f,

                1.0f, 1.0f, -1.0f,
                -1.0f, 1.0f, -1.0f,
                -1.0f, -1.0f, -1.0f,
                1.0f, -1.0f, -1.0f,

                1.0f, 1.0f, -1.0f,
                1.0f, 1.0f, 1.0f,
                1.0f, -1.0f, 1.0f,
                1.0f, -1.0f, -1.0f,

                -1.0f, 1.0f, -1.0f,
                -1.0f, 1.0f, 1.0f,
                -1.0f, -1.0f, 1.0f,
                -1.0f, -1.0f, -1.0f
            };

    const GLfloat fcubeTexCoords[] = {
                1.0f, 1.0f,
                0.0f, 1.0f,
                0.0f, 0.0f,
                1.0f, 0.0f,

                1.0f, 0.0f,
                0.0f, 0.0f,
                0.0f, 1.0f,
                1.0f, 1.0f,
    
                1.0f, 1.0f,
                0.0f, 1.0f,
                0.0f, 0.0f,
                1.0f, 0.0f,
    
                0.0f, 1.0f,
                1.0f, 1.0f,
                1.0f, 0.0f,
                0.0f, 0.0f,
    
                1.0f, 1.0f,
                0.0f, 1.0f,
                0.0f, 0.0f,
                1.0f, 0.0f,
    
                0.0f, 1.0f,
                1.0f, 1.0f,
                1.0f, 0.0f,
                0.0f, 0.0f
        };

        for(int i=0; i<72; i++)
        {
            if(fcubeVertices[i] < 0.0f)
            {
                fcubeVertices[i] = fcubeVertices[i] + 0.25f;
            }
            else if(fcubeVertices[i]>0.0f)
            {
                fcubeVertices[i] = fcubeVertices[i] - 0.25f;
            }
            else
            {
                fcubeVertices[i] = fcubeVertices[i]; // no change
            }
        }

        glGenVertexArrays(1, &vao_cube);
        glBindVertexArray(vao_cube);

        glGenBuffers(1, &vbo_cube_position);
        glBindBuffer(GL_ARRAY_BUFFER, vbo_cube_position);
        glBufferData(GL_ARRAY_BUFFER,
            sizeof(fcubeVertices),
            fcubeVertices,
            GL_STATIC_DRAW);

        glVertexAttribPointer(
            AMC_ATTRIBUTE_POSITION,
            3,
            GL_FLOAT,
            GL_FALSE,
            0,
            NULL
        );

        glEnableVertexAttribArray(AMC_ATTRIBUTE_POSITION);
        glBindBuffer(GL_ARRAY_BUFFER, 0);

        // Texture vbo
        glGenBuffers(1, &vbo_cube_texture);
        glBindBuffer(GL_ARRAY_BUFFER, vbo_cube_texture);

        glBufferData(GL_ARRAY_BUFFER,
            sizeof(fcubeTexCoords),
            fcubeTexCoords,
            GL_STATIC_DRAW);

        glVertexAttribPointer(AMC_ATTRIBUTE_TEXTURE0,
            2,
            GL_FLOAT,
            GL_FALSE,
            0,
            NULL);

        glEnableVertexAttribArray(AMC_ATTRIBUTE_TEXTURE0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);


        glBindVertexArray(0);
        glEnable(GL_TEXTURE_2D);

        glEnable(GL_DEPTH_TEST);
        glDepthFunc(GL_LEQUAL);
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        //glEnable(GL_CULL_FACE);
        //glClearDepth(1.0f);

        // set projection  Matrix
        perspectiveProjectionMatrix = vmath::mat4::identity();

        /*************************************************/
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

-(GLuint)loadTextureFromBMPFile:(NSString *)texFileName :(NSString *)extension
{
    NSString *textureFileNameWithPath = 
        [[NSBundle mainBundle] pathForResource:texFileName ofType:extension];

    UIImage *bmpImage =
        [[UIImage alloc] initWithContentsOfFile:textureFileNameWithPath];

    if(!bmpImage)
    {
        NSLog(@"can't find %@", textureFileNameWithPath);
        return(0);
    }

    //CGImageRef cgImage = [bmpImage CGImageForProposedRect:nil context:nil hints:nil];
    CGImageRef cgImage = bmpImage.CGImage;

    int w = (int)CGImageGetWidth(cgImage);
    int h = (int)CGImageGetHeight(cgImage);

    CFDataRef imageData = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
    void *pixels = (void *)CFDataGetBytePtr(imageData);

    GLuint bmpTexture;
    glGenTextures(1, &bmpTexture);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glBindTexture(GL_TEXTURE_2D, bmpTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    glGenerateMipmap(GL_TEXTURE_2D);

    CFRelease(imageData);
    return(bmpTexture);
}

+(Class)layerClass
{
    // code
    return([CAEAGLLayer class]);
}

-(void)drawView:(id)sender
{
    [EAGLContext setCurrentContext:eaglContext];

    glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
    glUseProgram(shaderProgramObject);

    // initialize above matrices to identity
    vmath::mat4 modelViewMatrix = vmath::mat4::identity();
    vmath::mat4 modelRotationMatrix = vmath::mat4::identity();
    vmath::mat4 modelViewProjectionMatrix = vmath::mat4::identity();

    modelViewMatrix = vmath::translate(-1.5f, 0.0f, -6.0f);
    modelRotationMatrix = vmath::rotate(fanglePyramid, 0.0f, 1.0f, 0.0f);
    modelViewMatrix = modelViewMatrix * modelRotationMatrix;
    modelViewProjectionMatrix = perspectiveProjectionMatrix * modelViewMatrix;

    // uniforms are given to m_uv_matrix (i.e. model view matrix)
    glUniformMatrix4fv(mvpUniform, 1, GL_FALSE, modelViewProjectionMatrix);

    glBindTexture(GL_TEXTURE_2D, pyramid_texture);
    glBindVertexArray(vao_pyramid);
    glDrawArrays(GL_TRIANGLES,  0,  12);
    glBindVertexArray(0);

    // Cube
    modelViewMatrix = vmath::mat4::identity();
    modelRotationMatrix = vmath::mat4::identity();
    modelViewProjectionMatrix = vmath::mat4::identity();

    modelViewMatrix = vmath::translate(1.5f, 0.0f, -6.0f);
    modelRotationMatrix = vmath::rotate(fangleCube, fangleCube, fangleCube);
    //modelRotationMatrix = modelRotationMatrix * vmath::rotate(fanglePyramid, 0.0f, 1.0f, 0.0f);
    //    modelRotationMatrix = modelRotationMatrix * vmath::rotate(fanglePyramid, 0.0f, 1.0f, 0.0f);

    modelViewMatrix = modelViewMatrix * modelRotationMatrix;
    modelViewProjectionMatrix = perspectiveProjectionMatrix * modelViewMatrix;

    // uniforms are given to m_uv_matrix (i.e. model view matrix)
    glUniformMatrix4fv(
            mvpUniform,
            1,			//	how many matrices
            GL_FALSE,	//	Transpose is needed ? ->
            modelViewProjectionMatrix
        );

    glBindTexture(GL_TEXTURE_2D, cube_texture);
    glBindVertexArray(vao_cube);

    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 4, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 8, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 12, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 16, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 20, 4);
    glBindVertexArray(0);

    glUseProgram(0);

    fanglePyramid += 0.3f;
    if (fanglePyramid > 360.0f)
    {
        fanglePyramid = 0.0f;
    }

    fangleCube += 0.3f;
    if (fangleCube > 360.0f)
    {
        fangleCube = 0.0f;
    }

    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    [eaglContext presentRenderbuffer:GL_RENDERBUFFER];
}

-(void)layoutSubviews // this is like redraw
{
    GLfloat fWidth;
    GLfloat fHeight;

    // code
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    [eaglContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];

    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &height);

    glGenRenderbuffers(1, &depthRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, width, height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);

    if(0 == height)
    {
        height = 1;
    }

    glViewport(0, 0, width, height);

    fWidth = (GLfloat)width;
    fHeight = (GLfloat)height;

    perspectiveProjectionMatrix = vmath::perspective(
            45.0f, fWidth/fHeight, 0.1f, 100.0f
        );

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
            NSClassFromString(@"CADisplayLink") displayLinkWithTarget:self selector:@selector(drawView:)];
            [displayLink setPreferredFramesPerSecond:animationFrameInterval];
            [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

    isAnimating:YES;
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
    // [self setNeedsDisplay]; // repainting
}

- (void)onDoubleTap:(UITapGestureRecognizer *)gr
{
    // code
    // [self setNeedsDisplay]; // repainting
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
    // [self setNeedsDisplay]; // repainting
}

- (void)dealloc
{
    if(vbo_pyramid_position)
    {
        glDeleteBuffers(1, &vbo_pyramid_position);
        vbo_pyramid_position = 0;
    }

    if(vbo_pyramid_texture)
    {
        glDeleteBuffers(1, &vbo_pyramid_texture);
        vbo_pyramid_texture = 0;
    }

    if(vbo_cube_position)
    {
        glDeleteBuffers(1, &vbo_cube_position);
        vbo_cube_position = 0;
    }

    if(vbo_cube_texture)
    {
        glDeleteBuffers(1, &vbo_cube_texture);
        vbo_cube_texture = 0;
    }

    if (vao_pyramid)
    {
        glDeleteVertexArrays(1, &vao_pyramid);
        vao_pyramid = 0;
    }

    if (vao_cube)
    {
        glDeleteVertexArrays(1, &vao_cube);
        vao_cube = 0;
    }

    if(depthRenderbuffer)
    {
        glDeleteRenderbuffers(1, &depthRenderbuffer);
        depthRenderbuffer = 0;
    }

    if(colorRenderbuffer)
    {
        glDeleteRenderbuffers(1, &colorRenderbuffer);
        colorRenderbuffer = 0;
    }

    if(defaultFramebuffer)
    {
        glDeleteFramebuffers(1, &defaultFramebuffer);
        defaultFramebuffer = 0;
    }

    if([EAGLContext currentContext] == eaglContext)
    {
        [EAGLContext setCurrentContext:nil];
    }

    [eaglContext release];
    eaglContext = nil;

    [super dealloc];
}

@end
