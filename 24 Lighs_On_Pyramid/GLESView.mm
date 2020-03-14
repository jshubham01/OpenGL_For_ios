//
// Created by shubham_at_astromedicomp on 12/21/19.
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

float fAngleRotate = 0.0f;

@implementation GLESView
{
    EAGLContext *eaglContext;

    GLuint defaultFramebuffer;
    GLuint colorRenderbuffer;
    GLuint depthRenderbuffer;

    GLuint vertexShaderObject;
    GLuint fragmentShaderObject;
    GLuint shaderProgramObject;

    GLuint vao_pyramid_sj;
    GLuint vbo_position_pyr_sj;
    GLuint vbo_normals_pyramid_sj;

    GLuint uiModelViewUniform_sj;
    GLuint uiProjectionUniform;

    vmath:: mat4 perspectiveProjectionMatrix;

    GLuint laUniform_left_sj;
    GLuint ldUniform_left_sj;
    GLuint lsUniform_left_sj;
    GLuint lightPositionVectorUniform_sj_left_sj;

    GLuint laUniform_right_sj;
    GLuint ldUniform_right_sj;
    GLuint lsUniform_right_sj;
    GLuint lightPositionVectorUniform_sj_right_sj;

    GLuint kaUniform;
    GLuint kdUniform;
    GLuint ksUniform;
    GLuint shineynessUniform;

    bool boKeyOfLightsIsPressed;
    GLuint uiKeyOfLightsIsPressed;

    float   *fSpherePositions;
    float   *fSphereNormals;
    float   *fSphereTexturesCoords;
    int     *indices;
    int gNumElements;

    GLint width;
    GLint height;
    id displayLink;
    NSInteger animationFrameInterval;
    BOOL isAnimating;
}

-(id)initWithFrame:(CGRect)frame
{
    // code
    boKeyOfLightsIsPressed = false;

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
            "in vec4 v_position;" \
            "in vec3 v_normals;" \

            "uniform mat4 u_model_view_mat;" \
            "uniform mat4 u_model_projection_mat;" \

            "uniform int ui_is_lighting_key_pressed;" \

            "uniform vec3 u_la_left;" \
            "uniform vec3 u_ld_left;" \
            "uniform vec3 u_ls_left;" \
            "uniform vec4 u_light_position_left;" \

            "uniform vec3 u_la_right;" \
            "uniform vec3 u_ld_right;" \
            "uniform vec3 u_ls_right;" \
            "uniform vec4 u_light_position_right;" \

            "uniform vec3 u_ka;" \
            "uniform vec3 u_kd;" \
            "uniform vec3 u_ks;" \
            "uniform float u_material_shiney_ness;" \

            "out vec3 phong_ads_light;" \

            "void main(void)" \
            "{" \

                "vec3 ambient;" \
                "vec3 diffused;" \
                "vec3 specular;" \
                "vec3 t_norm; " \
                "vec3 viewer_vector;" \
                "vec4 eye_coordinates;" \

                "float tn_dot_ld_right;" \
                "vec3 light_direction_right;" \
                "vec3 reflection_vector_right;" \

                "float tn_dot_ld_left;" \
                "vec3 light_direction_left;" \
                "vec3 reflection_vector_left;" \

                "if(ui_is_lighting_key_pressed == 1){" \
                    "eye_coordinates = u_model_view_mat * v_position;" \
                    "mat3 normal_matrix = mat3(transpose(inverse(u_model_view_mat)));" \
                    "t_norm = normalize(normal_matrix * v_normals);" \
                    "viewer_vector = normalize(vec3(-eye_coordinates));" \

                    "light_direction_right = normalize(vec3(u_light_position_right - eye_coordinates));" \
                    "tn_dot_ld_right = max(dot(light_direction_right, t_norm), 0.0);" \
                    "reflection_vector_right = reflect(-light_direction_right, t_norm);" \

                    "light_direction_left = normalize(vec3(u_light_position_left - eye_coordinates));" \
                    "tn_dot_ld_left = max(dot(light_direction_left, t_norm), 0.0);" \
                    "reflection_vector_left = reflect(-light_direction_left, t_norm);" \

                    "ambient = u_la_right * u_ka;" \
                    "diffused = u_ld_right * u_kd * tn_dot_ld_right;" \
                    "specular = u_ls_right * u_ks * " \
                    "pow(max(dot(reflection_vector_right, viewer_vector), 0.0), u_material_shiney_ness);" \

                    "phong_ads_light = ambient + diffused + specular;" \

                    "ambient = u_la_left * u_ka;" \
                    "diffused = u_ld_left * u_kd * tn_dot_ld_left;" \
                    "specular = u_ls_left * u_ks * " \
                    "pow(max(dot(reflection_vector_left, viewer_vector), 0.0), u_material_shiney_ness);" \

                    "phong_ads_light = phong_ads_light + ambient + diffused + specular;" \
                "}" \
                "else{" \
                    "phong_ads_light = vec3(1.0, 1.0, 1.0);" \
                "}"

                "gl_Position = u_model_projection_mat * u_model_view_mat * v_position;" \

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
        "precision highp int;" \

        "in vec3 phong_ads_light;" \
        "out vec4 v_frag_color;" \

        "void main(void)" \
        "{" \
            "v_frag_color = vec4(phong_ads_light, 1.0);" \
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
            "v_position");

        glBindAttribLocation(shaderProgramObject,
            AMC_ATTRIBUTE_NORMAL,
            "v_normals");

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

        uiModelViewUniform_sj = glGetUniformLocation(
            shaderProgramObject,
            "u_model_view_mat"
        );

        // uiViewMatrixUniform = glGetUniformLocation(
        //     shaderProgramObject,
        //     "u_view_matrix"
        // );

        uiProjectionUniform = glGetUniformLocation(
            shaderProgramObject,
            "u_model_projection_mat"
        );

        uiKeyOfLightsIsPressed = glGetUniformLocation(
                shaderProgramObject,
                "ui_is_lighting_key_pressed"
            );

        laUniform_left_sj = glGetUniformLocation(
            shaderProgramObject,
            "u_la_left"
        );

        ldUniform_left_sj = glGetUniformLocation(
            shaderProgramObject,
            "u_ld_left"
        );

        lsUniform_left_sj = glGetUniformLocation(
            shaderProgramObject,
            "u_ls_left"
        );

        lightPositionVectorUniform_sj_left_sj = glGetUniformLocation(
            shaderProgramObject,
            "u_light_position_left"
        );

        kaUniform = glGetUniformLocation(
            shaderProgramObject,
            "u_ka"
        );

        lightPositionVectorUniform_sj_right_sj = glGetUniformLocation(shaderProgramObject, "u_light_position_right");
        laUniform_right_sj = glGetUniformLocation(shaderProgramObject, "u_la_right");
        ldUniform_right_sj = glGetUniformLocation(shaderProgramObject, "u_ld_right");
        lsUniform_right_sj = glGetUniformLocation(shaderProgramObject, "u_ls_right");

        kdUniform = 
            glGetUniformLocation(
                shaderProgramObject,
                "u_kd"
            );

        ksUniform = 
            glGetUniformLocation(
                shaderProgramObject,
                "u_ks"
            );

        shineynessUniform = 
            glGetUniformLocation(
            shaderProgramObject,
            "u_material_shiney_ness"
        );


    const GLfloat fCubePositions[] =
                    {
                        0.0f, 1.0f, 0.0f, 	-1.0f, -1.0f, 1.0f, 	1.0f, -1.0f, 1.0f,
                        0.0f, 1.0f, 0.0f, 	1.0f, -1.0f, 1.0f,	1.0f, -1.0f, -1.0f,
                        0.0f, 1.0f, 0.0f, 	1.0f, -1.0f, -1.0f,  -1.0f, -1.0f, -1.0f,
                        0.0f, 1.0f, 0.0f, -1.0f, -1.0f, -1.0f, 	-1.0f, -1.0f, 1.0f
                    };

    const GLfloat fCubeNormals[] =
    {
                0.0f, 0.447214f, 0.894427f,
                0.0f, 0.447214f, 0.894427f,
                0.0f, 0.447214f, 0.894427f,

                0.894427f, 0.447214f, 0.0f,
                0.894427f, 0.447214f, 0.0f,
                0.894427f, 0.447214f, 0.0f,

                0.0f, 0.447214f, -0.894427f,
                0.0f, 0.447214f, -0.894427f,
                0.0f, 0.447214f, -0.894427f,

                -0.894427f, 0.447214f, 0.0f,
                -0.894427f, 0.447214f, 0.0f,
                -0.894427f, 0.447214f, 0.0f
    };

        glGenVertexArrays(1, &vao_pyramid_sj);
        glBindVertexArray(vao_pyramid_sj);

        glGenBuffers(1, &vbo_position_pyr_sj);
        glBindBuffer(GL_ARRAY_BUFFER, vbo_position_pyr_sj);
        glBufferData(
                        GL_ARRAY_BUFFER,
                        sizeof(fCubePositions),
                        fCubePositions,
                        GL_STATIC_DRAW
                    );

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

        // glGenBuffers(1, &vbo_sphere_elements);
        // glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo_sphere_elements);
        // glBufferData(GL_ELEMENT_ARRAY_BUFFER, gNumElements * sizeof(int), indices, GL_STATIC_DRAW);

        // normals
        glGenBuffers(1, &vbo_normals_pyramid_sj);
        glBindBuffer(GL_ARRAY_BUFFER, vbo_normals_pyramid_sj);
        glBufferData(GL_ARRAY_BUFFER,
             sizeof(fCubeNormals),
             fCubeNormals,
             GL_STATIC_DRAW
            );

        glVertexAttribPointer(
            AMC_ATTRIBUTE_NORMAL,
            3,
            GL_FLOAT,
            GL_FALSE,
            0, 
            NULL
        );

        glEnableVertexAttribArray(AMC_ATTRIBUTE_NORMAL);
        glBindBuffer(GL_ARRAY_BUFFER, 0);

        glBindVertexArray(0);

        glEnable(GL_DEPTH_TEST);
        glDepthFunc(GL_LEQUAL);
        // glEnable(GL_CULL_FACE);
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClearDepthf(1.0f);

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
    // vmath::mat4 viewMatrix = vmath::mat4::identity();
    vmath::mat4 rotateMatrix = vmath::mat4::identity();
    vmath::mat4 modelViewProjectionMatrix = vmath::mat4::identity();

    modelViewMatrix = vmath::translate(0.0f, 0.0f, -5.0f);
    rotateMatrix = vmath::rotate(fAngleRotate, 0.0f, 1.0f, 0.0f);
    modelViewMatrix = modelViewMatrix * rotateMatrix;

    glUniformMatrix4fv(uiModelViewUniform_sj,
            1,
            GL_FALSE,
            modelViewMatrix
        );
    
    glUniformMatrix4fv(uiProjectionUniform,
        1,
        GL_FALSE,
        perspectiveProjectionMatrix);
    
    if (true == boKeyOfLightsIsPressed)
    {
        glUniform1i(uiKeyOfLightsIsPressed, 1);

        glUniform4f(lightPositionVectorUniform_sj_left_sj, -2.0f, 0.0f, 0.0f, 1.0f);
        glUniform3f(laUniform_left_sj, 0.0f, 0.0f, 0.0f);
        glUniform3f(lsUniform_left_sj, 1.0f, 0.0f, 0.0f);
        glUniform3f(ldUniform_left_sj, 1.0f, 0.0f, 0.0f);

        glUniform4f(lightPositionVectorUniform_sj_right_sj, 2.0f, 0.0f, 0.0f, 1.0f);
        glUniform3f(laUniform_right_sj, 0.0f, 0.0f, 0.0f);
        glUniform3f(lsUniform_right_sj, 0.0f, 0.0f, 1.0f);
        glUniform3f(ldUniform_right_sj, 0.0f, 0.0f, 1.0f);

        glUniform3f(kaUniform, 0.0f, 0.0f, 0.0f);
        glUniform3f(kdUniform, 1.0f, 1.0f, 1.0f);
        glUniform3f(ksUniform, 1.0f, 1.0f, 1.0f);
        glUniform1f(shineynessUniform, 100.0f);
    }
    else
    {
        glUniform1i(uiKeyOfLightsIsPressed, 0);
    }

    glBindVertexArray(vao_pyramid_sj);
    glDrawArrays(GL_TRIANGLES, 0, 12);
    glBindVertexArray(0);
    glUseProgram(0); 

    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    [eaglContext presentRenderbuffer:GL_RENDERBUFFER];

    fAngleRotate += 0.1f;
    if (fAngleRotate > 360.0f)
    {
        fAngleRotate = 0.0f;
    }
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
    if (true == boKeyOfLightsIsPressed)
    {
        boKeyOfLightsIsPressed = false;
    }
    else
    {
        boKeyOfLightsIsPressed = true;
    }

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
    if(vbo_position_pyr_sj)
    {
        glDeleteBuffers(1, &vbo_position_pyr_sj);
        vbo_position_pyr_sj = 0;
    }

    if(vbo_normals_pyramid_sj)
    {
        glDeleteBuffers(1, &vbo_normals_pyramid_sj);
        vbo_normals_pyramid_sj = 0;
    }

    if (vao_pyramid_sj)
    {
        glDeleteVertexArrays(1, &vao_pyramid_sj);
        vao_pyramid_sj = 0;
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
