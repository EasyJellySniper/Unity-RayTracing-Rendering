# Unity RayTracing Rendering
 A simple demo shows how to customize your ray tracing shader.
 
![Imgur Image](https://i.imgur.com/HIZRbNT.png) <br>

Here is the step to customize your ray tracing shader: <br>
1. Create ray tracing shader, and write your ray generation/miss shader. <br>
2. Find a moment to call DispatchRays() so that your ray generation shader is be called. <br>
3. Write closest/any hit shader pass in your main shader (material) to handle the final shading. <br>
4. Of course you need Win10 + DirectX12. <br>
