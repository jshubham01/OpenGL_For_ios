//
//  Created by shubham_at_astromedicomp on 12/21/19.
//  Perspetive Triangle
//

#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#import "GLESView.h"

#import "vmath.h"


#define SAFFRON 1.0f, (153.0f / 256.0f), (51.0f / 256.0f)
#define GREEN (18.0f / 256.0f), (136.0f / 256.0f), (7.0f / 256.0f)

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

    GLuint vao_I;
    GLuint vbo_I_Position;
    GLuint vbo_I_Color;

    GLuint vao_N;
    GLuint vbo_N_Position;
    GLuint vbo_N_Color;

    GLuint vao_D;
    GLuint vbo_D_Position;
    GLuint vbo_D_Color;

    GLuint vao_I2;
    GLuint vbo_I2_Position;
    GLuint vbo_I2_Color;

    GLuint vao_A;
    GLuint vbo_A_Position;
    GLuint vbo_A_Color;

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
            "in vec4 vColor;" \
            "out vec4 voutColor;" \
            "uniform mat4 u_mvp_matrix;" \
            "void main(void)" \
            "{" \
            "voutColor = vColor;" \
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
        "in vec4 voutColor;" \
        "out vec4 vFragColor;" \
        "void main(void)" \
        "{" \
            "vFragColor = voutColor;" \
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

        glBindAttribLocation(shaderProgramObject,
        AMC_ATTRIBUTE_COLOR, "vColor");

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

    GLfloat fOffN;
    GLfloat fOffD;
    GLfloat fOffA;
    GLfloat fOffI2;
    GLfloat fOffI1;
    GLfloat fLine1x;
    GLfloat fLine1y;
    GLfloat fLine2x;
    GLfloat fLine2y;
    GLfloat fhSpace;
    GLfloat fwSpace;
    GLfloat fWidthH;
    GLfloat fHeightH;
    GLfloat fOffForN;
    GLfloat fOffForD;
    GLfloat fOffForA;
    GLfloat fLetterWidth;

    const GLfloat cfHeight = 4.1f;
    //const GLfloat cfWidth = 7.4f;
    const GLfloat cfWidth = 7.4f;

    // Drawing Letter I
    fWidthH = cfWidth / 2;
    fHeightH = cfHeight / 2;
    fwSpace = 15 * cfWidth / 100;
    fhSpace = 18 * cfHeight / 100;

    GLfloat Yoff;
    GLfloat fTemp;
    GLfloat fHeight;
    GLfloat fLetterSpace;

    fTemp = (fWidthH - fwSpace) - (-(fWidthH - fwSpace));
    //fLetterSpace = fTemp / 5;
    fLetterSpace = fTemp / 6;
    fOffI1 = -(fWidthH - fwSpace);
    fOffN = fOffI1 + fLetterSpace;
    fOffD = fOffN + fLetterSpace;
    fOffI2 = fOffD + fLetterSpace;
    fOffA = fOffI2 + fLetterSpace;
    fLetterWidth = fLetterSpace / 4;
    // fOffForN = fOffI1 + fLetterSpace;
    fOffForN = fOffI1 + fLetterSpace + 0.35f; // this 0.35 came after changing following fOffX
    fOffForD = fOffForN + fLetterSpace;
    fOffI2 = fOffForD + fLetterSpace;
    fOffForA = fOffI2 + fLetterSpace;

    //GLfloat fOffX = -2.35;
    GLfloat fOffX = -2.0;
    Yoff = fHeightH - fhSpace;
    GLfloat fWidth = fLetterWidth;
    fHeight = -(fHeightH - fhSpace);

    const GLfloat fLineArray[] =
    {
        fOffX + fWidth,Yoff, 0.0f,
        fOffX, Yoff, 0.0f,
        fOffX, fHeight, 0.0f,
        fOffX + fWidth, fHeight, 0.0f
    };

    glGenVertexArrays(1, &vao_I);
    glBindVertexArray(vao_I);

    glGenBuffers(1, &vbo_I_Position);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_I_Position);
    glBufferData(GL_ARRAY_BUFFER, sizeof(fLineArray), fLineArray, GL_STATIC_DRAW);
    glVertexAttribPointer(AMC_ATTRIBUTE_POSITION, 3, GL_FLOAT, GL_FALSE, 0, NULL);
    glEnableVertexAttribArray(AMC_ATTRIBUTE_POSITION);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    const GLfloat fColorIArray[] = {SAFFRON,  SAFFRON, GREEN, GREEN};

    glGenBuffers(1, &vbo_I_Color);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_I_Color);
    glBufferData(GL_ARRAY_BUFFER, sizeof(fColorIArray), fColorIArray, GL_STATIC_DRAW);
    glVertexAttribPointer(AMC_ATTRIBUTE_COLOR, 3, GL_FLOAT, GL_FALSE, 0, NULL);
    glEnableVertexAttribArray(AMC_ATTRIBUTE_COLOR);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);

	const GLfloat fN_PositionArray[] = {fOffForN + fLetterWidth, 1.31, 0.0f, fOffForN, 1.31,  0.0f,
		fOffForN, -1.31, 0.0f, fOffForN + fLetterWidth, -1.31, 0.0f, fOffForN + 3 * fLetterWidth, -1.31, 0.0f,
		fOffForN + fLetterWidth, 1.31, 0.0f, fOffForN, 1.31, 0.0f, fOffForN + 2 * fLetterWidth, -1.31, 0.0f,
		fOffForN + 3 * fLetterWidth, 1.31, 0.0f, fOffForN + 2 * fLetterWidth, 1.31, 0.0f,
		fOffForN + 2 * fLetterWidth, -1.31, 0.0f, fOffForN + 3 * fLetterWidth, -1.31, 0.0f
	};

	const GLfloat fN_ColorArray[] = {SAFFRON, SAFFRON, GREEN,
		GREEN, GREEN, SAFFRON,
		SAFFRON, GREEN, SAFFRON,
		SAFFRON, GREEN, GREEN};

	glGenVertexArrays(1, &vao_N);
	glBindVertexArray(vao_N);

	glGenBuffers(1, &vbo_N_Position);
	glBindBuffer(GL_ARRAY_BUFFER, vbo_N_Position);
	glBufferData(GL_ARRAY_BUFFER, sizeof(fN_PositionArray), fN_PositionArray, GL_STATIC_DRAW);
	glVertexAttribPointer(AMC_ATTRIBUTE_POSITION, 3, GL_FLOAT, GL_FALSE, 0, NULL);
	glEnableVertexAttribArray(AMC_ATTRIBUTE_POSITION);
	glBindBuffer(GL_ARRAY_BUFFER, 0);

	glGenBuffers(1, &vbo_N_Color);
	glBindBuffer(GL_ARRAY_BUFFER, vbo_N_Color);
	glBufferData(GL_ARRAY_BUFFER, sizeof(fN_ColorArray), fN_ColorArray, GL_STATIC_DRAW);
	glVertexAttribPointer(AMC_ATTRIBUTE_COLOR, 3, GL_FLOAT, GL_FALSE, 0, NULL);
	glEnableVertexAttribArray(AMC_ATTRIBUTE_COLOR);
	glBindBuffer(GL_ARRAY_BUFFER, 0);

	glBindVertexArray(0);

const GLfloat fD_PositionArray[] = {
		fOffForD + fLetterWidth + fLetterWidth / 2, Yoff, 0.0f,
		fOffForD + fLetterWidth / 2, Yoff, 0.0f,
		fOffForD + fLetterWidth / 2, fHeight, 0.0f,
		fOffForD + fLetterWidth + fLetterWidth / 2, fHeight, 0.0f,
		fOffForD + 3 * fLetterWidth, Yoff, 0.0f,
		fOffForD, Yoff, 0.0f,
		fOffForD, Yoff - fLetterWidth, 0.0f,
		fOffForD + 3 * fLetterWidth, Yoff - fLetterWidth, 0.0f,
		fOffForD + 3 * fLetterWidth, Yoff, 0.0f,
		fOffForD + 2 * fLetterWidth, Yoff, 0.0f,
		fOffForD + 2 * fLetterWidth, fHeight, 0.0f,
		fOffForD + 3 * fLetterWidth, fHeight, 0.0f,
		fOffForD + 3 * fLetterWidth, fHeight + fLetterWidth, 0.0f,
		fOffForD, fHeight + fLetterWidth, 0.0f,
		fOffForD, fHeight, 0.0f,
		fOffForD + 3 * fLetterWidth, fHeight, 0.0f
	};

	const GLfloat fD_ColorArray[] = {
		SAFFRON, SAFFRON, GREEN, GREEN,
		SAFFRON, SAFFRON, SAFFRON, SAFFRON,
		SAFFRON, SAFFRON,GREEN, GREEN,
		GREEN, GREEN, GREEN, GREEN
	};

	glGenVertexArrays(1, &vao_D);
	glBindVertexArray(vao_D);

	glGenBuffers(1, &vbo_D_Position);
	glBindBuffer(GL_ARRAY_BUFFER, vbo_D_Position);
	glBufferData(GL_ARRAY_BUFFER, sizeof(fD_PositionArray), fD_PositionArray, GL_STATIC_DRAW);
	glVertexAttribPointer(AMC_ATTRIBUTE_POSITION, 3, GL_FLOAT, GL_FALSE, 0, NULL);
	glEnableVertexAttribArray(AMC_ATTRIBUTE_POSITION);
	glBindBuffer(GL_ARRAY_BUFFER, 0);

	glGenBuffers(1, &vbo_D_Color);
	glBindBuffer(GL_ARRAY_BUFFER, vbo_D_Color);
	glBufferData(GL_ARRAY_BUFFER, sizeof(fD_ColorArray), fD_ColorArray, GL_STATIC_DRAW);
	glVertexAttribPointer(AMC_ATTRIBUTE_COLOR, 3, GL_FLOAT, GL_FALSE, 0, NULL);
	glEnableVertexAttribArray(AMC_ATTRIBUTE_COLOR);
	glBindBuffer(GL_ARRAY_BUFFER, 0);

	glBindVertexArray(0);

	const GLfloat fLineI2Array[] =
	{
		fOffI2 + fLetterWidth + fWidth,Yoff, 0.0f,
		fOffI2 + fLetterWidth , Yoff, 0.0f,
		fOffI2 + fLetterWidth , fHeight, 0.0f,
		fOffI2 + fLetterWidth + fWidth, fHeight, 0.0f
	};

	const GLfloat fColor_I2_Array[] =
	{SAFFRON, SAFFRON, GREEN, GREEN};

	glGenVertexArrays(1, &vao_I2);
	glBindVertexArray(vao_I2);

	glGenBuffers(1, &vbo_I2_Position);
	glBindBuffer(GL_ARRAY_BUFFER, vbo_I2_Position);
	glBufferData(GL_ARRAY_BUFFER,
		sizeof(fLineI2Array),
		fLineI2Array,
		GL_STATIC_DRAW);

	glVertexAttribPointer(AMC_ATTRIBUTE_POSITION, 3, GL_FLOAT, GL_FALSE, 0, NULL);
	glEnableVertexAttribArray(AMC_ATTRIBUTE_POSITION);
	glBindBuffer(GL_ARRAY_BUFFER, 0);

	glGenBuffers(1, &vbo_I2_Color);
	glBindBuffer(GL_ARRAY_BUFFER, vbo_I2_Color);
	glBufferData(GL_ARRAY_BUFFER, sizeof(fColor_I2_Array), fColor_I2_Array, GL_STATIC_DRAW);
	glVertexAttribPointer(AMC_ATTRIBUTE_COLOR, 3, GL_FLOAT, GL_FALSE, 0, NULL);
	glEnableVertexAttribArray(AMC_ATTRIBUTE_COLOR);
	glBindBuffer(GL_ARRAY_BUFFER, 0);

	const GLfloat A_Position[] = {
		//1.563 + 2 * fLetterWidth + (fLetterWidth / 2), Yoff, 0.0f,
		1.163f + 2 * fLetterWidth + (fLetterWidth / 2), Yoff, 0.0f,
		1.163f + 2 * fLetterWidth - (fLetterWidth / 2), Yoff, 0.0f,
		1.163f, fHeight, 0.0f,
		1.163f + fLetterWidth, fHeight, 0.0f,
		1.163f + 4 * fLetterWidth, fHeight, 0.0f,
		1.163f + 2 * fLetterWidth + (fLetterWidth / 2), Yoff, 0.0f,
		1.163f + 2 * fLetterWidth - (fLetterWidth / 2), Yoff, 0.0f,
		1.163f + 3 * fLetterWidth, fHeight, 0.0f
	};

	const GLfloat A_Color[] = {SAFFRON, SAFFRON, GREEN, GREEN,
		GREEN, SAFFRON, SAFFRON, GREEN};

	glGenVertexArrays(1, &vao_A);
	glBindVertexArray(vao_A);

	glGenBuffers(1, &vbo_A_Position);
	glBindBuffer(GL_ARRAY_BUFFER, vbo_A_Position);
	glBufferData(GL_ARRAY_BUFFER, sizeof(A_Position), A_Position, GL_STATIC_DRAW);
	glVertexAttribPointer(AMC_ATTRIBUTE_POSITION, 3, GL_FLOAT, GL_FALSE, 0, NULL);

	glEnableVertexAttribArray(AMC_ATTRIBUTE_POSITION);
	glBindBuffer(GL_ARRAY_BUFFER, 0);

	glGenBuffers(1, &vbo_A_Color);
	glBindBuffer(GL_ARRAY_BUFFER, vbo_A_Color);
	glBufferData(GL_ARRAY_BUFFER, sizeof(A_Color), A_Color, GL_STATIC_DRAW);
	glVertexAttribPointer(AMC_ATTRIBUTE_COLOR, 3, GL_FLOAT, GL_FALSE, 0, 	NULL);
	glEnableVertexAttribArray(AMC_ATTRIBUTE_COLOR);
	glBindBuffer(GL_ARRAY_BUFFER, 0);


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

    vmath::mat4 modelViewMatrix = vmath::mat4::identity();
    vmath::mat4 modelViewProjectionMatrix = vmath::mat4::identity();

    modelViewMatrix = vmath::translate(0.0f, 0.0f, -5.0f);
    modelViewProjectionMatrix = perspectiveProjectionMatrix * modelViewMatrix;

    // uniforms are given to m_uv_matrix (i.e. model view matrix)
    glUniformMatrix4fv(mvpUniform, 1, GL_FALSE,  modelViewProjectionMatrix);

	glBindVertexArray(vao_I);
	glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
	glBindVertexArray(0);

    modelViewMatrix = vmath::mat4::identity();
    modelViewProjectionMatrix = vmath::mat4::identity();

    modelViewMatrix = vmath::translate(0.0f, 0.0f, -5.0f);
    modelViewProjectionMatrix = perspectiveProjectionMatrix * modelViewMatrix;

    glUniformMatrix4fv(mvpUniform, 1, GL_FALSE,  modelViewProjectionMatrix);

    glBindVertexArray(vao_N);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 4, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 8, 4);
    glBindVertexArray(0);

    // DRAWING LETTER 'D' 
	modelViewMatrix =  vmath::mat4::identity();
	modelViewProjectionMatrix =  vmath::mat4::identity();
	modelViewMatrix =  vmath::translate(0.0f, 0.0f, -5.0f);
	modelViewProjectionMatrix = perspectiveProjectionMatrix * modelViewMatrix;
	glUniformMatrix4fv(mvpUniform, 1, GL_FALSE, modelViewProjectionMatrix);

    glBindVertexArray(vao_D);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 4, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 8, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 12, 4);
    glBindVertexArray(0);

    // LETTER I 2nd TIME
    modelViewMatrix =  vmath::mat4::identity();
    modelViewProjectionMatrix =  vmath::mat4::identity();
    modelViewMatrix =  vmath::translate(0.0f, 0.0f, -5.0f);
    modelViewProjectionMatrix = perspectiveProjectionMatrix * modelViewMatrix;
    glUniformMatrix4fv(mvpUniform, 1, GL_FALSE, modelViewProjectionMatrix);

    glBindVertexArray(vao_I2);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    glBindVertexArray(0);

    // DRAWING LETTER 'A'
    modelViewMatrix =  vmath::mat4::identity();
    modelViewProjectionMatrix =  vmath::mat4::identity();
    modelViewMatrix =  vmath::translate(0.0f, 0.0f, -5.0f);
    modelViewProjectionMatrix = perspectiveProjectionMatrix * modelViewMatrix;

    // uniforms are given to m_uv_matrix (i.e. model view matrix)
    glUniformMatrix4fv(mvpUniform, 1, GL_FALSE, modelViewProjectionMatrix);
    glBindVertexArray(vao_A);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 4, 4);
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
    if(vbo_A_Color)
    {
        glDeleteBuffers(1, &vbo_A_Color);
        vbo_A_Color = 0;
    }

    if(vbo_A_Position)
    {
        glDeleteBuffers(1, &vbo_A_Position);
        vbo_A_Position = 0;
    }

    if(vao_A)
    {
        glDeleteVertexArrays(1, &vao_A);
        vao_A = 0;
    }

    if(vbo_I2_Color)
    {
        glDeleteBuffers(1, &vbo_I2_Color);
        vbo_I2_Color = 0;
    }

    if(vbo_I2_Position)
    {
        glDeleteBuffers(1, &vbo_I2_Position);
        vbo_I2_Position = 0;
    }

    if(vao_I2)
    {
        glDeleteVertexArrays(1, &vao_I2);
        vao_I2 = 0;
    }

    if(vbo_D_Color)
    {
        glDeleteBuffers(1, &vbo_D_Color);
        vbo_D_Color = 0;
    }

    if(vbo_D_Position)
    {
        glDeleteBuffers(1, &vbo_D_Position);
        vbo_D_Position = 0;
    }

    if(vao_D)
    {
        glDeleteVertexArrays(1, &vao_D);
        vao_D = 0;
    }

    if(vbo_N_Color)
    {
        glDeleteBuffers(1, &vbo_N_Color);
        vbo_N_Color = 0;
    }

    if(vbo_N_Position)
    {
        glDeleteBuffers(1, &vbo_N_Position);
        vbo_N_Position = 0;
    }

    if(vao_N)
    {
        glDeleteVertexArrays(1, &vao_N);
        vao_N = 0;
    }

    if(vbo_I_Color)
    {
        glDeleteBuffers(1, &vbo_I_Color);
        vbo_I_Color = 0;
    }

    if(vbo_I_Position)
    {
        glDeleteBuffers(1, &vbo_I_Position);
        vbo_I_Position = 0;
    }

    if(vao_I)
    {
        glDeleteVertexArrays(1, &vao_I);
        vao_I = 0;
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
