//
//  Created by shubham_at_astromedicomp on 12/21/19.
//  Perspetive Triangle
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

@implementation GLESView
{
    EAGLContext *eaglContext;

    GLuint defaultFramebuffer;
    GLuint colorRenderbuffer;
    GLuint depthRenderbuffer;

    GLuint vertexShaderObject;
    GLuint fragmentShaderObject;
    GLuint shaderProgramObject;

    GLuint vao;
    GLuint vbo;

    GLuint vao_verticalLines;
    GLuint vbo_verticalLines;

    GLuint vao_Circle;
    GLuint vbo_Circle;

    GLuint vao_Rectangle;
    GLuint vbo_Rectangle;

    GLuint vao_Triangle;
    GLuint vbo_Triangle;

    GLuint vao_In_Circle;
    GLuint vbo_In_Circle;

    GLuint mvpUniform;
    GLuint colorUniform;

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
            "uniform mat4 u_mvp_matrix;" \
            "void main(void)" \
            "{" \
            "gl_Position = u_mvp_matrix * vPosition;" \
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
        "out vec4 vFragColor;" \
        "uniform vec4 u_vLineColor;" \
        "void main(void)" \
        "{" \
            "vFragColor = u_vLineColor;" \
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
        // change for Ortho
        // here we binded gpu`s variable to cpu`s index
        glBindAttribLocation(shaderProgramObject,
            AMC_ATTRIBUTE_POSITION,
            "vPosition");

        // link the shader
        glLinkProgram(shaderProgramObject);

        GLint iShaderProgramLinkStatus = 0;
        iInfoLogLength = 0;
        
        glGetProgramiv(shaderProgramObject,
            GL_LINK_STATUS,
            &iShaderProgramLinkStatus);

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

        colorUniform = glGetUniformLocation(
            shaderProgramObject,
            "u_vLineColor"
        );

        GLfloat fLineArray[126];
        int flag = 0;
        GLfloat fFact = -1.0f;
        int ind;
        for (ind = 0; ind < 42; ind++)
        {
            fLineArray[ind * 3 + 1] = fFact;
            fLineArray[ind * 3 + 2] = 0.0f;
            if (0 == flag)
            {
                fLineArray[ind * 3] = -1.0f;
            }
            else
            {
                fLineArray[ind * 3] = 1.0f;
                fFact += 0.1;
            }

            if (1 == flag)
            {
                flag = 0;
            }
            else
            {
            flag = 1;
            }
        }

        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);

        glGenBuffers(1, &vbo);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER,
                sizeof(fLineArray),
                fLineArray,
                GL_STATIC_DRAW);

        glVertexAttribPointer(
                AMC_ATTRIBUTE_POSITION,
                3,									// how many co-ordinates in vertice
                GL_FLOAT,							// type of above data
                GL_FALSE,							// no normalization is desired
                0,									// (dangha)
                NULL								// offset to start in above attrib position
            );

        glEnableVertexAttribArray(AMC_ATTRIBUTE_POSITION);

        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindVertexArray(0);

        // For VERTICAL Lines
        float fVerticalLines[126];
        flag = 0;
        fFact = -1.0f;
        for (ind = 0; ind < 42; ind++)
        {
            fVerticalLines[ind * 3] = fFact;
            fVerticalLines[ind * 3 + 2] = 0.0f;
            if (0 == flag)
            {
                fVerticalLines[ind * 3 + 1] = -1.0f;
            }
            else
            {
                fVerticalLines[ind * 3 + 1] = 1.0f;
                fFact += 0.1;
            }

            if (1 == flag)
            {
                flag = 0;
            }
            else
            {
                flag = 1;
            }
        }

        glGenVertexArrays(1, &vao_verticalLines);
        glBindVertexArray(vao_verticalLines);
        glGenBuffers(1, &vbo_verticalLines);
        glBindBuffer(GL_ARRAY_BUFFER, vbo_verticalLines);
        glBufferData(GL_ARRAY_BUFFER,
            sizeof(fVerticalLines),
            fVerticalLines,
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
        glBindVertexArray(0);

    //
	// Circle
	//
	GLfloat fAngle = 0.0f;
	float fCirclePositions[1000 * 3];
	for (ind = 0; ind < 1000; ind++)
	{
		fAngle = 2.0f * M_PI * ind / 1000;
		fCirclePositions[ind * 3] = cos(fAngle);
		fCirclePositions[ind * 3 + 1] = sin(fAngle);
		fCirclePositions[ind * 3 + 2] = 0.0f;
	}

	glGenVertexArrays(1, &vao_Circle);
	glBindVertexArray(vao_Circle);
	glGenBuffers(1, &vbo_Circle);
	glBindBuffer(GL_ARRAY_BUFFER, vbo_Circle);
	glBufferData(GL_ARRAY_BUFFER, sizeof(fCirclePositions), fCirclePositions, GL_STATIC_DRAW);
	glVertexAttribPointer(AMC_ATTRIBUTE_POSITION, 3, GL_FLOAT, GL_FALSE, 0, NULL);
	glEnableVertexAttribArray(AMC_ATTRIBUTE_POSITION);

	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glBindVertexArray(0);


    //
    // Rectangle
    //
    GLfloat fSide = sqrt(0.5f);
    const GLfloat fArrayRectangle[] = {
        fSide, fSide, 0.0f,
        -fSide, fSide, 0.0f,
        -fSide, fSide, 0.0f,
        -fSide, -fSide, 0.0f,
        -fSide, -fSide, 0.0f,
        fSide, -fSide, 0.0f,
        fSide, -fSide, 0.0f,
        fSide, fSide, 0.0f
    };

    glGenVertexArrays(1, &vao_Rectangle);
    glBindVertexArray(vao_Rectangle);
    glGenBuffers(1, &vbo_Rectangle);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_Rectangle);
    glBufferData(GL_ARRAY_BUFFER,
        sizeof(fArrayRectangle),
        fArrayRectangle,
        GL_STATIC_DRAW);
    glVertexAttribPointer(AMC_ATTRIBUTE_POSITION, 3, GL_FLOAT, GL_FALSE, 0, NULL);
    glEnableVertexAttribArray(AMC_ATTRIBUTE_POSITION);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);

	// Triangle for Incircle
	// Side of Triangle - fSide 

	// Calculating lengths of sides
	GLfloat fx, fy, fTempfA, fTempfB, fDistA, fDistB, fDistC;

	fx = fy = fSide;
	fTempfA = -fx;
	fTempfB = -2 * fy;
	fDistA = sqrt(fTempfA*fTempfA + fTempfB * fTempfB);
	fTempfA = 2 * fx;
	fTempfB = 0.0f;
	fDistB = sqrt(fTempfA*fTempfA + fTempfB * fTempfB);
	fTempfA = -fx;
	fTempfB = 2 * fy;
	fDistC = sqrt(fTempfA * fTempfA + fTempfB * fTempfB);

	const GLfloat fInTriangle[] = { 0.0f, fy, 0.0f,
				-fx, -fy, 0.0f,
				-fx, -fy, 0.0f,
				fx, -fy, 0.0f,
				fx, -fy, 0.0f,
				0.0f, fy, 0.0f
	};

	glGenVertexArrays(1, &vao_Triangle);
	glBindVertexArray(vao_Triangle);

	glGenBuffers(1, &vbo_Triangle);
	glBindBuffer(GL_ARRAY_BUFFER, vbo_Triangle);
	glBufferData(GL_ARRAY_BUFFER, sizeof(fInTriangle), fInTriangle, GL_STATIC_DRAW);
	glVertexAttribPointer(AMC_ATTRIBUTE_POSITION, 3, GL_FLOAT, GL_FALSE, 0, NULL);
	glEnableVertexAttribArray(AMC_ATTRIBUTE_POSITION);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glBindVertexArray(0);

	//
	// In-Circle
	// 
	GLfloat fIncircleXCord, fIncircleYCord, fSemiPerimeter, fAreaSquare, fArea, fInRadius;

	fIncircleXCord = ((fDistB) * 0.0f) + ((fDistC * (-fx)) + ((fDistA) * fx))
						/ (fDistA + fDistB + fDistC);

	fIncircleYCord = (((fDistB) * fy) + (fDistC * (-fy)) + ((fDistA) * (-fy)))
		/ (fDistA + fDistB + fDistC);

	fSemiPerimeter = (fDistA + fDistB + fDistC) / 2;

	fAreaSquare = (fSemiPerimeter - fDistA)
		* (fSemiPerimeter - fDistB)
		* (fSemiPerimeter - fDistC) * fSemiPerimeter;

	fArea = sqrt(fAreaSquare);
	fInRadius = fArea / fSemiPerimeter;

	ind = 0;
	fAngle = 0.0f;
	float fInCirclePositions[1000 * 3];
	for (ind = 0; ind < 1000; ind++)
	{
		fAngle = 2.0f * M_PI * ind / 1000;
		fInCirclePositions[ind * 3] = fInRadius * cos(fAngle) + fIncircleXCord;
		fInCirclePositions[ind * 3 + 1] = fInRadius * sin(fAngle) + fIncircleYCord;
		fInCirclePositions[ind * 3 + 2] = 0.0f;
	}

	glGenVertexArrays(1, &vao_In_Circle);
	glBindVertexArray(vao_In_Circle);

	glGenBuffers(1, &vbo_In_Circle);
	glBindBuffer(GL_ARRAY_BUFFER, vbo_In_Circle);
	glBufferData(GL_ARRAY_BUFFER, sizeof(fInCirclePositions), fInCirclePositions, GL_STATIC_DRAW);
	glVertexAttribPointer(AMC_ATTRIBUTE_POSITION, 3, GL_FLOAT, GL_FALSE, 0, NULL);
	glEnableVertexAttribArray(AMC_ATTRIBUTE_POSITION);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glBindVertexArray(0);

        glEnable(GL_DEPTH_TEST);
        glDepthFunc(GL_LEQUAL);
        glEnable(GL_CULL_FACE);
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
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
    vmath::mat4 modelViewProjectionMatrix = vmath::mat4::identity();

    modelViewMatrix = vmath::translate(0.0f, 0.0f, -3.0f);
    modelViewProjectionMatrix = perspectiveProjectionMatrix * modelViewMatrix;

    // uniforms are given to m_uv_matrix (i.e. model view matrix)
    glUniformMatrix4fv(
            mvpUniform,
            1,          //  how many matrices
            GL_FALSE,   //  Transpose is needed ? ->
            modelViewProjectionMatrix
        );

    glUniform4f(colorUniform, 0.0f, 0.0f, 1.0f, 1.0f);

    // bind with vow (this is avoiding many necessary binding with vbos)
    glBindVertexArray(vao);

    glLineWidth(0.5f);
    glDrawArrays(GL_LINES,  0,  20);

    glLineWidth(2.0f);
    glUniform4f(colorUniform, 1.0f, 0.0f, 0.0f, 1.0f);
    glDrawArrays(GL_LINES, 20, 2);

    glLineWidth(0.5f);
    glUniform4f(colorUniform, 0.0f, 0.0f, 1.0f, 1.0f);
    glDrawArrays(GL_LINES, 22, 20);
    glBindVertexArray(0);

    glBindVertexArray(vao_verticalLines);

    glLineWidth(0.5f);
    glDrawArrays(GL_LINES, 0, 20);

    glLineWidth(2.0f);
    glUniform4f(colorUniform, 0.0f, 1.0f, 0.0f, 1.0f);
    glDrawArrays(GL_LINES, 20, 2);

    glLineWidth(0.5f);
    glUniform4f(colorUniform, 0.0f, 0.0f, 1.0f, 1.0f);
    glDrawArrays(GL_LINES, 22, 20);
    glBindVertexArray(0);

    //
    // Circle
    //
    modelViewMatrix = vmath::mat4::identity();
    modelViewProjectionMatrix = vmath::mat4::identity();

    modelViewMatrix = vmath::translate(0.0f, 0.0f, -3.0f);
    modelViewProjectionMatrix = perspectiveProjectionMatrix * modelViewMatrix;

    // uniforms are given to m_uv_matrix (i.e. model view matrix)
    glUniformMatrix4fv(
        mvpUniform,
        1,			//	how many matrices
        GL_FALSE,	//	Transpose is needed ? ->
        modelViewProjectionMatrix
    );
    glUniform4f(colorUniform, 1.0f, 1.0f, 0.0f, 1.0f); // red + green = yellow

    glBindVertexArray(vao_Circle);
    glLineWidth(0.5f);
    glDrawArrays(GL_LINE_LOOP, 0, 1000);
    glBindVertexArray(0);

    //
    // Rectangle
    //
    glBindVertexArray(vao_Rectangle);
    glLineWidth(1.5f);
    glUniform4f(colorUniform, 1.0f, 1.0f, 0.0f, 1.0f); // red + green = yellow
    glDrawArrays(GL_LINES, 0, 8);
    glBindVertexArray(0);

    //
    // Triangle
    //
    glBindVertexArray(vao_Triangle);
    glDrawArrays(GL_LINES, 0, 6);
    glBindVertexArray(0);

    //
    // In-Circle
    //
    glBindVertexArray(vao_In_Circle);
    glDrawArrays(GL_LINE_LOOP, 0, 1000);
    glBindVertexArray(0);

    glUseProgram(0);
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

    if(vbo_Circle)
    {
        glDeleteBuffers(1, &vbo_Circle);
        vbo_Circle = 0;
    }

    if (vao_Circle)
    {
        glDeleteVertexArrays(1, &vao_Circle);
        vao_Circle = 0;
    }


    if(vbo_Rectangle)
    {
        glDeleteBuffers(1, &vbo_Rectangle);
        vbo_Rectangle = 0;
    }

    if (vao_Rectangle)
    {
        glDeleteVertexArrays(1, &vao_Rectangle);
        vao_Rectangle = 0;
    }

    if(vbo_Triangle)
    {
        glDeleteBuffers(1, &vbo_Triangle);
        vbo_Triangle = 0;
    }

    if (vao_Triangle)
    {
        glDeleteVertexArrays(1, &vao_Triangle);
        vao_Triangle = 0;
    }

    if(vbo_In_Circle)
    {
        glDeleteBuffers(1, &vbo_In_Circle);
        vbo_In_Circle = 0;
    }

    if (vao_In_Circle)
    {
        glDeleteVertexArrays(1, &vao_In_Circle);
        vao_In_Circle = 0;
    }

    if(vbo_verticalLines)
    {
        glDeleteBuffers(1, &vbo_verticalLines);
        vbo_verticalLines = 0;
    }

    if (vao_verticalLines)
    {
        glDeleteVertexArrays(1, &vao_verticalLines);
        vao_verticalLines = 0;
    }

    if(vbo)
    {
        glDeleteBuffers(1, &vbo);
        vbo = 0;
    }

    if(vao)
    {
        glDeleteVertexArrays(1, &vao);
        vao = 0;
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
