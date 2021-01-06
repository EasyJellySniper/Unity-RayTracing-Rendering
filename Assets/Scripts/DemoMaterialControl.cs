using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// demo material control
/// </summary>
public class DemoMaterialControl : MonoBehaviour
{
    /// <summary>
    /// emission mats
    /// </summary>
    public Material[] emissionMats;

    /// <summary>
    /// glow speed
    /// </summary>
    public float glowSpeed = 5;

    /// <summary>
    /// origin emission color
    /// </summary>
    private Color[] originEmissionColor;

    /// <summary>
    /// timer
    /// </summary>
    private float timer = 0f;

    /// <summary>
    /// glow factor
    /// </summary>
    private float glowFactor;

    /// <summary>
    /// start
    /// </summary>
    private void Start()
    {
        if (emissionMats.Length != 0)
        {
            originEmissionColor = new Color[emissionMats.Length];
            for (int i = 0; i < emissionMats.Length; i++)
            {
                originEmissionColor[i] = emissionMats[i].GetColor("_EmissionColor");
            }
        }

        timer = 0.5f;
        glowFactor = 1f;
    }

    /// <summary>
    /// disable
    /// </summary>
    private void OnDisable()
    {
        if (emissionMats.Length != 0)
        {
            for (int i = 0; i < emissionMats.Length; i++)
            {
                emissionMats[i].SetColor("_EmissionColor", originEmissionColor[i]);
                Color c = emissionMats[i].color;
                c.a = 1f;
                emissionMats[i].color = c;
            }
        }
    }

    /// <summary>
    /// update
    /// </summary>
    private void Update()
    {
        if (emissionMats.Length != 0)
        {
            for (int i = 0; i < emissionMats.Length; i++)
            {
                Color lerpEmission = Color.Lerp(originEmissionColor[i] * 0.5f, originEmissionColor[i] * 2.0f, timer);
                emissionMats[i].SetColor("_EmissionColor", lerpEmission);

                Color c = emissionMats[i].color;
                c.a = Mathf.Lerp(0.1f, 1, timer);
                emissionMats[i].color = c;
            }
        }

        timer += Time.deltaTime * glowSpeed * glowFactor;
        if (timer > 1f)
        {
            glowFactor *= -1;
            timer = 1f;
        }
        else if(timer < 0f)
        {
            timer = 0f;
            glowFactor *= -1;
        }
    }
}
