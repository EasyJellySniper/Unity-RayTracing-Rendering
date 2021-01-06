# Unity RayTracing Rendering
A simple demo shows how to customize your ray tracing shader in Unity. <br>
This demo is written on Unity 2019.4.7f1. <br>
And this is different work from my D3D12 demo before, this all works with Unity's component without any customized native DLL.
 
![Imgur Image](https://i.imgur.com/HIZRbNT.png) <br>

Here is the step to customize your ray tracing shader: <br>
1. Create ray tracing shader, and write your ray generation/miss shader. <br>
2. Find a moment to call DispatchRays() so that your ray generation shader is be called. <br>
3. Write closest/any hit shader pass in your main shader (material) to handle the final shading. <br>
4. Of course you need Win10 + DirectX12. <br>

<br>
In my simple demo, I attach RayTracingInstance.cs to the mesh renderer I want trace. <br>
And I attach RayTracingManager.cs to main camera, it will create output rendertextures, acceleration structures (AS) for ray tracing instances. <br>
I simply build AS to two groups: one for opaque/cutoff geometry another one for transparent. <br>
Calling DispatchRays() twice, one for reflection pass, one for final shading. <br>
Calling GenerateMips() on reflection output so that I can blur reflection when calculating the PBR. <br>

<br>
During the ray tracing process, I call TraceRay() twice. One for opaque/cutoff geometry & another one for transparent geometry. <br>
Because if you want to alpha blending for transparent geometry, you need a exist opaque image. <br>
This is why I call TraceRay() twice, you can't handle it with only one pass with just payload. <br>

<br>
At last, final shading is compleleted and blit to Unity's screen. <br>
Note that you need to use SampleLevel() instead of Sample() in DXR shader. Because DXR works like compute shader. <br>
I use a simple distance-to-miplevel method to simulate mipmapping on distant pixels. <br>
It's not the best but the simplest solution. <br>
