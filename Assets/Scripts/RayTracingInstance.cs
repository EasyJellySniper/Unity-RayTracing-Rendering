using UnityEngine;

/// <summary>
/// renderer ray tracing instance
/// </summary>
[RequireComponent(typeof(Renderer))]
public class RayTracingInstance : MonoBehaviour
{
    /// <summary>
    /// mesh renderer
    /// </summary>
    public MeshRenderer meshRenderer;

    /// <summary>
    /// is changed?
    /// </summary>
    public bool isChanged = false;

    /// <summary>
    /// unity start
    /// </summary>
    private void Awake()
    {
        meshRenderer = GetComponent<MeshRenderer>();
    }

    /// <summary>
    /// late update
    /// </summary>
    private void Update()
    {
        if (transform.hasChanged)
        {
            isChanged = true;
        }

        transform.hasChanged = false;
    }
}
