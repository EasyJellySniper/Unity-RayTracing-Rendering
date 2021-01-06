using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// create demo sphere
/// </summary>
public class CreateDemoSphere : MonoBehaviour
{
    /// <summary>
    /// target
    /// </summary>
    public GameObject target;

    /// <summary>
    /// test mat array
    /// </summary>
    public Material[] testMatArray;

    /// <summary>
    /// size
    /// </summary>
    public float areaSize = 100f;

    /// <summary>
    /// margin size
    /// </summary>
    public float marginSize = 10f;

    /// <summary>
    /// start
    /// </summary>
    private void Awake()
    {
        if (!target || testMatArray.Length == 0)
        {
            Debug.LogError("Missing target or material");
            enabled = false;
            return;
        }

        int sphereCount = Mathf.CeilToInt(areaSize / marginSize);
        int sphereMat = 0;

        for (int i = 0; i < sphereCount; i++)
        {
            for (int j = 0; j < sphereCount; j++)
            {
                GameObject newSphere = Instantiate(target);
                newSphere.name = "Demo Sphere";
                newSphere.transform.SetParent(transform);
                newSphere.transform.localPosition = new Vector3(-areaSize * 0.5f + i * marginSize, target.transform.position.y, -areaSize * 0.5f + j * marginSize);
                newSphere.AddComponent<RayTracingInstance>();

                // setup material
                newSphere.GetComponent<MeshRenderer>().sharedMaterial = testMatArray[sphereMat];
                sphereMat = (sphereMat + 1) % testMatArray.Length;
            }
        }
    }
}
