using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;
using UnityEngine.SceneManagement;
using System.Collections.Generic;

/// <summary>
/// ray tracing manager
/// </summary>
[RequireComponent(typeof(Camera))]
public class RayTracingManager : MonoBehaviour
{
    /// <summary>
    /// ray tracing shader
    /// </summary>
    public RayTracingShader rtShader;

    /// <summary>
    /// ray tracing output
    /// </summary>
    public RenderTexture rayTracingOutput;

    /// <summary>
    /// reflection output
    /// </summary>
    public RenderTexture reflectionOutput;

    /// <summary>
    /// skybox for clear
    /// </summary>
    public Cubemap clearSkybox;

    /// <summary>
    /// main cam
    /// </summary>
    private Camera mainCam;

    /// <summary>
    /// ray tracing cb
    /// </summary>
    private CommandBuffer rayTracingCB;

    /// <summary>
    /// scene AS
    /// </summary>
    private RayTracingAccelerationStructure sceneAS;

    /// <summary>
    /// ray tracing instance list
    /// </summary>
    private List<RayTracingInstance> rayTracingInstanceList;

    /// <summary>
    /// ray event
    /// </summary>
    private CameraEvent rayEvent = CameraEvent.AfterDepthTexture;

    /// <summary>
    /// start
    /// </summary>
    private void Start()
    {
        if (!rtShader)
        {
            Debug.LogError("No ray tracing shader is set.");
            enabled = false;
            return;
        }

        // use depth texture for saving first ray
        mainCam = GetComponent<Camera>();
        mainCam.depthTextureMode = DepthTextureMode.Depth;

        // create ray tracing AS for each renderers
        CreateSceneAS();

        // create ray tracing RT/CB
        CreateRayTracingRTCB();
    }

    /// <summary>
    /// on enable
    /// </summary>
    private void OnEnable()
    {
        if (rayTracingCB != null)
        {
            mainCam.RemoveCommandBuffer(rayEvent, rayTracingCB);
            mainCam.AddCommandBuffer(rayEvent, rayTracingCB);
        }
    }

    /// <summary>
    /// on disable
    /// </summary>
    private void OnDisable()
    {
        if (rayTracingCB != null)
        {
            mainCam.RemoveCommandBuffer(rayEvent, rayTracingCB);
        }
    }

    /// <summary>
    /// ondestroy
    /// </summary>
    private void OnDestroy()
    {
        if (rayTracingCB != null)
        {
            rayTracingCB.Release();
        }

        if (sceneAS != null)
        {
            sceneAS.Release();
            sceneAS.Dispose();
        }

        if (rayTracingInstanceList != null)
        {
            rayTracingInstanceList.Clear();
        }

        if (rayTracingOutput)
        {
            rayTracingOutput.Release();
            DestroyImmediate(rayTracingOutput);
        }

        if (reflectionOutput)
        {
            reflectionOutput.Release();
            DestroyImmediate(reflectionOutput);
        }
    }

    /// <summary>
    /// onrenderimage
    /// </summary>
    /// <param name="_source"> src </param>
    /// <param name="_destination"> dest </param>
    private void OnRenderImage(RenderTexture _source, RenderTexture _destination)
    {
        if (rayTracingOutput)
        {
            Graphics.Blit(rayTracingOutput, _destination);
        }
        else
        {
            Graphics.Blit(_source, _destination);
        }
    }

    /// <summary>
    /// late update
    /// </summary>
    private void LateUpdate()
    {
        if (rayTracingInstanceList != null)
        {
            foreach (var rti in rayTracingInstanceList)
            {
                if (rti.isChanged)
                {
                    // update AS transform if necessary
                    sceneAS.UpdateInstanceTransform(rti.meshRenderer);
                    rti.isChanged = false;
                }
            }
        }
    }

    /// <summary>
    /// on pre cull
    /// </summary>
    private void OnPreCull()
    {
        Matrix4x4 view = mainCam.worldToCameraMatrix;
        Matrix4x4 proj = GL.GetGPUProjectionMatrix(mainCam.projectionMatrix, true);
        Matrix4x4 viewProj = proj * view;
        Shader.SetGlobalMatrix("_InvViewProj", viewProj.inverse);

        Vector4 camPos = Vector4.zero;
        camPos = transform.position;
        camPos.w = mainCam.farClipPlane;
        Shader.SetGlobalVector("_CustomCameraSpacePos", camPos);
    }

    /// <summary>
    /// create scene AS
    /// </summary>
    private void CreateSceneAS()
    {
        sceneAS = new RayTracingAccelerationStructure();

        // get all ray tracing instance from this scene
        Scene scene = gameObject.scene;
        var rootObjs = scene.GetRootGameObjects();

        // collect scene ray tracing instance
        rayTracingInstanceList = new List<RayTracingInstance>();
        foreach (var ro in rootObjs)
        {
            rayTracingInstanceList.AddRange(ro.GetComponentsInChildren<RayTracingInstance>());
        }

        // create ray tracing instance
        foreach (var rti in rayTracingInstanceList)
        {
            // do not use culling, I will culling in shader
            bool[] submeshTransparent = new bool[1];
            submeshTransparent[0] = rti.meshRenderer.sharedMaterial.renderQueue > 2225; // mark as transparency if render queue is large than cutout start
            bool hasDepth = rti.meshRenderer.sharedMaterial.renderQueue <= (int)RenderQueue.GeometryLast;

            if (hasDepth)
            {
                sceneAS.AddInstance(rti.meshRenderer, null, submeshTransparent, true, false, 0x01);
            }
            else
            {
                sceneAS.AddInstance(rti.meshRenderer, null, submeshTransparent, true, false, 0x02);
            }
        }
    }

    /// <summary>
    /// create ray tracing CB
    /// </summary>
    private void CreateRayTracingRTCB()
    {
        // create ray tracing output
        rayTracingOutput = new RenderTexture(mainCam.pixelWidth, mainCam.pixelHeight, 0, DefaultFormat.HDR);
        rayTracingOutput.name = "Ray tracing output";
        rayTracingOutput.enableRandomWrite = true;
        rayTracingOutput.Create();

        // create reflection output
        reflectionOutput = new RenderTexture(mainCam.pixelWidth, mainCam.pixelHeight, 0, DefaultFormat.HDR);
        reflectionOutput.name = "Ray tracing reflection";
        reflectionOutput.enableRandomWrite = true;
        reflectionOutput.useMipMap = true;
        reflectionOutput.autoGenerateMips = false;
        reflectionOutput.Create();

        // ray tracing command buffer
        rayTracingCB = new CommandBuffer();
        rayTracingCB.name = "Ray Tracing CB";

        // AS
        rayTracingCB.BuildRayTracingAccelerationStructure(sceneAS);
        rayTracingCB.SetRayTracingAccelerationStructure(rtShader, "_SceneAS", sceneAS);

        // bind skybox & closest shader
        if (clearSkybox)
        {
            rayTracingCB.SetGlobalTexture("_ClearSkybox", clearSkybox);
        }
        rayTracingCB.SetRayTracingShaderPass(rtShader, "MyClosestHit");

        // reflection ray
        rayTracingCB.SetRayTracingTextureParam(rtShader, "_ReflectionOutput", reflectionOutput);
        rayTracingCB.DispatchRays(rtShader, "MyReflectionShader", (uint)rayTracingOutput.width, (uint)rayTracingOutput.height, 1);
        rayTracingCB.GenerateMips(reflectionOutput);

        // forward pass ray
        rayTracingCB.SetRayTracingTextureParam(rtShader, "_Output", rayTracingOutput);
        rayTracingCB.SetGlobalTexture("_ReflectionRT", reflectionOutput);
        rayTracingCB.DispatchRays(rtShader, "MyRaygenShader", (uint)rayTracingOutput.width, (uint)rayTracingOutput.height, 1);

        // setup cmd
        mainCam.RemoveCommandBuffer(rayEvent, rayTracingCB);
        mainCam.AddCommandBuffer(rayEvent, rayTracingCB);
    }
}
