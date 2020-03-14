//
// Created by shubham_at_astromedicomp on 12/21/19.
//

#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#import "GLESView.h"

#import "vmath.h"

float light_ambient[4] =  { 0.0f, 0.0f, 0.0f, 0.0f };
float light_diffused[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
float light_specular[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
float light_position[4] = { 100.0f, 100.0f, 100.0f, 1.0f};

float material_ambient[4] =  { 0.0f, 0.0f, 0.0f, 0.0f };
float material_diffused[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
float material_specular[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
float material_shineyness = 120.0f;


bool fragShader_sj = false;

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

    GLuint vao_sphere;
    GLuint vbo_sphere_position;
    GLuint vbo_sphere_elements;
    GLuint vbo_sphere_normals;

    GLuint uiModelMatrixUniform;
    GLuint uiViewMatrixUniform;
    GLuint uiProjectionUniform;

    vmath:: mat4 perspectiveProjectionMatrix;
    float fAngleRotate;

    GLuint laUniform;
    GLuint ldUniform;
    GLuint lsUniform;
    GLuint lightPositionVectorUniform;

    GLuint kaUniform;
    GLuint kdUniform;
    GLuint ksUniform;
    GLuint shineynessUniform;

    GLuint toggleForVertexAndFragment_sj;

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

            "uniform mat4 u_view_matrix;" \
            "uniform mat4 u_model_matrix;" \
            "uniform mat4 u_projection_matrix;" \
            "uniform int ui_is_lighting_key_pressed;" \

            "uniform vec4 u_light_position;" \
            "uniform int ui_is_vertex_or_fragment_light;" \

            "uniform vec3 u_la;" \
            "uniform vec3 u_ld;" \
            "uniform vec3 u_ls;" \

            "uniform vec3 u_ka;" \
            "uniform vec3 u_kd;" \
            "uniform vec3 u_ks;" \

            "uniform float u_material_shiney_ness;" \

            "out vec3 t_norm;" \
            "out vec3 viewer_vector;" \
            "out vec3 light_direction;" \
            "out vec3 phong_ads_light_vs;" \

            "void main(void)" \
            "{" \
                "vec4 eye_coordinates;" \
                "vec3 l_t_norm;" \
                "float tn_dot_ld;" \
                "vec3 l_light_direction;" \
                "vec3 l_viewer_vector;" \
                "vec3 reflection_vector;" \
                "vec3 ambient;" \
                "vec3 diffused;" \
                "vec3 specular;" \

                "if(ui_is_lighting_key_pressed == 1){" \
                    "eye_coordinates = u_view_matrix * u_model_matrix * v_position;" \
                    "t_norm = mat3(u_view_matrix * u_model_matrix) * v_normals;" \
                    "viewer_vector = vec3(-eye_coordinates);" \
                    "light_direction = vec3(u_light_position - eye_coordinates);" \

                    "if(ui_is_vertex_or_fragment_light == 1){" \
                        "l_t_norm = normalize(t_norm);" \
                        "l_light_direction	= normalize(light_direction);" \
                        "l_viewer_vector = normalize(viewer_vector);" \
                        "reflection_vector = reflect(-l_light_direction, l_t_norm);" \
                        "tn_dot_ld = max(dot(l_light_direction, l_t_norm), 0.0);" \
                        "ambient = u_la * u_ka;" \
                        "diffused = u_ld * u_kd * tn_dot_ld;" \
                        "specular = u_ls * u_ks * " \
                            "pow(max(dot(reflection_vector," \
                            "l_viewer_vector), 0.0), u_material_shiney_ness);" \
                        "phong_ads_light_vs = ambient + diffused + specular;" \
                        "}" \

                    "}" \

                "gl_Position = u_projection_matrix * u_view_matrix * u_model_matrix * v_position;" \
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

        "in vec3 t_norm;" \
        "in vec3 phong_ads_light_vs;" \

        "in vec3 light_direction;" \
        "in vec3 viewer_vector;" \

        "out vec4 v_frag_color;" \

        "uniform vec3 u_la;" \
        "uniform vec3 u_ld;" \
        "uniform vec3 u_ls;" \
        "uniform vec3 u_ka;" \
        "uniform vec3 u_kd;" \
        "uniform vec3 u_ks;" \

        "uniform float u_material_shiney_ness;" \
        "uniform int ui_is_lighting_key_pressed;" \
        "uniform int ui_is_vertex_or_fragment_light;" \

        "void main(void)" \
        "{" \
            "vec3 ambient;" \
            "vec3 specular;" \
            "vec3 l_t_norm;" \
            "vec3 diffused;" \
            "float tn_dot_ld;" \
            "vec3 phong_ads_light;" \
            "vec3 l_viewer_vector;" \
            "vec3 reflection_vector;" \
            "vec3 l_light_direction;" \

            "if(ui_is_lighting_key_pressed == 1){" \

                "if(1 == ui_is_vertex_or_fragment_light)" \
                "{" \
                    "v_frag_color = vec4(phong_ads_light_vs, 1.0);" \
                "}" \
                "else{" \
                    "l_t_norm = normalize(t_norm);" \
                    "l_light_direction	= normalize(light_direction);" \
                    "l_viewer_vector = normalize(viewer_vector);" \
                    "reflection_vector = reflect(-l_light_direction, l_t_norm);" \
                    "tn_dot_ld = max(dot(l_light_direction, l_t_norm), 0.0);" \
                    "ambient = u_la * u_ka;" \
                    "diffused = u_ld * u_kd * tn_dot_ld;" \

                    "specular = u_ls * u_ks * " \
                        "pow(max(dot(reflection_vector," \
                        "l_viewer_vector), 0.0), u_material_shiney_ness);" \

                    "phong_ads_light = ambient + diffused + specular;" \
                    "v_frag_color = vec4(phong_ads_light, 1.0);" \
                "}" \
            "}" \
            "else{" \
                "v_frag_color = vec4(1.0, 1.0, 1.0, 1.0);" \
            "}" \
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

        uiModelMatrixUniform = glGetUniformLocation(
            shaderProgramObject,
            "u_model_matrix"
        );

        uiViewMatrixUniform = glGetUniformLocation(
            shaderProgramObject,
            "u_view_matrix"
        );

        uiProjectionUniform = glGetUniformLocation(
            shaderProgramObject,
            "u_projection_matrix"
        );

        laUniform = glGetUniformLocation(
            shaderProgramObject,
            "u_la"
        );

        ldUniform = glGetUniformLocation(
            shaderProgramObject,
            "u_ld"
        );

        lsUniform = glGetUniformLocation(
            shaderProgramObject,
            "u_ls"
        );

        lightPositionVectorUniform = glGetUniformLocation(
            shaderProgramObject,
            "u_light_position"
        );

        kaUniform = glGetUniformLocation(
            shaderProgramObject,
            "u_ka"
        );

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

        uiKeyOfLightsIsPressed =
            glGetUniformLocation(
                shaderProgramObject,
                "ui_is_lighting_key_pressed"
            );

        toggleForVertexAndFragment_sj =
        glGetUniformLocation(
            shaderProgramObject, "ui_is_vertex_or_fragment_light"
    );

        int slices = 50;
        int stacks = 50;
        [self mySphereWithRadius:1.0 slices:slices stacks:stacks];

        int vertexCount = (slices + 1) * (stacks + 1);

        glGenVertexArrays(1, &vao_sphere);
        glBindVertexArray(vao_sphere);

        glGenBuffers(1, &vbo_sphere_position);
        glBindBuffer(GL_ARRAY_BUFFER, vbo_sphere_position);
        glBufferData(
                        GL_ARRAY_BUFFER,
                        3 * vertexCount * sizeof(float),
                        fSpherePositions,
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

        glGenBuffers(1, &vbo_sphere_elements);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo_sphere_elements);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, gNumElements * sizeof(int), indices, GL_STATIC_DRAW);

        // normals
        glGenBuffers(1, &vbo_sphere_normals);
        glBindBuffer(GL_ARRAY_BUFFER, vbo_sphere_normals);
        glBufferData(GL_ARRAY_BUFFER,
            3 * vertexCount * sizeof(float),
            fSphereNormals,
            GL_STATIC_DRAW);

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

-(void)mySphereWithRadius:(float)radius slices:(int)slices stacks:(int)stacks
{
    int vertexCount = (slices + 1)*(stacks + 1);
    gNumElements = 2 * slices*stacks * 3;

    fSpherePositions = (float *)malloc(3 * vertexCount * sizeof(float));
    fSphereNormals = (float *)malloc(3 * vertexCount * sizeof(float));
    fSphereTexturesCoords = (float *)malloc(2 * vertexCount * sizeof(float));
    indices = (int *)malloc(gNumElements * sizeof(int));

    float du = 2 * M_PI / slices;
    float dv = M_PI / stacks;

    int indexV = 0;
    int indexT = 0;

    float u, v, x, y, z;
    int i, j, k;
    for (i = 0; i <= stacks; i++)
    {
        v = -M_PI / 2 + i * dv;
        for (j = 0; j <= slices; j++)
        {
            u = j * du;
            x = cos(u) * cos(v);
            y = sin(u) * cos(v);
            z = sin(v);
            fSpherePositions[indexV] = radius * x;
            fSphereNormals[indexV++] = x;
            fSpherePositions[indexV] = radius * y;
            fSphereNormals[indexV++] = y;
            fSpherePositions[indexV] = radius * z;
            fSphereNormals[indexV++] = z;
            fSphereTexturesCoords[indexT++] = j / slices;
            fSphereTexturesCoords[indexT++] = i / stacks;
        }
    }

    k = 0;
    for (j = 0; j < stacks; j++)
    {
        int row1 = j * (slices + 1);
        int row2 = (j + 1)*(slices + 1);
        for (i = 0; i < slices; i++)
        {
            indices[k++] = row1 + i;
            indices[k++] = row2 + i + 1;
            indices[k++] = row2 + i;
            indices[k++] = row1 + i;
            indices[k++] = row1 + i + 1;
            indices[k++] = row2 + i + 1;
        }
    }

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

    vmath::mat4 modelMatrix = vmath::mat4::identity();
    vmath::mat4 viewMatrix = vmath::mat4::identity();
    vmath::mat4 rotateMatrix = vmath::mat4::identity();
    vmath::mat4 modelViewProjectionMatrix = vmath::mat4::identity();

    modelMatrix = vmath::translate(0.0f, 0.0f, -5.0f);

    glUniformMatrix4fv(uiModelMatrixUniform,
            1,
            GL_FALSE,
            modelMatrix
        );

    glUniformMatrix4fv(uiViewMatrixUniform,
        1,
        GL_FALSE,
        viewMatrix);

    glUniformMatrix4fv(uiProjectionUniform,
        1,
        GL_FALSE,
        perspectiveProjectionMatrix);

    if (true == boKeyOfLightsIsPressed)
    {
        glUniform1i(uiKeyOfLightsIsPressed, 1);
        glUniform4f(lightPositionVectorUniform, 100.0f, 100.0f, 100.0f, 1.0f);
        
        glUniform3fv(laUniform, 1, light_ambient);
        glUniform3fv(lsUniform, 1, light_specular);
        glUniform3fv(ldUniform, 1, light_diffused);
        
        glUniform3fv(kaUniform, 1, material_ambient);
        glUniform3fv(kdUniform, 1, material_diffused);
        glUniform3fv(ksUniform, 1, material_specular);
        glUniform1f(shineynessUniform, material_shineyness);

        if (true == fragShader_sj)
        {
            glUniform1i(toggleForVertexAndFragment_sj, 0);
        }
        else
        {
            glUniform1i(toggleForVertexAndFragment_sj, 1);
        }

    }
    else
    {
        glUniform1i(uiKeyOfLightsIsPressed, 0);
    }

    glBindVertexArray(vao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo_sphere_elements);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_INT, 0);
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
    fragShader_sj = true;
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
    fragShader_sj = false;
}

- (void)dealloc
{
    // code
    free(fSpherePositions);
    fSpherePositions = NULL;
    free(fSphereNormals);
    fSphereNormals = NULL;
    free(fSphereTexturesCoords);
    fSphereTexturesCoords = NULL;
    free(indices);
    indices = NULL;

    if(vbo_sphere_position)
    {
        glDeleteBuffers(1, &vbo_sphere_position);
        vbo_sphere_position = 0;
    }

    if(vbo_sphere_elements)
    {
        glDeleteBuffers(1, &vbo_sphere_elements);
        vbo_sphere_elements = 0;
    }

    if(vbo_sphere_normals)
    {
        glDeleteBuffers(1, &vbo_sphere_normals);
        vbo_sphere_normals = 0;
    }

    if (vao_sphere)
    {
        glDeleteVertexArrays(1, &vao_sphere);
        vao_sphere = 0;
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
